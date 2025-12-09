//
//  DashboardViewModel.swift
//  ProjectEstimate
//
//  ViewModel for dashboard analytics and project overview
//  Provides computed statistics and recent project data
//

import Foundation
import SwiftUI
import SwiftData
import OSLog

// MARK: - Dashboard Statistics

struct DashboardStatistics: Sendable {
    let totalProjects: Int
    let completedProjects: Int
    let pendingEstimates: Int
    let totalEstimatedValue: Double
    let averageProjectCost: Double
    let projectsByType: [RoomType: Int]
    let recentActivity: [ActivityItem]

    static let empty = DashboardStatistics(
        totalProjects: 0,
        completedProjects: 0,
        pendingEstimates: 0,
        totalEstimatedValue: 0,
        averageProjectCost: 0,
        projectsByType: [:],
        recentActivity: []
    )
}

struct ActivityItem: Identifiable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let timestamp: Date

    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Dashboard ViewModel

@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - State

    var statistics = DashboardStatistics.empty
    var recentProjects: [RenovationProject] = []
    var isLoading = false
    var error: Error?

    // MARK: - Quick Actions

    var showQuickEstimate = false
    var quickEstimateRoomType: RoomType = .kitchen
    var quickEstimateSquareFootage: String = ""

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.projectestimate", category: "Dashboard")

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Data Loading

    func loadDashboardData() async {
        isLoading = true

        do {
            // Fetch all projects
            let descriptor = FetchDescriptor<RenovationProject>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            let allProjects = try modelContext.fetch(descriptor)

            // Calculate statistics
            let completed = allProjects.filter { $0.status == .completed }.count
            let pending = allProjects.filter { $0.status == .draft || $0.status == .estimating }.count

            // Calculate total estimated value
            var totalValue: Double = 0
            for project in allProjects {
                if let estimates = project.estimates {
                    for estimate in estimates {
                        totalValue += estimate.averageTotalCost
                    }
                }
            }

            // Projects by type
            var byType: [RoomType: Int] = [:]
            for project in allProjects {
                byType[project.roomType, default: 0] += 1
            }

            // Recent activity
            let activity = allProjects.prefix(5).map { project in
                ActivityItem(
                    id: project.id,
                    title: project.projectName.isEmpty ? "Untitled Project" : project.projectName,
                    subtitle: project.roomType.rawValue,
                    icon: project.roomType.icon,
                    color: colorForStatus(project.status),
                    timestamp: project.updatedAt
                )
            }

            statistics = DashboardStatistics(
                totalProjects: allProjects.count,
                completedProjects: completed,
                pendingEstimates: pending,
                totalEstimatedValue: totalValue,
                averageProjectCost: allProjects.isEmpty ? 0 : totalValue / Double(allProjects.count),
                projectsByType: byType,
                recentActivity: Array(activity)
            )

            recentProjects = Array(allProjects.prefix(10))

            logger.info("Dashboard loaded: \(allProjects.count) projects")

        } catch {
            self.error = error
            logger.error("Failed to load dashboard: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Quick Estimate

    func performQuickEstimate() async -> RenovationProject? {
        guard let sqft = Double(quickEstimateSquareFootage), sqft > 0 else {
            return nil
        }

        let project = RenovationProject(
            projectName: "Quick \(quickEstimateRoomType.rawValue) Estimate",
            roomType: quickEstimateRoomType,
            squareFootage: sqft
        )

        modelContext.insert(project)

        do {
            try modelContext.save()
            await loadDashboardData()
            return project
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Project Actions

    func deleteProject(_ project: RenovationProject) {
        modelContext.delete(project)

        Task {
            do {
                try modelContext.save()
                await loadDashboardData()
            } catch {
                self.error = error
            }
        }
    }

    func duplicateProject(_ project: RenovationProject) -> RenovationProject {
        let newProject = RenovationProject(
            projectName: "\(project.projectName) (Copy)",
            roomType: project.roomType,
            squareFootage: project.squareFootage,
            location: project.location,
            zipCode: project.zipCode,
            budgetMin: project.budgetMin,
            budgetMax: project.budgetMax,
            selectedMaterials: project.selectedMaterials,
            qualityTier: project.qualityTier,
            notes: project.notes,
            urgency: project.urgency,
            includesPermits: project.includesPermits,
            includesDesign: project.includesDesign
        )

        modelContext.insert(newProject)

        Task {
            do {
                try modelContext.save()
                await loadDashboardData()
            } catch {
                self.error = error
            }
        }

        return newProject
    }

    // MARK: - Helpers

    private func colorForStatus(_ status: ProjectStatus) -> Color {
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

    // MARK: - Formatting

    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: statistics.totalEstimatedValue)) ?? "$0"
    }

    var formattedAverageCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: statistics.averageProjectCost)) ?? "$0"
    }
}

// MARK: - Preview Helper

extension DashboardViewModel {
    static func preview(modelContext: ModelContext) -> DashboardViewModel {
        DashboardViewModel(modelContext: modelContext)
    }
}
