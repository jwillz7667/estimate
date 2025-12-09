//
//  SupabaseService.swift
//  ProjectEstimate
//
//  Supabase database service for cloud sync, authentication, and real-time updates
//  Provides enterprise-grade backend integration with RLS security
//

import Foundation
import OSLog

// MARK: - Supabase Configuration

enum SupabaseConfiguration {
    // Load from Secrets.swift - configure your keys there
    static var projectURL: String { Secrets.supabaseURL }
    static var anonKey: String { Secrets.supabaseAnonKey }

    // API Endpoints
    static var authURL: String { "\(projectURL)/auth/v1" }
    static var restURL: String { "\(projectURL)/rest/v1" }
    static var storageURL: String { "\(projectURL)/storage/v1" }
    static var realtimeURL: String { "\(projectURL)/realtime/v1" }

    // Buckets
    static let generatedImagesBucket = "generated-images"
    static let userAvatarsBucket = "user-avatars"
    static let projectAttachmentsBucket = "project-attachments"

    // OAuth
    static var redirectURL: String { "\(Secrets.oauthCallbackScheme)://auth-callback" }
}

// MARK: - Database Error Types

enum DatabaseError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case serverError(Int, String?)
    case notFound
    case unauthorized
    case conflict
    case rateLimited
    case storageError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        case .conflict:
            return "Resource conflict"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .storageError(let message):
            return "Storage error: \(message)"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Auth Models

struct AuthSession: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
    let phone: String?
    let emailConfirmedAt: String?
    let phoneConfirmedAt: String?
    let createdAt: String
    let updatedAt: String?
    let appMetadata: [String: AnyCodable]?
    let userMetadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case emailConfirmedAt = "email_confirmed_at"
        case phoneConfirmedAt = "phone_confirmed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case appMetadata = "app_metadata"
        case userMetadata = "user_metadata"
    }
}

// MARK: - Profile Model

struct ProfileDTO: Codable {
    let id: String
    let email: String
    let displayName: String?
    let companyName: String?
    let phoneNumber: String?
    let avatarUrl: String?
    let licenseNumber: String?
    let serviceRegions: [String]?
    let specializations: [String]?
    let defaultQualityTier: String?
    let prefersDarkMode: Bool?
    let measurementSystem: String?
    let subscriptionTier: String
    let subscriptionExpiresAt: String?
    let estimatesGeneratedThisMonth: Int
    let imagesGeneratedThisMonth: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case companyName = "company_name"
        case phoneNumber = "phone_number"
        case avatarUrl = "avatar_url"
        case licenseNumber = "license_number"
        case serviceRegions = "service_regions"
        case specializations
        case defaultQualityTier = "default_quality_tier"
        case prefersDarkMode = "prefers_dark_mode"
        case measurementSystem = "measurement_system"
        case subscriptionTier = "subscription_tier"
        case subscriptionExpiresAt = "subscription_expires_at"
        case estimatesGeneratedThisMonth = "estimates_generated_this_month"
        case imagesGeneratedThisMonth = "images_generated_this_month"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Project Model

struct ProjectDTO: Codable {
    let id: String
    let userId: String
    let projectName: String
    let roomType: String
    let squareFootage: Double
    let location: String?
    let zipCode: String?
    let budgetMin: Double?
    let budgetMax: Double?
    let selectedMaterials: [String]?
    let qualityTier: String
    let notes: String?
    let urgency: String
    let includesPermits: Bool
    let includesDesign: Bool
    let status: String
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case projectName = "project_name"
        case roomType = "room_type"
        case squareFootage = "square_footage"
        case location
        case zipCode = "zip_code"
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case selectedMaterials = "selected_materials"
        case qualityTier = "quality_tier"
        case notes
        case urgency
        case includesPermits = "includes_permits"
        case includesDesign = "includes_design"
        case status
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Supabase Service Protocol

protocol SupabaseServiceProtocol {
    // Auth
    func signUp(email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthSession
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func signOut() async throws
    func refreshSession() async throws -> AuthSession
    func getCurrentUser() -> AuthUser?

    // Profile
    func getProfile() async throws -> ProfileDTO
    func updateProfile(_ profile: ProfileDTO) async throws -> ProfileDTO

    // Projects
    func getProjects() async throws -> [ProjectDTO]
    func getProject(id: String) async throws -> ProjectDTO
    func createProject(_ project: ProjectDTO) async throws -> ProjectDTO
    func updateProject(_ project: ProjectDTO) async throws -> ProjectDTO
    func deleteProject(id: String) async throws

    // Storage
    func uploadImage(_ data: Data, path: String, bucket: String) async throws -> String
    func getImageURL(path: String, bucket: String) -> String
    func deleteImage(path: String, bucket: String) async throws
}

// MARK: - Supabase Service Implementation

final class SupabaseService: SupabaseServiceProtocol {

