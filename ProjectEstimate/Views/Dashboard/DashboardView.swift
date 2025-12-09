//
//  DashboardView.swift
//  BuildPeek
//
//  Main dashboard with BUILD PEEK branding
//  Displays project statistics, recent activity, and quick actions
//

import SwiftUI
import SwiftData

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var viewModel: DashboardViewModel?
    @State private var scrollOffset: CGFloat = 0
    @State private var showNewProject = false
    @State private var quickActionRoomType: RoomType?

    var body: some View {
        NavigationStack {
            ZStack {
                // BUILD PEEK white background with subtle gradient
                BuildPeekColors.background
                    .ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Parallax header
                        headerSection
                            .offset(y: parallaxOffset)

                        // Stats grid
                        statsSection
                            .fadeSlideIn(delay: 0.1)

                        // Quick actions
                        quickActionsSection
                            .fadeSlideIn(delay: 0.2)

                        // Recent projects
                        recentProjectsSection
                            .fadeSlideIn(delay: 0.3)

                        // Activity feed
                        activitySection
                            .fadeSlideIn(delay: 0.4)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BuildPeekLogo(size: .small)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewProject = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(BuildPeekColors.primaryBlue)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            ProjectInputView(preselectedRoomType: quickActionRoomType)
        }
        .onChange(of: showNewProject) { _, isShowing in
            if !isShowing {
                quickActionRoomType = nil
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(modelContext: modelContext)
            }
            Task {
                await viewModel?.loadDashboardData()
            }
        }
    }

    // MARK: - Parallax Offset

    private var parallaxOffset: CGFloat {
        let offset = scrollOffset / 3
        return min(0, offset)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Welcome message
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Ready to peek?")
                        .font(BuildPeekTypography.displaySmall)
                }

                Spacer()

                // Profile avatar with BUILD PEEK cobalt blue
                Circle()
                    .fill(BuildPeekColors.primaryGradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                    .shadow(color: BuildPeekColors.primaryBlue.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.top, 20)

            // API status indicator
            if !appState.hasValidAPIKey {
                apiSetupBanner
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var initials: String {
        if let user = appState.currentUser {
            let names = user.displayName.split(separator: " ")
            if names.count >= 2 {
                return "\(names[0].prefix(1))\(names[1].prefix(1))".uppercased()
            }
            return String(user.displayName.prefix(2)).uppercased()
        }
        return "BP"  // BUILD PEEK
    }

    private var apiSetupBanner: some View {
        GlassmorphicCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)

                VStack(alignment: .leading, spacing: 2) {
                    Text("API Key Required")
                        .font(.subheadline.bold())
                    Text("Configure your Gemini API key to enable AI features")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    SettingsView()
                } label: {
                    Text("Setup")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCardView(
                    title: "Total Projects",
                    value: "\(viewModel?.statistics.totalProjects ?? 0)",
                    icon: "folder.fill",
                    color: .blue
                )
                .bounceOnAppear(delay: 0.15)

                StatCardView(
                    title: "Estimated Value",
                    value: viewModel?.formattedTotalValue ?? "$0",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                .bounceOnAppear(delay: 0.2)

                StatCardView(
                    title: "Completed",
                    value: "\(viewModel?.statistics.completedProjects ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .teal
                )
                .bounceOnAppear(delay: 0.25)

                StatCardView(
                    title: "Pending",
                    value: "\(viewModel?.statistics.pendingEstimates ?? 0)",
                    icon: "clock.fill",
                    color: .orange
                )
                .bounceOnAppear(delay: 0.3)
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "Kitchen",
                        icon: "frying.pan",
                        color: .orange
                    ) {
                        quickActionRoomType = .kitchen
                        showNewProject = true
                    }

                    QuickActionButton(
                        title: "Bathroom",
                        icon: "shower",
                        color: .blue
                    ) {
                        quickActionRoomType = .bathroom
                        showNewProject = true
                    }

                    QuickActionButton(
                        title: "Flooring",
                        icon: "square.grid.3x3",
                        color: .brown
                    ) {
                        quickActionRoomType = .flooring
                        showNewProject = true
                    }

                    QuickActionButton(
                        title: "Full Home",
                        icon: "house.fill",
                        color: .purple
                    ) {
                        quickActionRoomType = .wholehouse
                        showNewProject = true
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Recent Projects Section

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Projects")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink {
                    ProjectListView()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }

            if let projects = viewModel?.recentProjects, !projects.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(projects.prefix(3).enumerated()), id: \.element.id) { index, project in
                        RecentProjectCard(project: project)
                            .scaleOnAppear(delay: 0.1 * Double(index))
                    }
                }
            } else {
                EmptyStateCard(
                    icon: "folder.badge.plus",
                    title: "No Projects Yet",
                    message: "Create your first project to get started"
                ) {
                    showNewProject = true
                }
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let activity = viewModel?.statistics.recentActivity, !activity.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(activity.prefix(5).enumerated()), id: \.element.id) { index, item in
                        ActivityRow(item: item)
                            .fadeSlideIn(from: .trailing, delay: 0.05 * Double(index))

                        if index < min(activity.count - 1, 4) {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(
                    GlassmorphicCard(cornerRadius: 16) {
                        Color.clear
                    }
                )
            } else {
                GlassmorphicCard(cornerRadius: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No recent activity")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        GlassmorphicCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, value: isHovered)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                GlassmorphicCard(cornerRadius: 16) {
                    Color.clear
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct RecentProjectCard: View {
    let project: RenovationProject

    var body: some View {
        GlassmorphicCard(cornerRadius: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: project.roomType.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.projectName.isEmpty ? "Untitled Project" : project.projectName)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    Text(project.roomType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status badge
                Text(project.status.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor(project.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(project.status).opacity(0.15))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func statusColor(_ status: ProjectStatus) -> Color {
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

struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(item.color)
                .frame(width: 32, height: 32)
                .background(item.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        GlassmorphicCard(cornerRadius: 20) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GradientButton(
                    title: "Create Project",
                    icon: "plus",
                    colors: [.blue, .purple],
                    action: action
                )
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Projects List View

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RenovationProject.updatedAt, order: .reverse) private var projects: [RenovationProject]

    @State private var searchText = ""
    @State private var selectedFilter: ProjectFilter = .all
    @State private var showNewProject = false

    enum ProjectFilter: String, CaseIterable {
        case all = "All"
        case draft = "Draft"
        case estimated = "Estimated"
        case completed = "Completed"
    }

    var filteredProjects: [RenovationProject] {
        var result = projects

        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .draft:
            result = result.filter { $0.status == .draft }
        case .estimated:
            result = result.filter { $0.status == .estimated || $0.status == .approved }
        case .completed:
            result = result.filter { $0.status == .completed }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.roomType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        List {
            if filteredProjects.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredProjects) { project in
                    NavigationLink {
                        ProjectListDetailView(project: project)
                    } label: {
                        ProjectListRowView(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
        }
        .navigationTitle("Projects")
        .searchable(text: $searchText, prompt: "Search projects...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ProjectFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            ProjectInputView()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder.badge.questionmark")
        } description: {
            if searchText.isEmpty {
                Text("Create your first project to get started")
            } else {
                Text("No projects match '\(searchText)'")
            }
        } actions: {
            if searchText.isEmpty {
                Button {
                    showNewProject = true
                } label: {
                    Text("Create Project")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = filteredProjects[index]
            modelContext.delete(project)
        }
    }
}

// MARK: - Project Row View

struct ProjectListRowView: View {
    let project: RenovationProject

    var body: some View {
        HStack(spacing: 12) {
            // Room type icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: project.roomType.icon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.projectName.isEmpty ? "Untitled Project" : project.projectName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(project.roomType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if project.squareFootage > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(Int(project.squareFootage)) sq ft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(project.status.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())

                Text(project.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch project.status {
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

struct ProjectListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: RenovationProject

    @State private var showEstimate = false

    var body: some View {
        List {
            // Project Info Section
            Section("Project Details") {
                LabeledContent("Room Type", value: project.roomType.rawValue)
                LabeledContent("Square Footage", value: "\(Int(project.squareFootage)) sq ft")
                LabeledContent("Quality Tier", value: project.qualityTier.rawValue)
                LabeledContent("Urgency", value: project.urgency.rawValue)

                if !project.location.isEmpty {
                    LabeledContent("Location", value: project.location)
                }

                if !project.zipCode.isEmpty {
                    LabeledContent("ZIP Code", value: project.zipCode)
                }
            }

            // Budget Section
            Section("Budget") {
                if project.budgetMin > 0 || project.budgetMax > 0 {
                    LabeledContent("Range") {
                        Text("$\(Int(project.budgetMin)) - $\(Int(project.budgetMax))")
                    }
                } else {
                    Text("No budget set")
                        .foregroundStyle(.secondary)
                }
            }

            // Materials Section
            if !project.selectedMaterials.isEmpty {
                Section("Selected Materials") {
                    ForEach(project.selectedMaterials, id: \.self) { material in
                        Text(material)
                    }
                }
            }

            // Notes Section
            if !project.notes.isEmpty {
                Section("Notes") {
                    Text(project.notes)
                }
            }

            // Estimates Section
            if let estimates = project.estimates, !estimates.isEmpty {
                Section("Estimates") {
                    ForEach(estimates) { estimate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(estimate.formattedTotalRange)
                                .font(.headline)
                            Text(estimate.formattedTimeline)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Created \(estimate.createdAt, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Actions Section
            Section {
                Button {
                    showEstimate = true
                } label: {
                    Label("Generate New Estimate", systemImage: "sparkles")
                }
            }
        }
        .navigationTitle(project.projectName.isEmpty ? "Project Details" : project.projectName)
        .sheet(isPresented: $showEstimate) {
            NavigationStack {
                EstimateGenerationView(
                    viewModel: ProjectViewModel(
                        modelContext: modelContext,
                        geminiService: DIContainer.shared.geminiService
                    )
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Dashboard") {
    DashboardView()
        .environment(AppState.shared)
        .modelContainer(for: RenovationProject.self, inMemory: true)
}
