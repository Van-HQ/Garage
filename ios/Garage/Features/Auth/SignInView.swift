import SwiftUI

/// Email and password sign-in, the same account as the web app.
/// New accounts are created on the web; this app only signs in.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isWorking
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 64, height: 64)
                            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
                        Text("Garage")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                        Text("Sign in to track your vehicles")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    Panel(padding: 0) {
                        VStack(spacing: 0) {
                            field("Email") {
                                TextField("you@example.com", text: $email)
                                    .textContentType(.username)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focus, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .password }
                            }
                            Divider().overlay(Theme.hairline)
                            field("Password") {
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                                    .focused($focus, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { submit() }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.statusOverdue)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if isWorking { ProgressView().tint(Theme.accentForeground) }
                            Text("Sign in").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Theme.accentForeground)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 90)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(Theme.muted)
            content()
                .font(.system(size: 16))
                .foregroundStyle(Theme.foreground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func submit() {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
