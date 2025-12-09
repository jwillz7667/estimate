//
//  SupabaseAuthService.swift
//  BuildPeek
//
//  Supabase authentication service supporting Google, Apple, and Email sign-in
//  Handles OAuth flows, session management, and user profile sync
//

import Foundation
import AuthenticationServices
import CryptoKit
import OSLog

// NOTE: AuthProvider is defined in User.swift

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case authenticating
    case authenticated(SupabaseUser)
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticating, .authenticating): return true
        case (.authenticated(let u1), .authenticated(let u2)): return u1.id == u2.id
        case (.error(let e1), .error(let e2)): return e1 == e2
        default: return false
        }
    }
}

// MARK: - Supabase User

struct SupabaseUser: Codable, Sendable {
    let id: String
    let email: String
    let name: String?
    let avatarURL: String?
    let provider: AuthProvider
    let emailVerified: Bool
    let createdAt: Date

    init(from authUser: AuthUser, provider: AuthProvider) {
        self.id = authUser.id
        self.email = authUser.email ?? ""
        self.name = authUser.userMetadata?["full_name"]?.value as? String
            ?? authUser.userMetadata?["name"]?.value as? String
        self.avatarURL = authUser.userMetadata?["avatar_url"]?.value as? String
            ?? authUser.userMetadata?["picture"]?.value as? String
        self.provider = provider
        self.emailVerified = authUser.emailConfirmedAt != nil
        self.createdAt = ISO8601DateFormatter().date(from: authUser.createdAt) ?? Date()
    }

    init(id: String, email: String, name: String?, avatarURL: String?, provider: AuthProvider, emailVerified: Bool, createdAt: Date) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.provider = provider
        self.emailVerified = emailVerified
        self.createdAt = createdAt
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case notConfigured
    case networkError(Error)
    case invalidCredentials
    case userCancelled
    case emailNotVerified
    case weakPassword
    case emailAlreadyInUse
    case invalidEmail
    case sessionExpired
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Authentication is not configured. Please set up your Supabase credentials."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userCancelled:
            return "Sign in was cancelled"
        case .emailNotVerified:
            return "Please verify your email address"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .sessionExpired:
            return "Your session has expired. Please sign in again"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Supabase Auth Service

@MainActor
@Observable
final class SupabaseAuthService {

    // MARK: - Published State

    var authState: AuthState = .unknown
    var currentUser: SupabaseUser?
    var isLoading = false

    // MARK: - Private Properties

    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.buildpeek", category: "SupabaseAuth")
    private var currentNonce: String?
    private var webAuthSession: ASWebAuthenticationSession?

    // Keychain keys
    private enum KeychainKeys {
        static let currentUser = "supabase_current_user"
        static let provider = "supabase_auth_provider"
    }

    // MARK: - Initialization

    init() {
        Task {
            await checkExistingSession()
        }
    }

    // MARK: - Session Management

    /// Check for existing valid session on app launch
    func checkExistingSession() async {
        logger.info("Checking existing session...")

        // Check if Supabase is configured
        guard Secrets.isConfigured else {
            logger.warning("Supabase not configured")
            authState = .unauthenticated
            return
        }

        // Check for cached user
        if let authUser = supabase.getCurrentUser() {
            // Load provider from keychain
            let provider = loadStoredProvider() ?? .email

            let user = SupabaseUser(from: authUser, provider: provider)
            currentUser = user
            authState = .authenticated(user)
            logger.info("Session restored for user: \(user.email)")

            // Try to refresh the session
            Task {
                do {
                    _ = try await supabase.refreshSession()
                    logger.info("Session refreshed successfully")
                } catch {
                    logger.warning("Session refresh failed: \(error.localizedDescription)")
                    // Session might still be valid, don't sign out yet
                }
            }
        } else {
            logger.info("No existing session found")
            authState = .unauthenticated
        }
    }

    // MARK: - Email Authentication

    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws {
        guard Secrets.isConfigured else {
            throw AuthError.notConfigured
        }

        isLoading = true
        authState = .authenticating

        defer { isLoading = false }

        // Validate inputs
        guard isValidEmail(email) else {
            authState = .unauthenticated
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            authState = .unauthenticated
            throw AuthError.weakPassword
        }

        do {
            let session = try await supabase.signIn(email: email, password: password)

            let user = SupabaseUser(from: session.user, provider: .email)
            storeProvider(.email)

            currentUser = user
            authState = .authenticated(user)

            logger.info("Successfully signed in with email: \(email)")

        } catch let error as DatabaseError {
            authState = .unauthenticated
            throw mapDatabaseError(error)
        } catch {
            authState = .unauthenticated
            throw AuthError.networkError(error)
        }
    }

    /// Sign up with email and password
    func signUpWithEmail(email: String, password: String, name: String?) async throws {
        guard Secrets.isConfigured else {
            throw AuthError.notConfigured
        }

        isLoading = true
        authState = .authenticating

        defer { isLoading = false }

        // Validate inputs
        guard isValidEmail(email) else {
            authState = .unauthenticated
            throw AuthError.invalidEmail
        }

        guard password.count >= 8 else {
            authState = .unauthenticated
            throw AuthError.weakPassword
        }

        do {
            let session = try await supabase.signUp(email: email, password: password)

            let user = SupabaseUser(from: session.user, provider: .email)
            storeProvider(.email)

            currentUser = user
            authState = .authenticated(user)

            logger.info("Successfully signed up with email: \(email)")

        } catch let error as DatabaseError {
            authState = .unauthenticated
            throw mapDatabaseError(error)
        } catch {
            authState = .unauthenticated
            throw AuthError.networkError(error)
        }
    }

