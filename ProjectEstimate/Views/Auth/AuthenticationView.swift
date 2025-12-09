//
//  AuthenticationView.swift
//  BuildPeek
//
//  Authentication UI with Google, Apple, and Email sign-in options
//  Clean white design with cobalt blue accents
//

import SwiftUI

// MARK: - Authentication View

struct AuthenticationView: View {
    @Environment(SupabaseAuthService.self) private var authService
    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo and branding
                VStack(spacing: 16) {
                    BuildPeekLogo(size: .large)

                    Text("See your renovation\nbefore you build it")
                        .font(.title3)
                        .foregroundStyle(BuildPeekColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign in buttons
                VStack(spacing: 16) {
                    // Continue with Google
                    SocialSignInButton(
                        provider: .google,
                        action: signInWithGoogle
                    )

                    // Continue with Apple
                    SocialSignInButton(
                        provider: .apple,
                        action: signInWithApple
                    )

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(BuildPeekColors.backgroundTertiary)
                            .frame(height: 1)
                        Text("or")
                            .font(.subheadline)
                            .foregroundStyle(BuildPeekColors.textTertiary)
                        Rectangle()
                            .fill(BuildPeekColors.backgroundTertiary)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)

                    // Continue with Email
                    Button {
                        showEmailSignIn = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text("Continue with Email")
                                .font(.headline)
                        }
                        .foregroundStyle(BuildPeekColors.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(BuildPeekColors.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(BuildPeekColors.primaryBlue, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Sign up link
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(BuildPeekColors.textSecondary)
                    Button("Sign up") {
                        showEmailSignUp = true
                    }
                    .foregroundStyle(BuildPeekColors.primaryBlue)
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 16)

                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By continuing, you agree to our")
                        .foregroundStyle(BuildPeekColors.textTertiary)
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://buildpeek.app/terms")!)
                            .foregroundStyle(BuildPeekColors.primaryBlue)
                        Text("and")
                            .foregroundStyle(BuildPeekColors.textTertiary)
                        Link("Privacy Policy", destination: URL(string: "https://buildpeek.app/privacy")!)
                            .foregroundStyle(BuildPeekColors.primaryBlue)
                    }
                }
                .font(.caption)
                .padding(.bottom, 24)
            }

            // Loading overlay
            if authService.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch let error as AuthError {
                if case .userCancelled = error {
                    return // Don't show error for user cancellation
                }
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func signInWithApple() {
        Task {
            do {
                try await authService.signInWithApple()
            } catch let error as AuthError {
                if case .userCancelled = error {
                    return
                }
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Social Sign In Button

struct SocialSignInButton: View {
    let provider: AuthProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                providerIcon
                    .font(.title3)

                Text("Continue with \(provider.displayName)")
                    .font(.headline)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: provider == .apple ? 0 : 1)
            )
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .google:
            // Google "G" icon
            Image(systemName: "g.circle.fill")
                .symbolRenderingMode(.multicolor)
        case .apple:
            Image(systemName: "apple.logo")
        case .email:
            Image(systemName: "envelope.fill")
        }
    }

    private var foregroundColor: Color {
        switch provider {
        case .google: return BuildPeekColors.textPrimary
        case .apple: return .white
        case .email: return BuildPeekColors.primaryBlue
        }
    }

    private var backgroundColor: Color {
        switch provider {
        case .google: return .white
        case .apple: return .black
        case .email: return BuildPeekColors.primaryBlue.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch provider {
        case .google: return BuildPeekColors.backgroundTertiary
        case .apple: return .clear
        case .email: return BuildPeekColors.primaryBlue
        }
    }
}

// MARK: - Email Sign In View

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseAuthService.self) private var authService

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false
    @State private var errorMessage: String?
    @State private var showError = false

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(BuildPeekColors.primaryBlue)

                        Text("Sign in with Email")
                            .font(.title.bold())
                            .foregroundStyle(BuildPeekColors.textPrimary)
                    }
                    .padding(.top, 32)

