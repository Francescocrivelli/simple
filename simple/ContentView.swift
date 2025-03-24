import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if let preferences = authService.userPreferences, preferences.hasCompletedOnboarding == true {
                    MainView()
                } else {
                    OnboardingView()
                }
            } else {
                AuthView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}
