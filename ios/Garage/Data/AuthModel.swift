import Foundation
import Observation

@MainActor
@Observable
final class AuthModel {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(AuthUser)
    }

    private(set) var state: State = .loading
    private let service: AuthService

    init(service: AuthService) {
        self.service = service
    }

    /// Follows the session for the life of the app. Call once from the root view.
    func observe() async {
        for await user in service.userChanges() {
            state = user.map(State.signedIn) ?? .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        try await service.signIn(email: email, password: password)
    }

    func signOut() async {
        // Even if the network call fails, the local session is gone and
        // userChanges() reports signed out.
        try? await service.signOut()
    }
}
