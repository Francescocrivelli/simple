import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var contactService = ContactService.shared
    
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let steps = [
        OnboardingStep(
            title: "Welcome to NoteAI",
            description: "The AI-powered contact manager for networking events",
            imageName: "person.crop.circle.badge.plus"
        ),
        OnboardingStep(
            title: "Import Your Contacts",
            description: "Sync your existing contacts to get started quickly",
            imageName: "arrow.triangle.2.circlepath.circle.fill"
        ),
        OnboardingStep(
            title: "Natural Language",
            description: "Add contacts using natural language - just describe the person you met",
            imageName: "text.bubble.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            VStack {
                // Progress indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Rectangle()
                            .fill(currentStep >= index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                
                // Content
                VStack(spacing: 20) {
                    Image(systemName: steps[currentStep].imageName)
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                        .padding(.bottom, 20)
                    
                    Text(steps[currentStep].title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if currentStep == 1 {
                        // Contact sync step
                        Button(action: syncContacts) {
                            Text("Sync Contacts")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: skipSync) {
                            Text("Skip")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    } else {
                        // Standard navigation
                        Button(action: nextStep) {
                            Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        if currentStep > 0 && currentStep < steps.count - 1 {
                            Button(action: { currentStep -= 1 }) {
                                Text("Back")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            
            if isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Syncing contacts...")
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
            }
        }
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            // Complete onboarding
            completeOnboarding()
        }
    }
    
    private func syncContacts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await contactService.syncWithSystemContacts()
                try await authService.updateUserPreferences(hasSyncedContacts: true)
                
                await MainActor.run {
                    isLoading = false
                    nextStep()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to sync contacts: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func skipSync() {
        Task {
            do {
                try await authService.updateUserPreferences(hasSyncedContacts: false)
                nextStep()
            } catch {
                errorMessage = "Error updating preferences: \(error.localizedDescription)"
            }
        }
    }
    
    private func completeOnboarding() {
        isLoading = true
        
        Task {
            do {
                try await authService.updateUserPreferences(hasCompletedOnboarding: true)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error completing onboarding: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthService.shared)
    }
}
