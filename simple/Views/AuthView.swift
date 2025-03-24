import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                
                Text("NoteAI")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Smart contact management for networking")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .frame(height: 50)
                    .cornerRadius(8)
                    
                    // Sign in with Google
                    Button(action: {
                        handleGoogleSignIn()
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .padding()
            
            if isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        try await authService.signInWithApple(credential: appleIDCredential)
                        isLoading = false
                    } catch {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Failed to sign in with Apple: \(error.localizedDescription)"
                        }
                    }
                }
            }
        case .failure(let error):
            isLoading = false
            errorMessage = "Apple sign in failed: \(error.localizedDescription)"
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        errorMessage = nil
        
        // This is a placeholder for Google Sign-In implementation
        // You would need to configure GIDSignIn properly
        
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            errorMessage = "Failed to set up Google Sign-In"
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Google sign in failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to get user information from Google"
                }
                return
            }
            
            Task {
                do {
                    try await authService.signInWithGoogle(token: idToken)
                    await MainActor.run {
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Failed to sign in with Google: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthService.shared)
    }
}
