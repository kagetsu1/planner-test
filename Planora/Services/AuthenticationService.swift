//
// AuthenticationService.swift
// Sign in with Apple + Google (via SPM GoogleSignIn).
// Add 'Sign in with Apple' capability and GoogleSignIn SPM, configure URL Type (REVERSED_CLIENT_ID).

import Foundation
import AuthenticationServices
import CryptoKit
import Combine
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum AuthProvider: String, Codable { 
    case apple, google, guest 
    
    var iconName: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .google:
            return "globe"
        case .guest:
            return "person.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .guest:
            return "Guest"
        }
    }
}

struct AuthUser: Codable, Equatable {
    var id: String
    var name: String?
    var email: String?
    var provider: AuthProvider
}

final class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    @Published private(set) var currentUser: AuthUser?
    @Published var errorMessage: String?
    private var currentNonce: String?

    // MARK: - Apple
    func startSignInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }

    // MARK: - Google
    #if canImport(GoogleSignIn)
    func startSignInWithGoogle(presenting: UIViewController) {
        guard let clientID = GIDSignIn.sharedInstance.clientID, !clientID.isEmpty else {
            print("GoogleSignIn clientID missing. Configure in Info.plist (REVERSED_CLIENT_ID) or set at launch.")
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { [weak self] result, error in
            if let error { print("Google Sign-In error: \(error)"); return }
            guard let user = result?.user else { return }
            let profile = user.profile
            let authUser = AuthUser(id: user.userID ?? UUID().uuidString,
                                    name: profile?.name,
                                    email: profile?.email,
                                    provider: .google)
            DispatchQueue.main.async { self?.currentUser = authUser }
        }
    }
    #endif

    func signInAsGuest() {
        currentUser = AuthUser(id: UUID().uuidString, name: "Guest", email: nil, provider: .guest)
    }

    func signOut() {
        currentUser = nil
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    // MARK: - Helpers
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce.") }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credentials = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = credentials.user
            let fullName = credentials.fullName?.formatted()
            let email = credentials.email
            let user = AuthUser(id: userID, name: fullName, email: email, provider: .apple)
            DispatchQueue.main.async { self.currentUser = user }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
    }
}

// MARK: - Presentation anchor
extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? UIWindow()
    }
}
