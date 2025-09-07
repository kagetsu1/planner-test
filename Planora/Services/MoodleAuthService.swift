import Foundation
import Security

/// Service for handling Moodle authentication including discovery, direct login, and SSO
class MoodleAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychainService = "com.aeroflow.Planora.moodle"
    private let baseURLKey = "MoodleBaseURL"
    private let tokenKey = "MoodleToken"
    
    var baseURL: String? {
        get { UserDefaults.standard.string(forKey: baseURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }
    
    var token: String? {
        get { getFromKeychain(key: tokenKey) }
        set { 
            if let newValue = newValue {
                saveToKeychain(key: tokenKey, value: newValue)
            } else {
                deleteFromKeychain(key: tokenKey)
            }
        }
    }
    
    init() {
        checkAuthenticationStatus()
    }
    
    /// Check if user is currently authenticated
    func checkAuthenticationStatus() {
        isAuthenticated = baseURL != nil && token != nil
    }
    
    /// Discover Moodle site configuration
    func discoverSiteConfig(url: String) async throws -> SiteConfig {
        guard let baseURL = URL(string: url) else {
            throw MoodleAuthError.invalidURL
        }
        
        let configURL = baseURL.appendingPathComponent("webservice/rest/server.php")
        var components = URLComponents(url: configURL, resolvingAgainstBaseURL: false)!
        
        components.queryItems = [
            URLQueryItem(name: "wstoken", value: ""),
            URLQueryItem(name: "wsfunction", value: "tool_mobile_get_public_config"),
            URLQueryItem(name: "moodlewsrestformat", value: "json")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let config = try JSONDecoder().decode(SiteConfig.self, from: data)
        return config
    }
    
    /// Authenticate using direct login
    func authenticateWithCredentials(baseURL: String, username: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Normalize base URL
        let normalizedURL = normalizeURL(baseURL)
        
        // Get token via direct login
        guard let tokenURL = URL(string: "\(normalizedURL)/login/token.php") else {
            throw MoodleAuthError.invalidURL
        }
        
        var components = URLComponents(url: tokenURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "service", value: "moodle_mobile_app")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        if let error = tokenResponse.error {
            throw MoodleAuthError.authenticationFailed(error)
        }
        
        guard let token = tokenResponse.token else {
            throw MoodleAuthError.authenticationFailed("No token received")
        }
        
        // Validate token by getting site info
        try await validateToken(baseURL: normalizedURL, token: token)
        
        // Save credentials
        self.baseURL = normalizedURL
        self.token = token
        self.isAuthenticated = true
    }
    
    /// Get SSO login URL for external authentication
    func getSSOLoginURL(baseURL: String) -> URL? {
        let normalizedURL = normalizeURL(baseURL)
        guard let baseURL = URL(string: normalizedURL) else { return nil }
        
        let launchURL = baseURL.appendingPathComponent("admin/tool/mobile/launch.php")
        var components = URLComponents(url: launchURL, resolvingAgainstBaseURL: false)!
        
        components.queryItems = [
            URLQueryItem(name: "service", value: "moodle_mobile_app"),
            URLQueryItem(name: "passport", value: UUID().uuidString),
            URLQueryItem(name: "urlscheme", value: "planora")
        ]
        
        return components.url
    }
    
    /// Handle callback URL from SSO authentication
    func handleCallbackURL(_ url: URL) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw MoodleAuthError.invalidCallbackURL
        }
        
        var token: String?
        var baseURL: String?
        
        for item in queryItems {
            switch item.name {
            case "token":
                token = item.value
            case "siteurl":
                baseURL = item.value
            default:
                break
            }
        }
        
        guard let receivedToken = token,
              let receivedBaseURL = baseURL else {
            throw MoodleAuthError.invalidCallbackURL
        }
        
        // Validate token
        try await validateToken(baseURL: receivedBaseURL, token: receivedToken)
        
        // Save credentials
        self.baseURL = receivedBaseURL
        self.token = receivedToken
        self.isAuthenticated = true
    }
    
    /// Validate token by calling core_webservice_get_site_info
    private func validateToken(baseURL: String, token: String) async throws {
        guard let apiURL = URL(string: "\(baseURL)/webservice/rest/server.php") else {
            throw MoodleAuthError.invalidURL
        }
        
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "wstoken", value: token),
            URLQueryItem(name: "wsfunction", value: "core_webservice_get_site_info"),
            URLQueryItem(name: "moodlewsrestformat", value: "json")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let siteInfo = try JSONDecoder().decode(SiteInfo.self, from: data)
        
        if let error = siteInfo.exception {
            throw MoodleAuthError.authenticationFailed(error)
        }
    }
    
    /// Sign out and clear stored credentials
    func signOut() {
        baseURL = nil
        token = nil
        isAuthenticated = false
        errorMessage = nil
    }
    
    /// Normalize URL to ensure proper format
    private func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
    
    // MARK: - Keychain helpers
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Models

struct SiteConfig: Codable {
    let sitename: String?
    let username: String?
    let firstname: String?
    let lastname: String?
    let fullname: String?
    let lang: String?
    let userid: Int?
    let siteurl: String?
    let userpictureurl: String?
    let functions: [Function]?
    let downloadfiles: Int?
    let uploadfiles: Int?
    let release: String?
    let version: String?
    let mobilecssurl: String?
    let autologinkey: String?
    let autologinurl: String?
    let warnings: [Warning]?
    
    struct Function: Codable {
        let name: String
        let version: String
    }
    
    struct Warning: Codable {
        let item: String?
        let itemid: Int?
        let warningcode: String
        let message: String
    }
}

struct TokenResponse: Codable {
    let token: String?
    let privatetoken: String?
    let error: String?
}

struct SiteInfo: Codable {
    let sitename: String?
    let username: String?
    let firstname: String?
    let lastname: String?
    let fullname: String?
    let lang: String?
    let userid: Int?
    let siteurl: String?
    let userpictureurl: String?
    let functions: [SiteConfig.Function]?
    let downloadfiles: Int?
    let uploadfiles: Int?
    let release: String?
    let version: String?
    let mobilecssurl: String?
    let exception: String?
    let errorcode: String?
    let message: String?
}

enum MoodleAuthError: LocalizedError {
    case invalidURL
    case invalidCallbackURL
    case authenticationFailed(String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidCallbackURL:
            return "Invalid callback URL"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        }
    }
}
