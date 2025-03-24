import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("NoteAI Premium")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Unlock all features and support development")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Features
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "infinity", title: "Unlimited contacts", description: "Store as many contacts as you need")
                    FeatureRow(icon: "sparkles", title: "AI-powered organization", description: "Smart label suggestions and organization")
                    FeatureRow(icon: "magnifyingglass", title: "Advanced search", description: "Find contacts using natural language")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Subscription status
                Group {
                    if subscriptionService.subscriptionStatus == .active {
                        Text("You're subscribed to NoteAI Premium")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else {
                        // Subscribe button
                        VStack(spacing: 16) {
                            if !subscriptionService.products.isEmpty {
                                Button(action: {
                                    purchaseSubscription()
                                }) {
                                    Text("Subscribe - $5/month")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isLoading)
                            } else {
                                Text("Products not available")
                                    .foregroundColor(.secondary)
                            }
                            
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Subscription")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .overlay(
                isLoading ? 
                    ZStack {
                        Color.black.opacity(0.4)
                        ProgressView()
                    }
                    .edgesIgnoringSafeArea(.all)
                    : nil
            )
            .onAppear {
                // For development, simulate active subscription
                Task {
                    await subscriptionService.checkSubscriptionStatus()
                }
            }
        }
    }
    
    private func purchaseSubscription() {
        guard let product = subscriptionService.products.first else {
            errorMessage = "Subscription product not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await subscriptionService.purchase(product)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Purchase failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
            .environmentObject(SubscriptionService.shared)
    }
}