    // MARK: - Properties

    private let session: URLSession
    private let logger: Logger
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var currentSession: AuthSession?
    private var currentUser: AuthUser?

    // MARK: - Singleton

    static let shared = SupabaseService()

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.logger = Logger(subsystem: "com.projectestimate", category: "Supabase")

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Load cached session
        loadCachedSession()
    }

    // MARK: - Auth Methods

    func signUp(email: String, password: String) async throws -> AuthSession {
        let url = URL(string: "\(SupabaseConfiguration.authURL)/signup")!

        let body = ["email": email, "password": password]
        let response: AuthSession = try await makeAuthRequest(url: url, body: body)

        saveSession(response)
        return response
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let url = URL(string: "\(SupabaseConfiguration.authURL)/token?grant_type=password")!

        let body = ["email": email, "password": password]
        let response: AuthSession = try await makeAuthRequest(url: url, body: body)

        saveSession(response)
        return response
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let url = URL(string: "\(SupabaseConfiguration.authURL)/token?grant_type=id_token")!

        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]

        let response: AuthSession = try await makeAuthRequest(url: url, body: body)

        saveSession(response)
        return response
    }

    func signOut() async throws {
        guard let session = currentSession else { return }

        let url = URL(string: "\(SupabaseConfiguration.authURL)/logout")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")

        _ = try await self.session.data(for: request)

        clearSession()
    }

    func refreshSession() async throws -> AuthSession {
        guard let session = currentSession else {
            throw DatabaseError.notAuthenticated
        }

        let url = URL(string: "\(SupabaseConfiguration.authURL)/token?grant_type=refresh_token")!

        let body = ["refresh_token": session.refreshToken]
        let response: AuthSession = try await makeAuthRequest(url: url, body: body)

        saveSession(response)
        return response
    }

    func getCurrentUser() -> AuthUser? {
        return currentUser
    }

    // MARK: - Profile Methods

    func getProfile() async throws -> ProfileDTO {
        guard let user = currentUser else {
            throw DatabaseError.notAuthenticated
        }

        let url = URL(string: "\(SupabaseConfiguration.restURL)/profiles?id=eq.\(user.id)&select=*")!
        let profiles: [ProfileDTO] = try await makeRequest(url: url, method: "GET")

        guard let profile = profiles.first else {
            throw DatabaseError.notFound
        }

        return profile
    }

    func updateProfile(_ profile: ProfileDTO) async throws -> ProfileDTO {
        guard let user = currentUser else {
            throw DatabaseError.notAuthenticated
        }

        let url = URL(string: "\(SupabaseConfiguration.restURL)/profiles?id=eq.\(user.id)")!

        var request = try makeAuthenticatedRequest(url: url, method: "PATCH")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(profile)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        guard let updatedProfile = profiles.first else {
            throw DatabaseError.unknown("Update failed")
        }

        return updatedProfile
    }

    // MARK: - Projects Methods

    func getProjects() async throws -> [ProjectDTO] {
        let url = URL(string: "\(SupabaseConfiguration.restURL)/renovation_projects?select=*&order=updated_at.desc")!
        return try await makeRequest(url: url, method: "GET")
    }

    func getProject(id: String) async throws -> ProjectDTO {
        let url = URL(string: "\(SupabaseConfiguration.restURL)/renovation_projects?id=eq.\(id)&select=*")!
        let projects: [ProjectDTO] = try await makeRequest(url: url, method: "GET")

        guard let project = projects.first else {
            throw DatabaseError.notFound
        }

        return project
    }

