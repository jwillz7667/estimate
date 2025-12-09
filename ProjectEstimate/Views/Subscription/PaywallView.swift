//
//  PaywallView.swift
//  ProjectEstimate
//
//  Modern paywall UI with subscription options and Apple Pay
//  Supports free trial and multiple subscription tiers
//

import SwiftUI
import StoreKit

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var billingPeriod: BillingPeriod = .annual
    @State private var introOfferInfo: IntroductoryOfferInfo?
    @State private var isEligibleForIntroOffer = false

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual"

        var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual: return "Save 17%"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Trial banner
                    if !subscriptionService.hasUsedFreeTrial() {
                        trialBanner
                    }

                    // Billing toggle
                    billingToggle

                    // Subscription options
                    subscriptionOptions

                    // Features comparison
                    featuresSection

                    // Legal
                    legalSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task {
                            await restorePurchases()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isPurchasing {
                    purchasingOverlay
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "house.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Unlock Full Potential")
                    .font(.title.bold())

                Text("Get unlimited AI estimates, image generation, and premium features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        Button {
            Task {
                await startTrial()
            }
        } label: {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    if let introOffer = introOfferInfo, introOffer.type == .freeTrial {
                        Text("Start \(introOffer.periodCount)-\(introOffer.period.capitalized) Free Trial")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Then \(selectedProduct?.displayPrice ?? "") per \(billingPeriod == .annual ? "year" : "month")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("Start 7-Day Free Trial")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Full access to Professional features")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            ForEach(BillingPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        billingPeriod = period
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.medium))

                        if let savings = period.savings {
                            Text(savings)
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(billingPeriod == period ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        billingPeriod == period ? Color.blue : Color.clear
                    )
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subscription Options

    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            // Professional
            SubscriptionCard(
                title: "Professional",
                price: priceForProduct(.professional),
                period: billingPeriod == .annual ? "/year" : "/month",
                features: [
                    "100 AI estimates per month",
                    "50 image generations",
                    "Full materials library",
                    "Priority processing",
                    "Custom PDF branding"
                ],
                isPopular: true,
                isSelected: selectedTier == .professional,
                action: {
                    selectProduct(.professional)
                }
            )

            // Enterprise
            SubscriptionCard(
                title: "Enterprise",
                price: priceForProduct(.enterprise),
                period: billingPeriod == .annual ? "/year" : "/month",
                features: [
                    "Unlimited estimates",
                    "Unlimited image generation",
                    "API access",
                    "Multi-user accounts",
                    "Priority support",
                    "Custom integrations"
                ],
                isPopular: false,
                isSelected: selectedTier == .enterprise,
                action: {
                    selectProduct(.enterprise)
                }
            )
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(PremiumFeature.allCases, id: \.self) { feature in
                    FeatureRow(feature: feature)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 12) {
            // Purchase button
            if selectedProduct != nil {
                Button {
                    Task {
                        await purchase()
                    }
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Subscribe with Apple Pay")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            // Terms
            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .font(.caption)

                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    .font(.caption)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Purchasing Overlay

    private var purchasingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Processing...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Computed Properties

    private var selectedTier: SubscriptionTier? {
        guard let product = selectedProduct else { return nil }
        return SubscriptionProductID(rawValue: product.id)?.tier
    }

    // MARK: - Actions

    private func selectProduct(_ tier: SubscriptionTier) {
        let productID: SubscriptionProductID

        switch (tier, billingPeriod) {
        case (.professional, .monthly):
            productID = .professionalMonthly
        case (.professional, .annual):
            productID = .professionalAnnual
        case (.enterprise, .monthly):
            productID = .enterpriseMonthly
        case (.enterprise, .annual):
            productID = .enterpriseAnnual
        default:
            return
        }

        withAnimation(.spring(response: 0.3)) {
            selectedProduct = subscriptionService.product(for: productID)
        }
    }

    private func priceForProduct(_ tier: SubscriptionTier) -> String {
        let productID: SubscriptionProductID

        switch (tier, billingPeriod) {
        case (.professional, .monthly):
            productID = .professionalMonthly
        case (.professional, .annual):
            productID = .professionalAnnual
        case (.enterprise, .monthly):
            productID = .enterpriseMonthly
        case (.enterprise, .annual):
            productID = .enterpriseAnnual
        default:
            return "$0"
        }

        guard let product = subscriptionService.product(for: productID) else {
            return tier.monthlyPrice.formatted(.currency(code: "USD"))
        }

        return product.displayPrice
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true

        do {
            _ = try await subscriptionService.purchase(product)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true

        do {
            try await subscriptionService.restorePurchases()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func startTrial() async {
        // If we have an intro offer from StoreKit, use that
        if isEligibleForIntroOffer, let product = selectedProduct {
            isPurchasing = true
            do {
                _ = try await subscriptionService.purchaseWithIntroOffer(product)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        } else {
            // Fall back to local trial
            do {
                try await subscriptionService.startFreeTrial()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func checkIntroOfferEligibility() async {
        isEligibleForIntroOffer = await subscriptionService.isEligibleForIntroOffer()

        if let product = selectedProduct {
            introOfferInfo = await subscriptionService.getIntroductoryOffer(for: product)
        }
    }
}

// MARK: - Paywall Presentation Modifier

struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    let feature: PremiumFeature?

    @Environment(SubscriptionService.self) private var subscriptionService

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView()
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue, let feature = feature {
                    // Track which feature triggered the paywall
                    subscriptionService.trackFeatureUsage(feature)
                }
            }
    }
}

extension View {
    func paywall(isPresented: Binding<Bool>, for feature: PremiumFeature? = nil) -> some View {
        modifier(PaywallModifier(isPresented: isPresented, feature: feature))
    }
}

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let title: String
    let price: String
    let period: String
    let features: [String]
    let isPopular: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.headline)

                            if isPopular {
                                Text("POPULAR")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(price)
                                .font(.title.bold())
                            Text(period)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.green)

                            Text(feature)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)

            Text(feature.rawValue)
                .font(.subheadline)

            Spacer()

            tierBadge(for: feature.tier)
        }
    }

    @ViewBuilder
    private func tierBadge(for tier: SubscriptionTier) -> some View {
        switch tier {
        case .free:
            Text("FREE")
                .font(.caption2.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())

        case .professional:
            Text("PRO")
                .font(.caption2.bold())
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())

        case .enterprise:
            Text("ENTERPRISE")
                .font(.caption2.bold())
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Paywall Trigger Button

struct UpgradeButton: View {
    @State private var showPaywall = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text("Upgrade")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environment(SubscriptionService())
}
