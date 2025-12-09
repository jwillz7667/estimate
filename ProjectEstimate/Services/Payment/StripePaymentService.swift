//
//  StripePaymentService.swift
//  ProjectEstimate
//
//  Stripe payment integration for web-based subscriptions
//  Supports Apple Pay, credit cards, and subscription management
//

import Foundation
import PassKit
import OSLog
import SwiftUI

// MARK: - Stripe Configuration

enum StripeConfiguration {
    // IMPORTANT: Replace with your actual Stripe keys
    // These should be loaded from environment or secure configuration
    static let publishableKey = "pk_test_YOUR_PUBLISHABLE_KEY"
    static let merchantIdentifier = "merchant.com.projectestimate"

    // API Endpoints - Replace with your actual backend URL
    static let baseURL = "https://api.projectestimate.app/v1"
    static let createPaymentIntentEndpoint = "/stripe/create-payment-intent"
    static let createSubscriptionEndpoint = "/stripe/create-subscription"
    static let confirmSubscriptionEndpoint = "/stripe/confirm-subscription"
    static let cancelSubscriptionEndpoint = "/stripe/cancel-subscription"
    static let getSubscriptionEndpoint = "/stripe/subscription"
    static let createCustomerEndpoint = "/stripe/create-customer"
    static let getCustomerEndpoint = "/stripe/customer"
    static let webhookEndpoint = "/stripe/webhook"

    // Stripe Price IDs - Configure in Stripe Dashboard
    enum PriceID {
        static let proMonthly = "price_professional_monthly"
        static let proAnnual = "price_professional_annual"
        static let enterpriseMonthly = "price_enterprise_monthly"
        static let enterpriseAnnual = "price_enterprise_annual"

        static func priceID(for tier: SubscriptionTier, annual: Bool) -> String {
            switch (tier, annual) {
            case (.professional, false): return proMonthly
            case (.professional, true): return proAnnual
            case (.enterprise, false): return enterpriseMonthly
            case (.enterprise, true): return enterpriseAnnual
            default: return proMonthly
            }
        }
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, Sendable {
    case applePay = "apple_pay"
    case creditCard = "credit_card"
    case googlePay = "google_pay"
    case bankTransfer = "bank_transfer"

    var displayName: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .creditCard: return "Credit Card"
        case .googlePay: return "Google Pay"
        case .bankTransfer: return "Bank Transfer"
        }
    }

    var iconName: String {
        switch self {
        case .applePay: return "apple.logo"
        case .creditCard: return "creditcard.fill"
        case .googlePay: return "g.circle.fill"
        case .bankTransfer: return "building.columns.fill"
        }
    }
}

// MARK: - Stripe Customer

struct StripeCustomer: Codable, Sendable {
    let id: String
    let email: String
    let name: String?
    let defaultPaymentMethod: String?
    let subscriptionId: String?
    let subscriptionStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case defaultPaymentMethod = "default_payment_method"
        case subscriptionId = "subscription_id"
        case subscriptionStatus = "subscription_status"
    }
}

// MARK: - Stripe Subscription

struct StripeSubscription: Codable, Sendable {
    let id: String
    let customerId: String
    let status: SubscriptionStatusType
    let priceId: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelAtPeriodEnd: Bool
    let trialStart: Date?
    let trialEnd: Date?
    let defaultPaymentMethod: String?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case status
        case priceId = "price_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case trialStart = "trial_start"
        case trialEnd = "trial_end"
        case defaultPaymentMethod = "default_payment_method"
    }

    enum SubscriptionStatusType: String, Codable, Sendable {
        case active
        case pastDue = "past_due"
        case unpaid
        case canceled
        case incomplete
        case incompleteExpired = "incomplete_expired"
        case trialing
        case paused
    }

    var isActive: Bool {
        status == .active || status == .trialing
    }

    var isInTrial: Bool {
        status == .trialing
    }

    var trialDaysRemaining: Int? {
        guard let trialEnd = trialEnd else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0
        return max(0, days)
    }
}

// MARK: - Payment Intent

struct PaymentIntent: Codable, Sendable {
    let id: String
    let clientSecret: String
    let amount: Int
    let currency: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case clientSecret = "client_secret"
        case amount
        case currency
        case status
    }
}

// MARK: - Create Subscription Request

struct CreateSubscriptionRequest: Codable, Sendable {
    let customerId: String
    let priceId: String
    let paymentMethodId: String?
    let trialDays: Int?
    let couponId: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case priceId = "price_id"
        case paymentMethodId = "payment_method_id"
        case trialDays = "trial_days"
        case couponId = "coupon_id"
        case metadata
    }
}

// MARK: - Stripe Payment Service

@MainActor
@Observable
final class StripePaymentService {

    // MARK: - Properties

    var customer: StripeCustomer?
    var subscription: StripeSubscription?
    var isLoading = false
    var error: Error?

