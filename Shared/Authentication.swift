import Combine
import FirebaseAuth
import SwiftUI

@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()
    @Published private(set) var uid: String?
    @Published var errorMessage: String?
    private var listener: AuthStateDidChangeListenerHandle?

    private init() { uid = Auth.auth().currentUser?.uid }

    func start() {
        guard listener == nil else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.uid = user?.uid }
        }
    }

    func signIn(email: String, password: String, createAccount: Bool) async throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else { throw AuthError.missingCredentials }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion: (AuthDataResult?, Error?) -> Void = { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
            if createAccount {
                Auth.auth().createUser(withEmail: email, password: password, completion: completion)
            } else {
                Auth.auth().signIn(withEmail: email, password: password, completion: completion)
            }
        }
    }

    func signOut() throws { try Auth.auth().signOut() }
}

private enum AuthError: LocalizedError {
    case missingCredentials
    var errorDescription: String? { "Enter an email and password." }
}

struct AuthenticationView: View {
    @ObservedObject var session: AuthSession
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = false
    @State private var busy = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Island Agent").font(.title2.bold())
            Text("Sign in with the same account on Mac and iPhone.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            TextField("Email", text: $email).textContentType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
            if let error = session.errorMessage { Text(error).foregroundStyle(.red).font(.callout) }
            Button {
                Task {
                    busy = true
                    defer { busy = false }
                    do { try await session.signIn(email: email, password: password, createAccount: createAccount) }
                    catch { session.errorMessage = error.localizedDescription }
                }
            } label: {
                if busy { ProgressView() }
                else { Text(createAccount ? "Create Account" : "Sign In").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent).disabled(busy)
            Button(createAccount ? "I already have an account" : "Create an account") {
                createAccount.toggle(); session.errorMessage = nil
            }.buttonStyle(.plain)
        }
        .padding(24).frame(maxWidth: 360)
    }
}
