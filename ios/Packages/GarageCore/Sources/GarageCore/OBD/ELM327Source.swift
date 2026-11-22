import Foundation

/// One open line to an ELM327-style adapter. The Bluetooth radio code implements
/// this in the app; tests implement it with a fake, so everything above the radio
/// is tested without hardware.
public protocol OBDTransport: Sendable {
    /// A name to show, such as "OBDLink CX".
    var name: String { get }
    /// Sends one command (such as "010C") and returns the reply text, without the
    /// trailing ">" prompt. Throws `OBDLinkError.timeout` if the adapter stays silent.
    func send(_ command: String, timeout: Duration) async throws -> String
    func close() async
}

public enum OBDLinkError: Error, Equatable, LocalizedError, Sendable {
    case timeout
    case notConnected
    case adapterError(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .timeout: "The adapter stopped answering."
        case .notConnected: "No adapter is connected."
        case .adapterError(let text): text
        case .unsupported(let text): text
        }
    }
}

public typealias OBDTransportFactory = @Sendable () async throws -> OBDTransport

/// A real vehicle, read through an ELM327-style adapter (OBDLink, vLinker, Veepeak).
/// Handles adapter setup, the polling loop, and trouble codes. Bluetooth itself
/// lives behind `OBDTransport`.
public final class ELM327Source: OBDDataSource, @unchecked Sendable {
    public let displayName: String

    private let makeTransport: OBDTransportFactory
    private let plan: OBDSamplingPlan
    private let commandTimeout: Duration
    private let startupTimeout: Duration
    private let maxConsecutiveFailures: Int

    private struct Job {
        let command: String
        let reply: CheckedContinuation<String, Error>
    }
    private let lock = NSLock()
    private var jobs: [Job] = []
    private var isRunning = false

    public init(
        displayName: String = "Bluetooth adapter",
        plan: OBDSamplingPlan = .standard,
        commandTimeout: Duration = .seconds(3),
        startupTimeout: Duration = .seconds(20),
        maxConsecutiveFailures: Int = 6,
        makeTransport: @escaping OBDTransportFactory
    ) {
        self.displayName = displayName
        self.plan = plan
        self.commandTimeout = commandTimeout
        self.startupTimeout = startupTimeout
        self.maxConsecutiveFailures = maxConsecutiveFailures
        self.makeTransport = makeTransport
    }

    // MARK: Streaming

    public func events() -> AsyncStream<OBDEvent> {
        AsyncStream { continuation in
            let task = Task { [self] in
                continuation.yield(.state(.connecting))
                var transport: OBDTransport?
                do {
                    let opened = try await makeTransport()
                    transport = opened
                    try await initialise(opened)
                    guard !Task.isCancelled else { await opened.close(); return }
                    setRunning(true)
                    continuation.yield(.state(.connected(adapter: opened.name)))
                    try await poll(opened, continuation: continuation)
                    continuation.yield(.state(.disconnected))
                } catch is CancellationError {
                    continuation.yield(.state(.disconnected))
                } catch {
                    continuation.yield(.state(.failed(Self.message(for: error))))
                }
                setRunning(false)
                failPendingJobs()
                await transport?.close()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Adapter setup, then a probe that also makes the adapter find the car's protocol.
    private func initialise(_ transport: OBDTransport) async throws {
        _ = try? await transport.send("ATZ", timeout: startupTimeout)   // reset; some clones answer late or not at all
        for command in ["ATE0", "ATL0", "ATS1", "ATH0", "ATSP0"] {
            _ = try await transport.send(command, timeout: commandTimeout)
        }
        let probe = try await transport.send("0100", timeout: startupTimeout)
        let text = probe.uppercased()
        if text.contains("UNABLE TO CONNECT") || text.contains("BUS INIT") || text.contains("CAN ERROR") {
            throw OBDLinkError.adapterError("The adapter can't reach the car. Turn the ignition on and try again.")
        }
        if !text.contains("41") && !text.contains("NO DATA") {
            throw OBDLinkError.adapterError("The adapter didn't answer like an OBD-II adapter.")
        }
    }

    private func poll(_ transport: OBDTransport, continuation: AsyncStream<OBDEvent>.Continuation) async throws {
        var lastSlow = -TimeInterval.infinity
        let start = Date()
        var failures = 0
        while !Task.isCancelled {
            for job in takeJobs() {
                do { job.reply.resume(returning: try await transport.send(job.command, timeout: commandTimeout)) }
                catch { job.reply.resume(throwing: error) }
            }

            let now = Date()
            let elapsed = now.timeIntervalSince(start)
            var pids = plan.fastPIDs
            if elapsed - lastSlow >= plan.slowInterval {
                pids += plan.slowPIDs
                lastSlow = elapsed
            }

            var readings: [OBDReading] = []
            for pid in pids {
                guard !Task.isCancelled else { return }
                do {
                    let reply = try await transport.send(pid.command, timeout: commandTimeout)
                    failures = 0
                    // "NO DATA" or an unsupported PID parses to nil; skip it, it isn't a failure.
                    if let value = ELM327.parseLiveData(reply, for: pid) {
                        readings.append(OBDReading(pid: pid, value: value, timestamp: Date()))
                    }
                } catch OBDLinkError.timeout {
                    failures += 1
                    if failures >= maxConsecutiveFailures {
                        throw OBDLinkError.adapterError("Lost the adapter. Check it is plugged in and in range.")
                    }
                }
            }
            if !readings.isEmpty { continuation.yield(.readings(readings)) }
            try? await Task.sleep(for: .seconds(plan.fastInterval))
        }
    }

    // MARK: Trouble codes

    public func readTroubleCodes() async throws -> [String] {
        let reply = try await submit("03")
        if reply.uppercased().contains("NO DATA") { return [] }
        return ELM327.parseTroubleCodes(reply)
    }

    public func clearTroubleCodes() async throws {
        let reply = try await submit("04")
        // A positive reply starts "44". Anything else means the car refused (engine running, for example).
        guard reply.uppercased().contains("44") else {
            throw OBDLinkError.adapterError("The car didn't clear the codes. Try with the engine off and the ignition on.")
        }
    }

    /// Queues a command for the polling loop, so it never collides with a gauge read.
    private func submit(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard isRunning else {
                lock.unlock()
                continuation.resume(throwing: OBDLinkError.notConnected)
                return
            }
            jobs.append(Job(command: command, reply: continuation))
            lock.unlock()
        }
    }

    // MARK: Bookkeeping

    private func setRunning(_ value: Bool) {
        lock.lock(); isRunning = value; lock.unlock()
    }

    private func takeJobs() -> [Job] {
        lock.lock(); defer { lock.unlock() }
        let taken = jobs
        jobs = []
        return taken
    }

    private func failPendingJobs() {
        for job in takeJobs() { job.reply.resume(throwing: OBDLinkError.notConnected) }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
