//
//  BuildPeekApp.swift
//  BuildPeek
//
//  BUILD PEEK - AI-Powered Renovation Cost Estimation & Visualization
//  See your renovation before you build it
//
//  Powered by Google Gemini AI for intelligent estimates and photorealistic visualizations
//
//  Architecture: MVVM with dependency injection
//  Target: iOS 18.0+, iPhone and iPad
//

import SwiftUI
import SwiftData
import OSLog

@main
struct BuildPeekApp: App {
    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RenovationProject.self,
            EstimateResult.self,
            GeneratedImage.self,
            User.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration failed - delete existing store and retry
            // This handles development schema changes gracefully
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    // MARK: - App State

    @State private var appState = AppState.shared
    @State private var subscriptionService = SubscriptionService()
    @State private var authService = SupabaseAuthService()

    // MARK: - Init

    init() {
        // Configure BUILD PEEK appearance
        BuildPeekTabBarAppearance.configure()
        BuildPeekNavBarAppearance.configure()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(DIContainer.shared)
                .environment(subscriptionService)
                .environment(authService)
                .tint(BuildPeekColors.primaryBlue)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch authService.authState {
            case .unknown:
                // Show loading while checking auth state
                LoadingView()
            case .unauthenticated, .error:
                // Show authentication view
                AuthenticationView()
                    .transition(.opacity)
            case .authenticating:
                // Show loading during auth
                LoadingView()
            case .authenticated:
                // User is authenticated
                if appState.showOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.authState)
        .preferredColorScheme(appState.colorScheme)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                BuildPeekLogo(size: .large)

                ProgressView()
                    .scaleEffect(1.2)
                    .tint(BuildPeekColors.primaryBlue)
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon)
                }
                .tag(AppTab.dashboard)

            ProjectInputView()
                .tabItem {
                    Label("New Peek", systemImage: AppTab.newProject.icon)
                }
                .tag(AppTab.newProject)

            ProjectsListView()
                .tabItem {
                    Label(AppTab.projects.rawValue, systemImage: AppTab.projects.icon)
                }
                .tag(AppTab.projects)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(BuildPeekColors.primaryBlue)
        .onChange(of: appState.selectedTab) { _, newTab in
            selectedTab = newTab
        }
    }
}

// MARK: - Projects List View

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RenovationProject.updatedAt, order: .reverse)
    private var projects: [RenovationProject]

    @State private var searchText = ""
    @State private var selectedFilter: ProjectStatus?
    @State private var showImageEditor = false

    var filteredProjects: [RenovationProject] {
        var result = projects

        if !searchText.isEmpty {
            result = result.filter {
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.roomType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let filter = selectedFilter {
            result = result.filter { $0.status == filter }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectsList
                }
            }
            .navigationTitle("Projects")
            .searchable(text: $searchText, prompt: "Search projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            selectedFilter = nil
                        } label: {
                            HStack {
                                Text("All")
                                if selectedFilter == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button {
                                selectedFilter = status
                            } label: {
                                HStack {
                                    Text(status.rawValue)
                                    if selectedFilter == status {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showImageEditor = true
                    } label: {
                        Label("Image Editor", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showImageEditor) {
                ImageEditorView()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Projects Yet")
                    .font(.title2.bold())

                Text("Create your first project to get started with AI-powered estimates")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    private var projectsList: some View {
        List {
            ForEach(filteredProjects) { project in
                NavigationLink {
                    ProjectDetailView(project: project)
                } label: {
                    ProjectRowView(project: project)
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = filteredProjects[index]
            modelContext.delete(project)
        }
    }
}

// MARK: - Project Row View

struct ProjectRowView: View {
    let project: RenovationProject

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: project.roomType.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.projectName.isEmpty ? "Untitled Project" : project.projectName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(project.roomType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("\(Int(project.squareFootage)) sq ft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: project.status)

                Text(project.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .draft: return .gray
        case .estimating: return .orange
        case .estimated: return .blue
        case .approved: return .green
        case .inProgress: return .purple
        case .completed: return .teal
        case .cancelled: return .red
        }
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: RenovationProject

    @State private var showEstimate = false
    @State private var showImageEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                headerCard

                // Details section
                detailsSection

                // Estimates section
                if let estimates = project.estimates, !estimates.isEmpty {
                    estimatesSection(estimates)
                }

                // Images section
                if let images = project.generatedImages, !images.isEmpty {
                    imagesSection(images)
                }

                // Actions
                actionsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(project.projectName.isEmpty ? "Project Details" : project.projectName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEstimate) {
            EstimateGenerationView(
                viewModel: ProjectViewModel(
                    modelContext: modelContext,
                    geminiService: DIContainer.shared.geminiService
                )
            )
        }
        .sheet(isPresented: $showImageEditor) {
            ImageEditorView()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: project.roomType.icon)
                        .font(.title)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.roomType.rawValue)
                        .font(.headline)

                    StatusBadge(status: project.status)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(project.squareFootage))")
                        .font(.title.bold())
                    Text("sq ft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 0) {
                DetailRow(label: "Quality Tier", value: project.qualityTier.rawValue)
                Divider()
                DetailRow(label: "Location", value: project.location.isEmpty ? "Not specified" : project.location)
                Divider()
                DetailRow(label: "Urgency", value: project.urgency.rawValue)
                Divider()
                DetailRow(label: "Includes Permits", value: project.includesPermits ? "Yes" : "No")
                Divider()
                DetailRow(label: "Includes Design", value: project.includesDesign ? "Yes" : "No")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func estimatesSection(_ estimates: [EstimateResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimates")
                .font(.headline)

            ForEach(estimates) { estimate in
                VStack(alignment: .leading, spacing: 8) {
                    Text(estimate.formattedTotalRange)
                        .font(.title2.bold())

                    HStack {
                        Text("Confidence: \(Int(estimate.confidenceScore * 100))%")
                        Spacer()
                        Text(estimate.createdAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func imagesSection(_ images: [GeneratedImage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated Images")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images) { image in
                        if let uiImage = image.uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showEstimate = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate New Estimate")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                showImageEditor = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Edit Images")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding()
    }
}

