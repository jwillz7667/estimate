//
//  SubscriptionService.swift
//  ProjectEstimate
//
//  StoreKit 2 subscription management with Apple Pay integration
//  Handles subscription tiers, trials, and entitlements
//

import Foundation
import StoreKit
import SwiftUI
import OSLog

// MARK: - Product Identifiers

enum SubscriptionProductID: String, CaseIterable {
    case professionalMonthly = "com.projectestimate.pro.monthly"
    case professionalAnnual = "com.projectestimate.pro.annual"
    case enterpriseMonthly = "com.projectestimate.enterprise.monthly"
    case enterpriseAnnual = "com.projectestimate.enterprise.annual"

    var tier: SubscriptionTier {
        switch self {
        case .professionalMonthly, .professionalAnnual:
            return .professional
        case .enterpriseMonthly, .enterpriseAnnual:
            return .enterprise
        }
    }

    var isAnnual: Bool {
        self == .professionalAnnual || self == .enterpriseAnnual
    }

    var groupId: String {
        "com.projectestimate.subscriptions"
    }
}

// MARK: - Introductory Offer Info

struct IntroductoryOfferInfo: Sendable {
    let type: OfferType
    let period: String
    let periodCount: Int
    let price: Decimal
    let displayPrice: String

    enum OfferType: String, Sendable {
        case freeTrial = "Free Trial"
        case payUpFront = "Pay Up Front"
        case payAsYouGo = "Pay As You Go"
    }
}

// MARK: - Subscription Status

struct SubscriptionStatus: Sendable {
    let tier: SubscriptionTier
    let isActive: Bool
    let expirationDate: Date?
    let willRenew: Bool
    let isTrialPeriod: Bool
    let trialDaysRemaining: Int?

    static let free = SubscriptionStatus(
        tier: .free,
        isActive: true,
        expirationDate: nil,
        willRenew: false,
        isTrialPeriod: false,
        trialDaysRemaining: nil
    )
}

// MARK: - Subscription Service Protocol

protocol SubscriptionServiceProtocol: Sendable {
    func loadProducts() async throws -> [Product]
    func purchase(_ product: Product) async throws -> StoreKit.Transaction?
    func checkSubscriptionStatus() async -> SubscriptionStatus
    func restorePurchases() async throws
    func startFreeTrial() async throws
}

// MARK: - Subscription Service

@MainActor
@Observable
final class SubscriptionService: SubscriptionServiceProtocol {

    // MARK: - Properties

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var subscriptionStatus: SubscriptionStatus = .free
    var isLoading = false
    var error: Error?

    private var updateListenerTask: Task<Void, Error>?
    private let logger = Logger(subsystem: "com.projectestimate", category: "Subscription")

    // MARK: - Trial Configuration

    private let trialDays = 7
    private let trialStartKey = "trialStartDate"

    // MARK: - Initialization