    /// Request password reset email
    func resetPassword(email: String) async throws {
        guard Secrets.isConfigured else {
            throw AuthError.notConfigured
        }

        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        isLoading = true
        defer { isLoading = false }

        // Make password reset request
        let url = URL(string: "\(SupabaseConfiguration.authURL)/recover")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")

        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.unknown("Failed to send password reset email")
        }

        logger.info("Password reset email sent to: \(email)")
    }

    // MARK: - Google Sign In

    /// Sign in with Google via Supabase OAuth
    func signInWithGoogle() async throws {
        guard Secrets.isConfigured else {
            throw AuthError.notConfigured
        }

        isLoading = true
        authState = .authenticating

        defer { isLoading = false }

        // Build OAuth URL for Google
        var components = URLComponents(string: "\(SupabaseConfiguration.authURL)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: SupabaseConfiguration.redirectURL),
            URLQueryItem(name: "scopes", value: "email profile")
        ]

        guard let authURL = components.url else {
            authState = .unauthenticated
            throw AuthError.unknown("Failed to build auth URL")
        }

        do {
            let callbackURL = try await performWebAuth(url: authURL)
            try await handleOAuthCallback(url: callbackURL, provider: .google)
        } catch let error as AuthError {
            authState = .unauthenticated
            throw error
        } catch {
            authState = .unauthenticated
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Apple Sign In

    /// Sign in with Apple using native Sign in with Apple
    func signInWithApple() async throws {
        guard Secrets.isConfigured else {
            throw AuthError.notConfigured
        }

        isLoading = true
        authState = .authenticating

        defer { isLoading = false }

        // Generate nonce for security
        let nonce = generateNonce()
        currentNonce = nonce

        // Perform Apple Sign In
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let result = try await performAppleSignIn(request: request)

        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            authState = .unauthenticated
            throw AuthError.unknown("Failed to get Apple credentials")
        }

        // Exchange Apple token with Supabase
        do {
            let session = try await supabase.signInWithApple(idToken: identityToken, nonce: nonce)

            let user = SupabaseUser(from: session.user, provider: .apple)
            storeProvider(.apple)

            currentUser = user
            authState = .authenticated(user)

            logger.info("Successfully signed in with Apple")

        } catch let error as DatabaseError {
            authState = .unauthenticated
            throw mapDatabaseError(error)
        } catch {
            authState = .unauthenticated
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign Out

    /// Sign out and clear session
    func signOut() async {
        isLoading = true

        do {
            try await supabase.signOut()
        } catch {
            logger.warning("Sign out error: \(error.localizedDescription)")
        }

        // Clear local state
        clearStoredProvider()
        currentUser = nil
        authState = .unauthenticated
        isLoading = false

        logger.info("User signed out")
    }

    // MARK: - Private Methods

    private func performWebAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Secrets.oauthCallbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: AuthError.networkError(error))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthError.unknown("No callback URL"))
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = WebAuthContextProvider.shared

            if !session.start() {
                continuation.resume(throwing: AuthError.unknown("Failed to start auth session"))
            }

            self.webAuthSession = session
        }
    }

    private func handleOAuthCallback(url: URL, provider: AuthProvider) async throws {
        // Parse callback URL for tokens
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fragment = components.fragment else {
            throw AuthError.unknown("Invalid callback URL")
        }

        // Parse fragment parameters (access_token, refresh_token, etc.)
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                params[String(parts[0])] = String(parts[1])
            }
        }

        guard let accessToken = params["access_token"] else {
            throw AuthError.unknown("No access token in callback")
        }

        // Get user info with the token
        let url = URL(string: "\(SupabaseConfiguration.authURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.unknown("Failed to get user info")
        }

        let authUser = try JSONDecoder().decode(AuthUser.self, from: data)

        let user = SupabaseUser(from: authUser, provider: provider)
        storeProvider(provider)

        currentUser = user
        authState = .authenticated(user)

        logger.info("Successfully signed in with \(provider.displayName)")
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = WebAuthContextProvider.shared
            controller.performRequests()

            // Hold reference to delegate
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func mapDatabaseError(_ error: DatabaseError) -> AuthError {
        switch error {
        case .unauthorized:
            return .invalidCredentials
        case .conflict:
            return .emailAlreadyInUse
        case .notAuthenticated:
            return .sessionExpired
        default:
            return .unknown(error.localizedDescription ?? "Unknown error")
        }
    }

    private func storeProvider(_ provider: AuthProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: KeychainKeys.provider)
    }

    private func loadStoredProvider() -> AuthProvider? {
        guard let rawValue = UserDefaults.standard.string(forKey: KeychainKeys.provider) else {
            return nil
        }
        return AuthProvider(rawValue: rawValue)
    }

    private func clearStoredProvider() {
        UserDefaults.standard.removeObject(forKey: KeychainKeys.provider)
    }
}

// MARK: - Web Auth Context Provider

class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation.resume(throwing: AuthError.userCancelled)
        } else {
            continuation.resume(throwing: AuthError.networkError(error))
        }
    }
}