    private let networkService: NetworkService
    private let keychainService: KeychainService
    private let logger = Logger(subsystem: "com.projectestimate", category: "StripePayment")

    // Cached customer ID
    private var cachedCustomerId: String? {
        get { UserDefaults.standard.string(forKey: "stripeCustomerId") }
        set { UserDefaults.standard.set(newValue, forKey: "stripeCustomerId") }
    }

    // MARK: - Initialization

    init(networkService: NetworkService = NetworkService(), keychainService: KeychainService = .shared) {
        self.networkService = networkService
        self.keychainService = keychainService
    }

    // MARK: - Customer Management

    /// Creates or retrieves a Stripe customer for the current user
    func getOrCreateCustomer(email: String, name: String?) async throws -> StripeCustomer {
        isLoading = true
        defer { isLoading = false }

        // Check for cached customer
        if let customerId = cachedCustomerId {
            do {
                let customer = try await getCustomer(customerId: customerId)
                self.customer = customer
                return customer
            } catch {
                logger.warning("Cached customer not found, creating new one")
            }
        }

        // Create new customer
        let customer = try await createCustomer(email: email, name: name)
        self.customer = customer
        cachedCustomerId = customer.id
        return customer
    }

    private func createCustomer(email: String, name: String?) async throws -> StripeCustomer {
        let requestBody: [String: Any] = [
            "email": email,
            "name": name ?? ""
        ]

        guard let url = URL(string: "\(StripeConfiguration.baseURL)\(StripeConfiguration.createCustomerEndpoint)") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StripeError.customerCreationFailed
        }