    func createProject(_ project: ProjectDTO) async throws -> ProjectDTO {
        let url = URL(string: "\(SupabaseConfiguration.restURL)/renovation_projects")!

        var request = try makeAuthenticatedRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(project)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        let projects = try decoder.decode([ProjectDTO].self, from: data)
        guard let createdProject = projects.first else {
            throw DatabaseError.unknown("Create failed")
        }

        return createdProject
    }

    func updateProject(_ project: ProjectDTO) async throws -> ProjectDTO {
        let url = URL(string: "\(SupabaseConfiguration.restURL)/renovation_projects?id=eq.\(project.id)")!

        var request = try makeAuthenticatedRequest(url: url, method: "PATCH")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(project)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        let projects = try decoder.decode([ProjectDTO].self, from: data)
        guard let updatedProject = projects.first else {
            throw DatabaseError.unknown("Update failed")
        }

        return updatedProject
    }

    func deleteProject(id: String) async throws {
        let url = URL(string: "\(SupabaseConfiguration.restURL)/renovation_projects?id=eq.\(id)")!

        let request = try makeAuthenticatedRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)
    }

    // MARK: - Storage Methods

    func uploadImage(_ data: Data, path: String, bucket: String) async throws -> String {
        guard currentSession != nil else {
            throw DatabaseError.notAuthenticated
        }

        let url = URL(string: "\(SupabaseConfiguration.storageURL)/object/\(bucket)/\(path)")!

        var request = try makeAuthenticatedRequest(url: url, method: "POST")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: responseData, encoding: .utf8)
            throw DatabaseError.storageError(message ?? "Upload failed")
        }

        return getImageURL(path: path, bucket: bucket)
    }

    func getImageURL(path: String, bucket: String) -> String {
        return "\(SupabaseConfiguration.storageURL)/object/public/\(bucket)/\(path)"
    }

    func deleteImage(path: String, bucket: String) async throws {
        let url = URL(string: "\(SupabaseConfiguration.storageURL)/object/\(bucket)/\(path)")!

        let request = try makeAuthenticatedRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)
    }

    // MARK: - Private Methods

    private func makeAuthRequest<T: Decodable>(url: URL, body: Any) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")

        if let bodyDict = body as? [String: Any] {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
        } else if let encodable = body as? Encodable {
            request.httpBody = try encoder.encode(AnyEncodable(encodable))
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        return try decoder.decode(T.self, from: data)
    }

    private func makeRequest<T: Decodable>(url: URL, method: String) async throws -> T {
        let request = try makeAuthenticatedRequest(url: url, method: method)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.unknown("Invalid response")
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        return try decoder.decode(T.self, from: data)
    }

    private func makeAuthenticatedRequest(url: URL, method: String) throws -> URLRequest {
        guard let session = currentSession else {
            throw DatabaseError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")

        return request
    }

    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return
        case 401:
            throw DatabaseError.unauthorized
        case 404:
            throw DatabaseError.notFound
        case 409:
            throw DatabaseError.conflict
        case 429:
            throw DatabaseError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8)
            throw DatabaseError.serverError(statusCode, message)
        }
    }

    private func saveSession(_ session: AuthSession) {
        currentSession = session
        currentUser = session.user

        // Save to Keychain
        if let data = try? encoder.encode(session) {
            try? KeychainService.shared.save(data, forKey: "supabase_session")
        }

        logger.info("Session saved for user: \(session.user.id)")
    }

    private func loadCachedSession() {
        do {
            if let data = try KeychainService.shared.load(forKey: "supabase_session") {
                let session = try decoder.decode(AuthSession.self, from: data)
                currentSession = session
                currentUser = session.user
                logger.info("Cached session loaded")
            }
        } catch {
            logger.debug("No cached session found")
        }
    }

    private func clearSession() {
        currentSession = nil
        currentUser = nil

        try? KeychainService.shared.delete(forKey: "supabase_session")

        logger.info("Session cleared")
    }
}

// MARK: - AnyEncodable Helper

private struct AnyEncodable: Encodable {
    private let encodable: Encodable

    init(_ encodable: Encodable) {
        self.encodable = encodable
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