    init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProductsAndStatus()
        }
    }

    nonisolated func cancelUpdateListener() {
        Task { @MainActor in
            updateListenerTask?.cancel()
        }
    }

    // MARK: - Product Loading

    func loadProducts() async throws -> [Product] {
        isLoading = true
        defer { isLoading = false }

        let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }

        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            logger.info("Loaded \(storeProducts.count) products")
            return products
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                logger.info("Purchase successful: \(product.id)")
                return transaction

            case .userCancelled:
                logger.info("User cancelled purchase")
                return nil

            case .pending:
                logger.info("Purchase pending")
                return nil

            @unknown default:
                return nil
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Subscription Status

    func checkSubscriptionStatus() async -> SubscriptionStatus {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if let productID = SubscriptionProductID(rawValue: transaction.productID) {
                let expirationDate = transaction.expirationDate
                let isTrialPeriod = transaction.offer?.type == .introductory

                subscriptionStatus = SubscriptionStatus(
                    tier: productID.tier,
                    isActive: true,
                    expirationDate: expirationDate,
                    willRenew: transaction.revocationDate == nil,
                    isTrialPeriod: isTrialPeriod,
                    trialDaysRemaining: isTrialPeriod ? calculateTrialDaysRemaining(expirationDate) : nil
                )

                return subscriptionStatus
            }
        }

        // Check for free trial
        if isInFreeTrial() {
            let trialDaysRemaining = calculateLocalTrialDaysRemaining()
            subscriptionStatus = SubscriptionStatus(
                tier: .professional,
                isActive: true,
                expirationDate: getTrialEndDate(),
                willRenew: false,
                isTrialPeriod: true,
                trialDaysRemaining: trialDaysRemaining
            )
            return subscriptionStatus
        }

        subscriptionStatus = .free
        return subscriptionStatus
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updateSubscriptionStatus()
        logger.info("Purchases restored")
    }

    // MARK: - Free Trial

    func startFreeTrial() async throws {
        guard !hasUsedFreeTrial() else {
            throw SubscriptionError.trialAlreadyUsed
        }

        UserDefaults.standard.set(Date(), forKey: trialStartKey)
        await updateSubscriptionStatus()
        logger.info("Free trial started")
    }

    func isInFreeTrial() -> Bool {
        guard let startDate = UserDefaults.standard.object(forKey: trialStartKey) as? Date else {
            return false
        }

        let endDate = Calendar.current.date(byAdding: .day, value: trialDays, to: startDate) ?? Date()
        return Date() < endDate
    }

    func hasUsedFreeTrial() -> Bool {
        UserDefaults.standard.object(forKey: trialStartKey) != nil
    }

    func getTrialEndDate() -> Date? {
        guard let startDate = UserDefaults.standard.object(forKey: trialStartKey) as? Date else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: trialDays, to: startDate)
    }

    // MARK: - Private Methods

    private func loadProductsAndStatus() async {
        do {
            _ = try await loadProducts()
            await updateSubscriptionStatus()
        } catch {
            self.error = error
        }
    }

    private func updateSubscriptionStatus() async {
        _ = await checkSubscriptionStatus()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }

                await self.updateSubscriptionStatus()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func calculateTrialDaysRemaining(_ expirationDate: Date?) -> Int {
        guard let expiration = expirationDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
        return max(0, days)
    }

    private func calculateLocalTrialDaysRemaining() -> Int {
        guard let endDate = getTrialEndDate() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }

    // MARK: - Helper Methods

    func product(for productID: SubscriptionProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func isSubscribed(to tier: SubscriptionTier) -> Bool {
        subscriptionStatus.isActive && subscriptionStatus.tier == tier
    }

    func canAccessFeature(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .unlimitedEstimates:
            return subscriptionStatus.tier != .free
        case .imageGeneration:
            return subscriptionStatus.tier != .free
        case .pdfExport:
            return true // Available on free tier
        case .customBranding:
            return subscriptionStatus.tier == .enterprise
        case .apiAccess:
            return subscriptionStatus.tier == .enterprise
        case .prioritySupport:
            return subscriptionStatus.tier == .enterprise
        }
    }

    // MARK: - Introductory Offers

    /// Gets introductory offer information for a product
    func getIntroductoryOffer(for product: Product) async -> IntroductoryOfferInfo? {
        guard let subscription = product.subscription else { return nil }

        // Check eligibility for introductory offers
        let isEligible = await subscription.isEligibleForIntroOffer

        guard isEligible, let introOffer = subscription.introductoryOffer else {
            return nil
        }

        let offerType: IntroductoryOfferInfo.OfferType
        switch introOffer.paymentMode {
        case .freeTrial:
            offerType = .freeTrial
        case .payUpFront:
            offerType = .payUpFront
        case .payAsYouGo:
            offerType = .payAsYouGo
        default:
            offerType = .freeTrial
        }

        let period = formatPeriod(introOffer.period)

        return IntroductoryOfferInfo(
            type: offerType,
            period: period,
            periodCount: introOffer.periodCount,
            price: introOffer.price,
            displayPrice: introOffer.displayPrice
        )
    }

    /// Checks if user is eligible for any introductory offer
    func isEligibleForIntroOffer() async -> Bool {
        for product in products {
            if let subscription = product.subscription {
                let isEligible = await subscription.isEligibleForIntroOffer
                if isEligible {
                    return true
                }
            }
        }
        return false
    }

    /// Purchases with introductory offer if eligible
    func purchaseWithIntroOffer(_ product: Product) async throws -> StoreKit.Transaction? {
        guard let subscription = product.subscription else {
            return try await purchase(product)
        }

        let isEligible = await subscription.isEligibleForIntroOffer

        if isEligible, let _ = subscription.introductoryOffer {
            logger.info("Purchasing with introductory offer: \(product.id)")
        }

        return try await purchase(product)
    }

    // MARK: - Subscription Management

    /// Gets the current subscription renewal info
    func getSubscriptionRenewalInfo() async -> Product.SubscriptionInfo.RenewalInfo? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if let productID = SubscriptionProductID(rawValue: transaction.productID) {
                if let product = product(for: productID),
                   let subscription = product.subscription {
                    do {
                        let statuses = try await subscription.status
                        for status in statuses {
                            if case .verified(let renewalInfo) = status.renewalInfo {
                                return renewalInfo
                            }
                        }
                    } catch {
                        logger.error("Failed to get subscription status: \(error.localizedDescription)")
                    }
                }
            }
        }
        return nil
    }

    /// Gets all subscription statuses for the group
    func getSubscriptionGroupStatus() async -> [Product.SubscriptionInfo.Status] {
        var statuses: [Product.SubscriptionInfo.Status] = []

        for product in products {
            guard let subscription = product.subscription else { continue }

            do {
                let productStatuses = try await subscription.status
                statuses.append(contentsOf: productStatuses)
            } catch {
                logger.error("Failed to get subscription status: \(error.localizedDescription)")
            }
        }

        return statuses
    }

    /// Checks if there's an active subscription in the group
    func hasActiveSubscriptionInGroup() async -> Bool {
        for product in products {
            guard let subscription = product.subscription else { continue }

            do {
                let statuses = try await subscription.status
                for status in statuses {
                    switch status.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                        return true
                    default:
                        continue
                    }
                }
            } catch {
                logger.error("Failed to get subscription status: \(error.localizedDescription)")
            }
        }
        return false
    }

    // MARK: - Offer Codes

    /// Presents the offer code redemption sheet
    @available(iOS 16.0, *)
    func presentOfferCodeRedemption() async {
        await MainActor.run {
            // Present offer code redemption sheet using StoreKit
            // Note: This requires configuration in App Store Connect
        }
    }

    // MARK: - Usage Tracking

    /// Tracks feature usage for analytics
    func trackFeatureUsage(_ feature: PremiumFeature) {
        let usageKey = "usage_\(feature.rawValue)"
        let currentCount = UserDefaults.standard.integer(forKey: usageKey)
        UserDefaults.standard.set(currentCount + 1, forKey: usageKey)
    }

    /// Gets current month's usage count for a feature
    func getMonthlyUsage(_ feature: PremiumFeature) -> Int {
        let usageKey = "usage_\(feature.rawValue)"
        return UserDefaults.standard.integer(forKey: usageKey)
    }

    /// Resets monthly usage (call at start of billing period)
    func resetMonthlyUsage() {
        for feature in PremiumFeature.allCases {
            let usageKey = "usage_\(feature.rawValue)"
            UserDefaults.standard.set(0, forKey: usageKey)
        }
    }

    // MARK: - Helper Methods

    private func formatPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "year" : "\(period.value) years"
        @unknown default:
            return "\(period.value) periods"
        }
    }
}

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case unlimitedEstimates = "Unlimited Estimates"
    case imageGeneration = "AI Image Generation"
    case pdfExport = "PDF Export"
    case customBranding = "Custom Branding"
    case apiAccess = "API Access"
    case prioritySupport = "Priority Support"

    var icon: String {
        switch self {
        case .unlimitedEstimates: return "infinity"
        case .imageGeneration: return "photo.fill"
        case .pdfExport: return "doc.fill"
        case .customBranding: return "paintbrush.fill"
        case .apiAccess: return "server.rack"
        case .prioritySupport: return "headphones"
        }
    }

    var tier: SubscriptionTier {
        switch self {
        case .unlimitedEstimates, .imageGeneration:
            return .professional
        case .pdfExport:
            return .free
        case .customBranding, .apiAccess, .prioritySupport:
            return .enterprise
        }
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case verificationFailed
    case trialAlreadyUsed
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        case .verificationFailed:
            return "Transaction verification failed"
        case .trialAlreadyUsed:
            return "You have already used your free trial"
        case .restoreFailed:
            return "Failed to restore purchases"
        }
    }
}

// MARK: - Environment Key

struct SubscriptionServiceKey: EnvironmentKey {
    @MainActor static let defaultValue = SubscriptionService()
}

extension EnvironmentValues {
    var subscriptionService: SubscriptionService {
        get { self[SubscriptionServiceKey.self] }
        set { self[SubscriptionServiceKey.self] = newValue }
    }
}