        let customer = try JSONDecoder().decode(StripeCustomer.self, from: data)
        logger.info("Created Stripe customer: \(customer.id)")
        return customer
    }

    private func getCustomer(customerId: String) async throws -> StripeCustomer {
        guard let url = URL(string: "\(StripeConfiguration.baseURL)\(StripeConfiguration.getCustomerEndpoint)/\(customerId)") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StripeError.customerNotFound
        }

        return try JSONDecoder().decode(StripeCustomer.self, from: data)
    }

    // MARK: - Subscription Management

    /// Creates a new subscription with optional trial
    func createSubscription(
        tier: SubscriptionTier,
        isAnnual: Bool,
        paymentMethodId: String?,
        trialDays: Int? = 7,
        couponId: String? = nil
    ) async throws -> StripeSubscription {
        isLoading = true
        defer { isLoading = false }

        guard let customer = customer else {
            throw StripeError.noCustomer
        }

        let priceId = StripeConfiguration.PriceID.priceID(for: tier, annual: isAnnual)

        let subscriptionRequest = CreateSubscriptionRequest(
            customerId: customer.id,
            priceId: priceId,
            paymentMethodId: paymentMethodId,
            trialDays: trialDays,
            couponId: couponId,
            metadata: [
                "tier": tier.rawValue,
                "billing_cycle": isAnnual ? "annual" : "monthly"
            ]
        )

        guard let url = URL(string: "\(StripeConfiguration.baseURL)\(StripeConfiguration.createSubscriptionEndpoint)") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(subscriptionRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Subscription creation failed: \(errorMessage)")
            throw StripeError.subscriptionCreationFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let subscription = try decoder.decode(StripeSubscription.self, from: data)

        self.subscription = subscription
        logger.info("Created subscription: \(subscription.id)")
        return subscription
    }

    /// Retrieves the current subscription
    func getSubscription() async throws -> StripeSubscription? {
        guard let customer = customer else {
            return nil
        }

        guard let url = URL(string: "\(StripeConfiguration.baseURL)\(StripeConfiguration.getSubscriptionEndpoint)/\(customer.id)") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StripeError.networkError
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw StripeError.subscriptionNotFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let subscription = try decoder.decode(StripeSubscription.self, from: data)

        self.subscription = subscription
        return subscription
    }

    /// Cancels the current subscription at period end
    func cancelSubscription() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let subscription = subscription else {
            throw StripeError.noSubscription
        }

        guard let url = URL(string: "\(StripeConfiguration.baseURL)\(StripeConfiguration.cancelSubscriptionEndpoint)/\(subscription.id)") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StripeError.cancellationFailed
        }

        // Refresh subscription status
        _ = try await getSubscription()
        logger.info("Subscription cancelled: \(subscription.id)")
    }

    // MARK: - Apple Pay Support

    /// Checks if Apple Pay is available on this device
    func isApplePayAvailable() -> Bool {
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex, .discover])
    }

    /// Creates an Apple Pay payment request
    func createApplePayRequest(
        tier: SubscriptionTier,
        isAnnual: Bool
    ) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = StripeConfiguration.merchantIdentifier
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"

        let price = isAnnual ? tier.annualPrice : tier.monthlyPrice
        let period = isAnnual ? "year" : "month"

        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "\(tier.rawValue) Subscription",
                amount: NSDecimalNumber(value: price),
                type: .final
            ),
            PKPaymentSummaryItem(
                label: "ProjectEstimate",
                amount: NSDecimalNumber(value: price),
                type: .final
            )
        ]

        // Add recurring payment request for subscriptions
        if #available(iOS 16.0, *) {
            let recurringPayment = PKRecurringPaymentRequest(
                paymentDescription: "\(tier.rawValue) - \(period)ly",
                regularBilling: PKRecurringPaymentSummaryItem(
                    label: "\(tier.rawValue) Subscription",
                    amount: NSDecimalNumber(value: price)
                ),
                managementURL: URL(string: "https://projectestimate.app/account")!
            )
            request.recurringPaymentRequest = recurringPayment
        }

        return request
    }

    /// Processes Apple Pay payment result
    func processApplePayPayment(
        _ payment: PKPayment,
        tier: SubscriptionTier,
        isAnnual: Bool
    ) async throws -> StripeSubscription {
        // Convert Apple Pay token to Stripe payment method
        let paymentMethodId = try await createPaymentMethodFromApplePay(payment)

        // Create subscription with payment method
        return try await createSubscription(
            tier: tier,
            isAnnual: isAnnual,
            paymentMethodId: paymentMethodId,
            trialDays: 7
        )
    }

    private func createPaymentMethodFromApplePay(_ payment: PKPayment) async throws -> String {
        // In production, send the payment token to your backend
        // Your backend creates the Stripe payment method and returns the ID

        guard let url = URL(string: "\(StripeConfiguration.baseURL)/stripe/create-payment-method") else {
            throw StripeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(await getAuthToken(), forHTTPHeaderField: "Authorization")

        let tokenData = payment.token.paymentData.base64EncodedString()
        let body: [String: Any] = [
            "type": "apple_pay",
            "token": tokenData
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StripeError.paymentMethodCreationFailed
        }

        struct PaymentMethodResponse: Codable {
            let paymentMethodId: String
            enum CodingKeys: String, CodingKey {
                case paymentMethodId = "payment_method_id"
            }
        }

        let result = try JSONDecoder().decode(PaymentMethodResponse.self, from: data)
        return result.paymentMethodId
    }

    // MARK: - Helpers

    private func getAuthToken() async -> String {
        // In production, get the user's auth token
        if let token = try? keychainService.loadString(forKey: KeychainService.Keys.userAuthToken) {
            return "Bearer \(token)"
        }
        return ""
    }

    /// Converts Stripe subscription to app subscription status
    func toSubscriptionStatus() -> SubscriptionStatus {
        guard let subscription = subscription, subscription.isActive else {
            return .free
        }

        let tier: SubscriptionTier
        switch subscription.priceId {
        case StripeConfiguration.PriceID.proMonthly, StripeConfiguration.PriceID.proAnnual:
            tier = .professional
        case StripeConfiguration.PriceID.enterpriseMonthly, StripeConfiguration.PriceID.enterpriseAnnual:
            tier = .enterprise
        default:
            tier = .free
        }

        return SubscriptionStatus(
            tier: tier,
            isActive: subscription.isActive,
            expirationDate: subscription.currentPeriodEnd,
            willRenew: !subscription.cancelAtPeriodEnd,
            isTrialPeriod: subscription.isInTrial,
            trialDaysRemaining: subscription.trialDaysRemaining
        )
    }
}

// MARK: - Stripe Errors

enum StripeError: LocalizedError {
    case invalidURL
    case networkError
    case customerCreationFailed
    case customerNotFound
    case noCustomer
    case subscriptionCreationFailed
    case subscriptionNotFound
    case noSubscription
    case cancellationFailed
    case paymentMethodCreationFailed
    case invalidPaymentToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network error occurred"
        case .customerCreationFailed:
            return "Failed to create customer"
        case .customerNotFound:
            return "Customer not found"
        case .noCustomer:
            return "No customer account found"
        case .subscriptionCreationFailed:
            return "Failed to create subscription"
        case .subscriptionNotFound:
            return "Subscription not found"
        case .noSubscription:
            return "No active subscription"
        case .cancellationFailed:
            return "Failed to cancel subscription"
        case .paymentMethodCreationFailed:
            return "Failed to process payment method"
        case .invalidPaymentToken:
            return "Invalid payment token"
        }
    }
}

// MARK: - Environment Key

struct StripePaymentServiceKey: EnvironmentKey {
    @MainActor static let defaultValue = StripePaymentService()
}

extension EnvironmentValues {
    var stripePaymentService: StripePaymentService {
        get { self[StripePaymentServiceKey.self] }
        set { self[StripePaymentServiceKey.self] = newValue }
    }
}
