//
//  SettingsView.swift
//  BuildPeek
//
//  App settings with API configuration, appearance, and preferences
//  Professional UI with BUILD PEEK branding
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(SupabaseAuthService.self) private var authService
    @State private var viewModel = SettingsViewModel()

    @State private var showAPIKeySheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSubscriptionManagement = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Account
                accountSection

                // Subscription
                subscriptionSection

                // API Configuration
                apiSection

                // Appearance
                appearanceSection

                // Export Settings
                exportSection

                // Privacy
                privacySection

                // About
                aboutSection

                // Danger Zone
                dangerSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAPIKeySheet) {
                APIKeyConfigSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showSubscriptionManagement) {
                SubscriptionManagementView()
            }
            .alert("Reset Settings?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {}
            } message: {
                if let message = viewModel.successMessage {
                    Text(message)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if let user = authService.currentUser {
                HStack(spacing: 16) {
                    // Avatar
                    if let avatarURLString = user.avatarURL, let url = URL(string: avatarURLString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            userInitialsView(for: user)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        userInitialsView(for: user)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name ?? user.email)
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: user.provider.iconName)
                                .font(.caption2)
                            Text("Signed in with \(user.provider.displayName)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            }

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } header: {
            Text("Account")
        }
    }

    private func userInitialsView(for user: SupabaseUser) -> some View {
        Circle()
            .fill(BuildPeekColors.primaryGradient)
            .frame(width: 50, height: 50)
            .overlay(
                Text(userInitials(for: user))
                    .font(.headline)
                    .foregroundStyle(.white)
            )
    }

    private func userInitials(for user: SupabaseUser) -> String {
        if let name = user.name, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return String(user.email.prefix(2)).uppercased()
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            Button {
                showSubscriptionManagement = true
            } label: {
                HStack {
                    // Subscription tier icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(subscriptionGradient)
                            .frame(width: 36, height: 36)

                        Image(systemName: subscriptionIcon)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(subscriptionService.subscriptionStatus.tier.rawValue)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if subscriptionService.subscriptionStatus.isTrialPeriod {
                            if let days = subscriptionService.subscriptionStatus.trialDaysRemaining {
                                Text("\(days) days left in trial")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else if subscriptionService.subscriptionStatus.tier == .free {
                            Text("Upgrade for more features")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Active subscription")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Usage overview
            HStack {
                Label("Estimates Used", systemImage: "doc.text.fill")
                Spacer()
                Text("\(subscriptionService.getMonthlyUsage(.unlimitedEstimates))/\(formatLimit(subscriptionService.subscriptionStatus.tier.estimateLimit))")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Images Generated", systemImage: "photo.fill")
                Spacer()
                Text("\(subscriptionService.getMonthlyUsage(.imageGeneration))/\(formatLimit(subscriptionService.subscriptionStatus.tier.imageLimit))")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Subscription")
        } footer: {
            if subscriptionService.subscriptionStatus.tier == .free {
                Text("Upgrade to unlock unlimited estimates and AI image generation.")
            }
        }
    }

    private var subscriptionGradient: LinearGradient {
        switch subscriptionService.subscriptionStatus.tier {
        case .free:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .professional:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .enterprise:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var subscriptionIcon: String {
        switch subscriptionService.subscriptionStatus.tier {
        case .free: return "person.fill"
        case .professional: return "star.fill"
        case .enterprise: return "building.2.fill"
        }
    }

    private func formatLimit(_ limit: Int) -> String {
        limit == Int.max ? "Unlimited" : "\(limit)"
    }

    // MARK: - API Section

    private var apiSection: some View {
        Section {
            // API Status
            HStack {
                Label("Gemini API", systemImage: "key.fill")

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: viewModel.apiKeyValidationStatus.icon)
                        .foregroundStyle(viewModel.apiKeyValidationStatus.color)

                    Text(viewModel.apiKeyValidationStatus.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(viewModel.apiKeyValidationStatus.color)
                }
            }

            Button {
                showAPIKeySheet = true
            } label: {
                Label(
                    appState.hasValidAPIKey ? "Update API Key" : "Configure API Key",
                    systemImage: "gear"
                )
            }

            if appState.hasValidAPIKey {
                Button(role: .destructive) {
                    Task {
                        await viewModel.removeAPIKey()
                    }
                } label: {
                    Label("Remove API Key", systemImage: "trash")
                }
            }
        } header: {
            Text("API Configuration")
        } footer: {
            Text("Your API key is stored securely in the device Keychain and never transmitted to our servers.")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $viewModel.colorSchemePreference) {
                ForEach(ColorSchemePreference.allCases) { preference in
                    Text(preference.rawValue).tag(preference)
                }
            }

            Picker("Accent Color", selection: $viewModel.accentColorChoice) {
                ForEach(AccentColorChoice.allCases) { choice in
                    HStack {
                        Circle()
                            .fill(choice.color)
                            .frame(width: 16, height: 16)
                        Text(choice.rawValue)
                    }
                    .tag(choice)
                }
            }

            Toggle("Dynamic Type", isOn: $viewModel.useDynamicType)

            Toggle("Reduce Motion", isOn: $viewModel.reduceMotion)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            Picker("PDF Format", selection: $viewModel.defaultPDFFormat) {
                ForEach(PDFFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }

            Toggle("Include Images in PDF", isOn: $viewModel.includeImagesInPDF)

            HStack {
                Text("Company Name")
                Spacer()
                TextField("Optional", text: $viewModel.companyName)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Export Settings")
        } footer: {
            Text("These settings apply to PDF exports and client reports.")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            Toggle("Analytics", isOn: $viewModel.enableAnalytics)

            Toggle("Crash Reporting", isOn: $viewModel.enableCrashReporting)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Help improve the app by sharing anonymous usage data.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://example.com/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://example.com/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://example.com/support")!) {
                Label("Help & Support", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        Section {
            Button {
                showDeleteConfirmation = true
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }

            Button(role: .destructive) {
                Task {
                    await viewModel.clearAllData()
                }
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Clearing all data will remove all projects, estimates, and generated images.")
        }
    }
}

// MARK: - API Key Config Sheet

struct APIKeyConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text("Configure API Key")
                            .font(.title2.bold())

                        Text("Enter your Google Gemini API key to enable AI-powered features.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // API Key Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gemini API Key")
                            .font(.headline)

                        SecureField("Enter your API key", text: $viewModel.geminiAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()

                        Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                            Label("Get API Key from Google AI Studio", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)

                    // Status indicator
                    if viewModel.isValidatingAPIKey {
                        HStack {
                            ProgressView()
                            Text("Validating...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Save button
                    Button {
                        Task {
                            await viewModel.saveGeminiAPIKey()
                            if viewModel.apiKeyValidationStatus == .valid {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isValidatingAPIKey {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Save API Key")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.geminiAPIKey.isEmpty ? Color.gray : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.geminiAPIKey.isEmpty || viewModel.isValidatingAPIKey)
                    .padding(.horizontal)

                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to get your API key:")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            InstructionStep(number: 1, text: "Visit Google AI Studio")
                            InstructionStep(number: 2, text: "Sign in with your Google account")
                            InstructionStep(number: 3, text: "Click 'Create API Key'")
                            InstructionStep(number: 4, text: "Copy and paste the key above")
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
        .environment(AppState.shared)
        .environment(SubscriptionService())
        .environment(SupabaseAuthService())
}
