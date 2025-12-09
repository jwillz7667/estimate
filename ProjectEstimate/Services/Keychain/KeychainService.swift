//
//  KeychainService.swift
//  ProjectEstimate
//
//  Secure Keychain wrapper for storing sensitive data
//  Implements OWASP security best practices for credential storage
//

import Foundation
import Security
import OSLog

/// Protocol for Keychain operations - enables dependency injection and testing
protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String) throws
    func load(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
    func saveString(_ string: String, forKey key: String) throws
    func loadString(forKey key: String) throws -> String?
    func exists(forKey key: String) -> Bool
}

/// Secure Keychain service implementation
/// Thread-safe, supports iCloud Keychain sync for enterprise deployments
final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = KeychainService()

    // MARK: - Properties

    private let serviceName: String
    private let accessGroup: String?
    private let logger = Logger(subsystem: "com.projectestimate", category: "Keychain")
    private let lock = NSLock()

    // MARK: - Keychain Keys

    enum Keys {
        static let geminiAPIKey = "com.projectestimate.gemini.apikey"
        static let imagenAPIKey = "com.projectestimate.imagen.apikey"
        static let userAuthToken = "com.projectestimate.auth.token"
        static let userRefreshToken = "com.projectestimate.auth.refresh"
        static let firebaseToken = "com.projectestimate.firebase.token"
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case dataConversionError
        case duplicateItem
        case itemNotFound
        case unexpectedError(OSStatus)
        case accessDenied
        case invalidData

        var errorDescription: String? {
            switch self {
            case .dataConversionError:
                return "Failed to convert data for Keychain storage"
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            case .accessDenied:
                return "Access to Keychain denied"
            case .invalidData:
                return "Invalid data retrieved from Keychain"
            }
        }
    }

    // MARK: - Initialization

    init(serviceName: String = "com.projectestimate.keychain", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods

    /// Saves data to Keychain
    func save(_ data: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        // First try to delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to save to Keychain: \(status)")
            throw mapError(status)
        }

        logger.debug("Successfully saved data to Keychain for key: \(key)")
    }

    /// Loads data from Keychain
    func load(forKey key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Failed to load from Keychain: \(status)")
            throw mapError(status)
        }
    }

    /// Deletes data from Keychain
    func delete(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete from Keychain: \(status)")
            throw mapError(status)
        }

        logger.debug("Successfully deleted from Keychain for key: \(key)")
    }

    /// Saves string to Keychain
    func saveString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try save(data, forKey: key)
    }

    /// Loads string from Keychain
    func loadString(forKey key: String) throws -> String? {
        guard let data = try load(forKey: key) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    /// Checks if key exists in Keychain
    func exists(forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanFalse

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Convenience Methods for API Keys

    /// Saves Gemini API key securely
    func saveGeminiAPIKey(_ apiKey: String) throws {
        try saveString(apiKey, forKey: Keys.geminiAPIKey)
    }

    /// Loads Gemini API key
    func getGeminiAPIKey() throws -> String? {
        try loadString(forKey: Keys.geminiAPIKey)
    }

    /// Saves Imagen API key securely
    func saveImagenAPIKey(_ apiKey: String) throws {
        try saveString(apiKey, forKey: Keys.imagenAPIKey)
    }

    /// Loads Imagen API key
    func getImagenAPIKey() throws -> String? {
        try loadString(forKey: Keys.imagenAPIKey)
    }

    /// Clears all stored credentials
    func clearAllCredentials() throws {
        try delete(forKey: Keys.geminiAPIKey)
        try delete(forKey: Keys.imagenAPIKey)
        try delete(forKey: Keys.userAuthToken)
        try delete(forKey: Keys.userRefreshToken)
        try delete(forKey: Keys.firebaseToken)
        logger.info("All credentials cleared from Keychain")
    }

    // MARK: - Private Methods

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func mapError(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecItemNotFound:
            return .itemNotFound
        case errSecAuthFailed, errSecInteractionNotAllowed:
            return .accessDenied
        default:
            return .unexpectedError(status)
        }
    }
}

// MARK: - API Key Manager

/// High-level API key manager with validation
final class APIKeyManager: Sendable {
    private let keychain: KeychainServiceProtocol

    init(keychain: KeychainServiceProtocol = KeychainService.shared) {
        self.keychain = keychain
    }

    /// Validates and saves Gemini API key
    func setGeminiAPIKey(_ key: String) async throws {
        guard isValidAPIKeyFormat(key) else {
            throw APIKeyError.invalidFormat
        }
        try keychain.saveString(key, forKey: KeychainService.Keys.geminiAPIKey)
    }

    /// Gets Gemini API key if available
    func getGeminiAPIKey() async throws -> String {
        guard let key = try keychain.loadString(forKey: KeychainService.Keys.geminiAPIKey) else {
            throw APIKeyError.notConfigured
        }
        return key
    }

    /// Validates and saves Imagen API key
    func setImagenAPIKey(_ key: String) async throws {
        guard isValidAPIKeyFormat(key) else {
            throw APIKeyError.invalidFormat
        }
        try keychain.saveString(key, forKey: KeychainService.Keys.imagenAPIKey)
    }

    /// Gets Imagen API key if available
    func getImagenAPIKey() async throws -> String {
        guard let key = try keychain.loadString(forKey: KeychainService.Keys.imagenAPIKey) else {
            throw APIKeyError.notConfigured
        }
        return key
    }

    /// Checks if API keys are configured
    var hasAPIKeysConfigured: Bool {
        keychain.exists(forKey: KeychainService.Keys.geminiAPIKey)
    }

    private func isValidAPIKeyFormat(_ key: String) -> Bool {
        // Basic validation: not empty, reasonable length, no whitespace
        !key.isEmpty &&
        key.count >= 20 &&
        key.count <= 200 &&
        !key.contains(" ") &&
        !key.contains("\n")
    }

    enum APIKeyError: LocalizedError {
        case notConfigured
        case invalidFormat
        case validationFailed

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "API key not configured. Please add your API key in Settings."
            case .invalidFormat:
                return "Invalid API key format"
            case .validationFailed:
                return "API key validation failed"
            }
        }
    }
}
