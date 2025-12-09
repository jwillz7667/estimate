//
//  OnboardingView.swift
//  BuildPeek
//
//  Modern onboarding flow with BUILD PEEK branding
//  First-launch tutorial introducing app features
//

import SwiftUI

// MARK: - Onboarding Page Model

struct OnboardingPage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let backgroundColor: Color
    let accentColor: Color
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @State private var showAPISetup = false
    @State private var apiKey = ""
    @State private var isValidating = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to",
            subtitle: "BUILD PEEK",
            description: "See your renovation before you build it. AI-powered estimates and photorealistic visualizations in seconds.",
            imageName: "building.2.crop.circle",
            backgroundColor: .white,
            accentColor: BuildPeekColors.primaryBlue
        ),
        OnboardingPage(
            title: "Snap &",
            subtitle: "Analyze",
            description: "Upload photos of your space and let Gemini AI analyze your project. Get accurate estimates based on real images.",
            imageName: "camera.viewfinder",
            backgroundColor: .white,
            accentColor: BuildPeekColors.primaryBlue
        ),
        OnboardingPage(
            title: "Peek Your",
            subtitle: "Future Space",
            description: "See what your renovation will look like when complete. AI-generated visualizations bring your vision to life.",
            imageName: "eye.circle.fill",
            backgroundColor: .white,
            accentColor: BuildPeekColors.accentBlue
        ),
        OnboardingPage(
            title: "Real-Time",
            subtitle: "Pricing",
            description: "Get accurate material and labor costs for your area. Regional pricing ensures realistic estimates you can trust.",
            imageName: "dollarsign.arrow.circlepath",
            backgroundColor: .white,
            accentColor: BuildPeekColors.success
        )
    ]

    var body: some View {
        ZStack {
            // Clean white background with subtle accent tint
            Color.white
                .ignoresSafeArea()

            // Very subtle gradient overlay
            LinearGradient(
                colors: [
                    pages[currentPage].accentColor.opacity(0.05),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        showAPISetup = true
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding()
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator
                PageIndicator(
                    numberOfPages: pages.count,
                    currentPage: currentPage,
                    activeColor: pages[currentPage].accentColor
                )
                .padding(.vertical, 20)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BuildPeekColors.textSecondary)
                                .frame(width: 50, height: 50)
                                .background(BuildPeekColors.backgroundTertiary)
                                .clipShape(Circle())
                        }
                    }

                    Spacer()

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            showAPISetup = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(BuildPeekColors.primaryBlue)
                        .clipShape(Capsule())
                        .shadow(color: BuildPeekColors.primaryBlue.opacity(0.4), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showAPISetup) {
            APISetupSheet(
                apiKey: $apiKey,
                isValidating: $isValidating,
                onComplete: {
                    appState.completeOnboarding()
                }
            )
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Circle()
                    .fill(page.accentColor.opacity(0.25))
                    .frame(width: 140, height: 140)

                Image(systemName: page.imageName)
                    .font(.system(size: 60))
                    .foregroundStyle(page.accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2)
                    .foregroundStyle(BuildPeekColors.textSecondary)

                Text(page.subtitle)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(page.accentColor)
            }

            Text(page.description)
                .font(.body)
                .foregroundStyle(BuildPeekColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Page Indicator

struct PageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? activeColor : Color.gray.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }
}

// MARK: - API Setup Sheet

struct APISetupSheet: View {
    @Binding var apiKey: String
    @Binding var isValidating: Bool
    let onComplete: () -> Void

    @State private var validationError: String?
    @State private var showSkipConfirmation = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(BuildPeekColors.primaryBlue)
                            .padding()
                            .background(BuildPeekColors.primaryBlue.opacity(0.1))
                            .clipShape(Circle())

                        Text("Configure API Key")
                            .font(.title.bold())
                            .foregroundStyle(BuildPeekColors.textPrimary)

                        Text("Enter your Google Gemini API key to enable AI-powered estimates and image generation.")
                            .font(.subheadline)
                            .foregroundStyle(BuildPeekColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // API Key Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gemini API Key")
                            .font(.headline)

                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .focused($isTextFieldFocused)

                        if let error = validationError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                            Label("Get API Key from Google AI Studio", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)

                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to get your API key:")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(number: 1, text: "Visit Google AI Studio")
                            InstructionRow(number: 2, text: "Sign in with your Google account")
                            InstructionRow(number: 3, text: "Click 'Create API Key'")
                            InstructionRow(number: 4, text: "Copy and paste the key above")
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            validateAndSave()
                        } label: {
                            HStack {
                                if isValidating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save & Continue")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(apiKey.isEmpty ? BuildPeekColors.textTertiary : BuildPeekColors.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(apiKey.isEmpty || isValidating)

                        Button {
                            showSkipConfirmation = true
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(BuildPeekColors.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSkipConfirmation = true
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .alert("Skip API Setup?", isPresented: $showSkipConfirmation) {
            Button("Skip", role: .destructive) {
                onComplete()
            }
            Button("Go Back", role: .cancel) {}
        } message: {
            Text("You can configure your API key later in Settings. Some features will be unavailable until configured.")
        }
    }

    private func validateAndSave() {
        isValidating = true
        validationError = nil

        Task {
            do {
                let keyManager = APIKeyManager()
                try await keyManager.setGeminiAPIKey(apiKey)

                // Attempt validation
                let geminiService = GeminiAPIService()
                let isValid = try await geminiService.validateAPIKey()

                await MainActor.run {
                    isValidating = false
                    if isValid {
                        AppState.shared.setAPIKeyConfigured(true)
                        onComplete()
                    } else {
                        validationError = "API key validation failed. Please check your key."
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    validationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(BuildPeekColors.primaryBlue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(BuildPeekColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
        .environment(AppState.shared)
}
