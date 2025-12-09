//
//  NetworkService.swift
//  ProjectEstimate
//
//  Enterprise-grade networking layer with retry logic, caching, and comprehensive error handling
//  Implements URLSession best practices with async/await
//

import Foundation
import OSLog

// MARK: - Network Error Types

/// Comprehensive network error enumeration
enum NetworkError: LocalizedError, Sendable {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String?)
    case networkUnavailable
    case timeout
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case serverError(String)
    case apiKeyMissing
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP Error \(statusCode): \(message ?? "Unknown error")"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Authentication required"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(seconds) seconds"
            }
            return "Rate limited. Please try again later"
        case .serverError(let message):
            return "Server error: \(message)"
        case .apiKeyMissing:
            return "API key not configured"
        case .cancelled:
            return "Request was cancelled"
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .networkUnavailable, .rateLimited, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Request Configuration

/// HTTP request methods
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Network request configuration
struct NetworkRequest: Sendable {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    let retryCount: Int
    let cachePolicy: URLRequest.CachePolicy

    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30,
        retryCount: Int = 3,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.retryCount = retryCount
        self.cachePolicy = cachePolicy
    }
}

// MARK: - Network Response

/// Generic network response wrapper
struct NetworkResponse<T: Decodable & Sendable>: Sendable {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let duration: TimeInterval
}

// MARK: - Protocol Definition

/// Protocol for network operations - enables dependency injection
protocol NetworkServiceProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ request: NetworkRequest, responseType: T.Type) async throws -> NetworkResponse<T>
    func requestData(_ request: NetworkRequest) async throws -> (Data, Int)
}

// MARK: - Network Service Implementation

/// Production-ready network service with exponential backoff, logging, and comprehensive error handling
final class NetworkService: NetworkServiceProtocol, Sendable {

    // MARK: - Properties

    private let session: URLSession
    private let logger: Logger
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Initialization

    init(configuration: URLSessionConfiguration = .default) {
        let config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]

        self.session = URLSession(configuration: config)
        self.logger = Logger(subsystem: "com.projectestimate", category: "Network")

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Performs network request with retry logic and returns decoded response
    func request<T: Decodable & Sendable>(
        _ request: NetworkRequest,
        responseType: T.Type
    ) async throws -> NetworkResponse<T> {
        let startTime = Date()

        var lastError: Error?
        var currentRetry = 0

        while currentRetry <= request.retryCount {
            do {
                let urlRequest = try buildURLRequest(from: request)
                logger.debug("Sending \(request.method.rawValue) request to \(request.url.absoluteString)")

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.unknown(URLError(.badServerResponse))
                }

                // Log response details
                logger.debug("Received response: \(httpResponse.statusCode) (\(data.count) bytes)")

                // Handle HTTP status codes
                try handleStatusCode(httpResponse.statusCode, data: data)

                // Decode response
                let decodedData = try decoder.decode(T.self, from: data)

                let duration = Date().timeIntervalSince(startTime)
                let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]

                return NetworkResponse(
                    data: decodedData,
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    duration: duration
                )

            } catch let error as NetworkError where error.isRetryable {
                lastError = error
                currentRetry += 1

                if currentRetry <= request.retryCount {
                    let delay = calculateBackoffDelay(attempt: currentRetry)
                    logger.warning("Request failed, retrying in \(delay)s (attempt \(currentRetry)/\(request.retryCount))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                throw mapError(error)
            }
        }

        throw lastError ?? NetworkError.unknown(URLError(.unknown))
    }

    /// Performs network request and returns raw data
    func requestData(_ request: NetworkRequest) async throws -> (Data, Int) {
        let urlRequest = try buildURLRequest(from: request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        try handleStatusCode(httpResponse.statusCode, data: data)

        return (data, httpResponse.statusCode)
    }

    // MARK: - Private Methods

    private func buildURLRequest(from request: NetworkRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        urlRequest.cachePolicy = request.cachePolicy

        // Add headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Add body
        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }

    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return // Success
        case 401:
            throw NetworkError.unauthorized
        case 429:
            // Try to parse retry-after header
            throw NetworkError.rateLimited(retryAfter: nil)
        case 400...499:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(statusCode: statusCode, message: message)
        case 500...599:
            let message = String(data: data, encoding: .utf8) ?? "Internal server error"
            throw NetworkError.serverError(message)
        default:
            throw NetworkError.httpError(statusCode: statusCode, message: nil)
        }
    }

    private func calculateBackoffDelay(attempt: Int) -> Double {
        // Exponential backoff with jitter
        let baseDelay = pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        return min(baseDelay + jitter, 30) // Max 30 seconds
    }

    private func mapError(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }

        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorCancelled:
            return .cancelled
        default:
            if error is DecodingError {
                return .decodingError(error)
            }
            return .unknown(error)
        }
    }
}

// MARK: - Request Builders

extension NetworkRequest {
    /// Creates a POST request with JSON body
    static func post<T: Encodable & Sendable>(
        url: URL,
        body: T,
        headers: [String: String] = [:]
    ) throws -> NetworkRequest {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(body)

        return NetworkRequest(
            url: url,
            method: .post,
            headers: headers,
            body: data
        )
    }

    /// Creates a GET request
    static func get(
        url: URL,
        headers: [String: String] = [:]
    ) -> NetworkRequest {
        NetworkRequest(
            url: url,
            method: .get,
            headers: headers
        )
    }
}
