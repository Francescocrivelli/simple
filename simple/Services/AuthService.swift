import Foundation
import Supabase
import AuthenticationServices
import GoogleSignIn

enum AuthError: Error {
    case signInFailed
    case userNotFound
    case sessionExpired
    case unknown
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userPreferences: UserPreferences?
    
    private let supabase = SupabaseService.shared.client
    
    // Check current session on init
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            do {
                // Get session and check if it's valid
                let session = try await supabase.auth.session
                let hasValidSession = session.accessToken.isEmpty == false
                
                if hasValidSession {
                    await fetchUserData()
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } else {
                    await MainActor.run {
                        self.isAuthenticated = false
                    }
                }
            } catch {
                print("Session check error: \(error)")
                await MainActor.run {
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    func fetchUserData() async {
        do {
            // Get the current user from the session
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // No conversion to UUID, use userId string directly
            // Fetch user data
            let userData = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            
            // Fetch user preferences
            let userPrefs = try await supabase
                .from("user_preferences")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            await MainActor.run {
                let decoder = JSONDecoder()
                do {
                    // data is not optional, so we don't need if let
                    let userDataJson = userData.data
                    if let user = try? decoder.decode(User.self, from: userDataJson) {
                        self.currentUser = user
                    }
                    
                    let userPrefsJson = userPrefs.data
                    if let prefs = try? decoder.decode(UserPreferences.self, from: userPrefsJson) {
                        self.userPreferences = prefs
                    }
                } catch {
                    print("Error decoding user data: \(error)")
                }
            }
        } catch {
            print("Error fetching user data: \(error)")
        }
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let token = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.signInFailed
        }
        
        do {
            let authResponse = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: token
                )
            )
            
            // Check if user exists in the response
            let userIdString = authResponse.user.id.uuidString
            if !userIdString.isEmpty {
                await fetchUserData()
                await MainActor.run {
                    self.isAuthenticated = true
                }
                
                // Create user preferences if needed
                if self.userPreferences == nil {
                    try await createUserPreferences()
                }
            } else {
                throw AuthError.signInFailed
            }
        } catch {
            print("Apple sign in error: \(error)")
            throw AuthError.signInFailed
        }
    }
    
    func signInWithGoogle(token: String) async throws {
        do {
            let authResponse = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: token
                )
            )
            
            // Check if user exists in the response
            let userIdString = authResponse.user.id.uuidString
            if !userIdString.isEmpty {
                await fetchUserData()
                await MainActor.run {
                    self.isAuthenticated = true
                }
                
                // Create user preferences if needed
                if self.userPreferences == nil {
                    try await createUserPreferences()
                }
            } else {
                throw AuthError.signInFailed
            }
        } catch {
            print("Google sign in error: \(error)")
            throw AuthError.signInFailed
        }
    }
    
    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.userPreferences = nil
            }
        } catch {
            print("Sign out error: \(error)")
            throw AuthError.unknown
        }
    }
    
    private func createUserPreferences() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Get string from UUID
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        do {
            // Use a dictionary with strong types for Encodable conformance
            let preferences: [String: String] = [
                "user_id": userIdString,
                "has_completed_onboarding": "false",
                "has_synced_contacts": "false"
            ]
            
            try await supabase
                .from("user_preferences")
                .insert(preferences)
                .execute()
            
            await fetchUserData()
        } catch {
            print("Error creating user preferences: \(error)")
            throw error
        }
    }
    
    func updateUserPreferences(hasCompletedOnboarding: Bool? = nil, hasSyncedContacts: Bool? = nil) async throws {
        guard let preferencesId = userPreferences?.id.uuidString, !preferencesId.isEmpty else {
            throw AuthError.userNotFound
        }
        
        // Use a strongly typed dictionary instead of Any
        var updates: [String: String] = [:]
        
        if let hasCompletedOnboarding = hasCompletedOnboarding {
            updates["has_completed_onboarding"] = hasCompletedOnboarding ? "true" : "false"
        }
        
        if let hasSyncedContacts = hasSyncedContacts {
            updates["has_synced_contacts"] = hasSyncedContacts ? "true" : "false"
        }
        
        if updates.isEmpty {
            return
        }
        
        do {
            try await supabase
                .from("user_preferences")
                .update(updates)
                .eq("id", value: preferencesId)
                .execute()
            
            await fetchUserData()
        } catch {
            print("Error updating user preferences: \(error)")
            throw error
        }
    }
}