                    // Form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            TextField("Enter your email", text: $email)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                        }

                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Forgot password?") {
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(BuildPeekColors.primaryBlue)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sign in button
                    Button {
                        signIn()
                    } label: {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? BuildPeekColors.primaryBlue : BuildPeekColors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isFormValid || authService.isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(BuildPeekColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email)
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private func signIn() {
        focusedField = nil

        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Email Sign Up View

struct EmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseAuthService.self) private var authService

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showError = false

    @FocusState private var focusedField: Field?

    enum Field {
        case name, email, password, confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(BuildPeekColors.primaryBlue)

                        Text("Create Account")
                            .font(.title.bold())
                            .foregroundStyle(BuildPeekColors.textPrimary)

                        Text("Sign up to start estimating your renovation projects")
                            .font(.subheadline)
                            .foregroundStyle(BuildPeekColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Form
                    VStack(spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            TextField("Enter your name", text: $name)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.name)
                                .focused($focusedField, equals: .name)
                        }

                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            TextField("Enter your email", text: $email)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            SecureField("Create a password", text: $password)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .password)

                            // Password requirements
                            if !password.isEmpty {
                                PasswordStrengthView(password: password)
                            }
                        }

                        // Confirm password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BuildPeekColors.textSecondary)

                            SecureField("Confirm your password", text: $confirmPassword)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Label("Passwords don't match", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sign up button
                    Button {
                        signUp()
                    } label: {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? BuildPeekColors.primaryBlue : BuildPeekColors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isFormValid || authService.isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(BuildPeekColors.textSecondary)
                }
            }
        }
        .alert("Sign Up Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        email.contains("@") &&
        password.count >= 8
    }

    private func signUp() {
        focusedField = nil

        Task {
            do {
                try await authService.signUpWithEmail(email: email, password: password, name: name.isEmpty ? nil : name)
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseAuthService.self) private var authService

    @State var email: String
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(BuildPeekColors.primaryBlue)

                    Text("Reset Password")
                        .font(.title.bold())
                        .foregroundStyle(BuildPeekColors.textPrimary)

                    Text("Enter your email and we'll send you a link to reset your password")
                        .font(.subheadline)
                        .foregroundStyle(BuildPeekColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)

                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BuildPeekColors.textSecondary)

                    TextField("Enter your email", text: $email)
                        .textFieldStyle(AuthTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 24)

                // Reset button
                Button {
                    resetPassword()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(email.contains("@") ? BuildPeekColors.primaryBlue : BuildPeekColors.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!email.contains("@") || isLoading)
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(BuildPeekColors.textSecondary)
                }
            }
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Password reset email sent to \(email)")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func resetPassword() {
        isLoading = true
        Task {
            do {
                try await authService.resetPassword(email: email)
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let password: String

    private var strength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Strength bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BuildPeekColors.backgroundTertiary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(strength.color)
                        .frame(width: geo.size.width * strength.progress)
                        .animation(.easeInOut, value: strength)
                }
            }
            .frame(height: 4)

            // Requirements
            HStack(spacing: 16) {
                RequirementLabel(
                    met: password.count >= 8,
                    text: "8+ characters"
                )
                RequirementLabel(
                    met: password.contains(where: { $0.isUppercase }),
                    text: "Uppercase"
                )
                RequirementLabel(
                    met: password.contains(where: { $0.isNumber }),
                    text: "Number"
                )
            }
        }
    }
}

struct RequirementLabel: View {
    let met: Bool
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption2)
                .foregroundStyle(met ? BuildPeekColors.success : BuildPeekColors.textTertiary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(met ? BuildPeekColors.textSecondary : BuildPeekColors.textTertiary)
        }
    }
}

enum PasswordStrength {
    case weak, fair, strong

    var color: Color {
        switch self {
        case .weak: return .red
        case .fair: return .orange
        case .strong: return BuildPeekColors.success
        }
    }

    var progress: CGFloat {
        switch self {
        case .weak: return 0.33
        case .fair: return 0.66
        case .strong: return 1.0
        }
    }

    static func evaluate(_ password: String) -> PasswordStrength {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .fair
        default: return .strong
        }
    }
}

// MARK: - Auth Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(BuildPeekColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BuildPeekColors.backgroundTertiary, lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview("Authentication") {
    AuthenticationView()
        .environment(SupabaseAuthService())
}
