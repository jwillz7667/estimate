//
//  SubscriptionManagementView.swift
//  ProjectEstimate
//
//  Comprehensive subscription management interface
//  Displays current plan, usage, billing info, and upgrade options
//

import SwiftUI
import StoreKit

// MARK: - Subscription Management View

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var showCancelConfirmation = false
    @State private var showPaywall = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Plan Card
                    currentPlanCard

                    // Trial Banner (if applicable)
                    if subscriptionService.subscriptionStatus.isTrialPeriod {
                        trialBanner
                    }

                    // Usage Stats
                    usageStatsSection

                    // Billing Info
                    if subscriptionService.subscriptionStatus.tier != .free {
                        billingInfoSection
                    }

                    // Plan Benefits
                    planBenefitsSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Cancel Subscription", isPresented: $showCancelConfirmation) {
                Button("Keep Subscription", role: .cancel) {}
                Button("Cancel", role: .destructive) {
                    // Note: App Store subscriptions must be cancelled through Settings
                    openSubscriptionManagement()
                }
            } message: {
                Text("To cancel your subscription, you'll be redirected to your Apple ID subscription settings.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
        }
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        VStack(spacing: 16) {
            // Plan Icon
            ZStack {
                Circle()
                    .fill(tierGradient)
                    .frame(width: 80, height: 80)

                Image(systemName: tierIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            // Plan Name
            VStack(spacing: 4) {
                Text(subscriptionService.subscriptionStatus.tier.rawValue)
                    .font(.title.bold())

                if subscriptionService.subscriptionStatus.isTrialPeriod {
                    Text("Trial Period")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else if subscriptionService.subscriptionStatus.tier == .free {
                    Text("Limited Features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Active Subscription")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            // Upgrade button for free users
            if subscriptionService.subscriptionStatus.tier == .free {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Trial Ends Soon")
                    .font(.headline)

                if let daysRemaining = subscriptionService.subscriptionStatus.trialDaysRemaining {
                    Text("\(daysRemaining) days remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                showPaywall = true
            } label: {
                Text("Subscribe")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Usage Stats Section

    private var usageStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Month's Usage")
                .font(.headline)

            HStack(spacing: 16) {
                // Estimates
                UsageStatCard(
                    title: "Estimates",
                    current: subscriptionService.getMonthlyUsage(.unlimitedEstimates),
                    limit: subscriptionService.subscriptionStatus.tier.estimateLimit,
                    icon: "doc.text.fill",
                    color: .blue
                )

                // Images
                UsageStatCard(
                    title: "Images",
                    current: subscriptionService.getMonthlyUsage(.imageGeneration),
                    limit: subscriptionService.subscriptionStatus.tier.imageLimit,
                    icon: "photo.fill",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Billing Info Section

    private var billingInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Billing")
                .font(.headline)

            VStack(spacing: 12) {
                // Next billing date
                if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
                    BillingInfoRow(
                        title: subscriptionService.subscriptionStatus.willRenew ? "Next Billing Date" : "Expires On",
                        value: expirationDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }

                // Auto-renew status
                BillingInfoRow(
                    title: "Auto-Renew",
                    value: subscriptionService.subscriptionStatus.willRenew ? "On" : "Off",
                    icon: "arrow.triangle.2.circlepath",
                    valueColor: subscriptionService.subscriptionStatus.willRenew ? .green : .orange
                )

                // Manage subscription button
                Button {
                    openSubscriptionManagement()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Manage in Settings")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Plan Benefits Section

    private var planBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Benefits")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(subscriptionService.subscriptionStatus.tier.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Text(feature)
                            .font(.subheadline)

                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Restore purchases
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restore Purchases")
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Cancel subscription (for paid users)
            if subscriptionService.subscriptionStatus.tier != .free &&
               !subscriptionService.subscriptionStatus.isTrialPeriod {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel Subscription")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.top, 8)
            }

            // Terms and Privacy
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://projectestimate.app/terms")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("Privacy Policy", destination: URL(string: "https://projectestimate.app/privacy")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .padding(32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Computed Properties

    private var tierGradient: LinearGradient {
        switch subscriptionService.subscriptionStatus.tier {
        case .free:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .professional:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .enterprise:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var tierIcon: String {
        switch subscriptionService.subscriptionStatus.tier {
        case .free: return "person.fill"
        case .professional: return "star.fill"
        case .enterprise: return "building.2.fill"
        }
    }

    // MARK: - Actions

    private func restorePurchases() async {
        isLoading = true

        do {
            try await subscriptionService.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Usage Stat Card

struct UsageStatCard: View {
    let title: String
    let current: Int
    let limit: Int
    let icon: String
    let color: Color

    private var progress: Double {
        guard limit > 0 && limit != Int.max else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }

    private var displayLimit: String {
        limit == Int.max ? "Unlimited" : "\(limit)"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(current)")
                .font(.title.bold())

            if limit != Int.max {
                ProgressView(value: progress)
                    .tint(progress > 0.8 ? .orange : color)

                Text("of \(displayLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Unlimited")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Billing Info Row

struct BillingInfoRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Entitlement Gate View

struct EntitlementGateView<Content: View>: View {
    let feature: PremiumFeature
    @ViewBuilder let content: () -> Content

    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showPaywall = false

    var body: some View {
        if subscriptionService.canAccessFeature(feature) {
            content()
        } else {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("Upgrade Required")
                    .font(.headline)

                Text("This feature requires a \(feature.tier.rawValue) subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade Now")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
            }
            .padding()
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Usage Limit Alert Modifier

struct UsageLimitAlertModifier: ViewModifier {
    let feature: PremiumFeature
    @Binding var isPresented: Bool

    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .alert("Usage Limit Reached", isPresented: $isPresented) {
                Button("Upgrade") {
                    showPaywall = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've reached your monthly limit for \(feature.rawValue.lowercased()). Upgrade to continue using this feature.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
    }
}

extension View {
    func usageLimitAlert(for feature: PremiumFeature, isPresented: Binding<Bool>) -> some View {
        modifier(UsageLimitAlertModifier(feature: feature, isPresented: isPresented))
    }
}

// MARK: - Preview

#Preview("Subscription Management") {
    SubscriptionManagementView()
        .environment(SubscriptionService())
}

#Preview("Entitlement Gate") {
    EntitlementGateView(feature: .imageGeneration) {
        Text("Premium Content Here")
    }
    .environment(SubscriptionService())
}
