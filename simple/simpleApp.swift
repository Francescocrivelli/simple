import SwiftUI

@main
struct SimpleApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(subscriptionService)
                .onAppear {
                    // Check subscription status and user session
                    Task {
                        await subscriptionService.checkSubscriptionStatus()
                    }
                }
        }
    }
}
