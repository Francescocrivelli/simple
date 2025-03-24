import Foundation
import StoreKit

enum SubscriptionStatus {
    case active
    case inactive
    case unknown
}

class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var products: [Product] = []
    
    // Use this for development mode (no real payments)
    private let isTestMode = true
    
    // Product IDs - replace with your actual product IDs
    private let monthlySubscriptionID = "recursivestudio.ai.noteai.monthly"
    
    private var updates: Task<Void, Error>? = nil
    
    private init() {
        updates = observeTransactionUpdates()
        loadProducts()
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() {
        Task {
            do {
                let products = try await Product.products(for: [monthlySubscriptionID])
                await MainActor.run {
                    self.products = products
                }
            } catch {
                print("Failed to load products: \(error)")
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    // Process successful purchase
                    await updateSubscriptionStatus(transaction: transaction)
                    await transaction.finish()
                case .unverified:
                    throw StoreKitError.failedVerification
                }
            case .userCancelled:
                throw StoreKitError.userCancelled
            case .pending:
                // Transaction pending external action
                break
            @unknown default:
                throw StoreKitError.unknown
            }
        } catch {
            print("Purchase failed: \(error)")
            throw error
        }
    }
    
    func checkSubscriptionStatus() async {
        do {
            // For development purposes, always return active
            if isTestMode {
                await MainActor.run {
                    self.subscriptionStatus = .active
                }
                return
            }
            
            // In production, verify transaction receipt
            let latestTransaction = await getLatestTransaction()
            if let transaction = latestTransaction {
                let isActive = await isSubscriptionActive(transaction: transaction)
                await MainActor.run {
                    self.subscriptionStatus = isActive ? .active : .inactive
                }
                
                // Also update the database
                await updateSubscriptionInDatabase(transaction: transaction)
            } else {
                await MainActor.run {
                    self.subscriptionStatus = .inactive
                }
            }
        } catch {
            print("Error checking subscription status: \(error)")
            await MainActor.run {
                self.subscriptionStatus = .unknown
            }
        }
    }
    
    private func getLatestTransaction() async -> Transaction? {
        do {
            var latestTransaction: Transaction? = nil
            
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == monthlySubscriptionID &&
                       (latestTransaction == nil || transaction.purchaseDate > latestTransaction!.purchaseDate) {
                        latestTransaction = transaction
                    }
                case .unverified:
                    continue
                }
            }
            
            return latestTransaction
        } catch {
            print("Error getting latest transaction: \(error)")
            return nil
        }
    }
    
    private func isSubscriptionActive(transaction: Transaction) async -> Bool {
        guard let expirationDate = transaction.expirationDate else {
            return false
        }
        
        let isActive = expirationDate > Date() && transaction.revocationDate == nil
        return isActive
    }
    
    private func updateSubscriptionStatus(transaction: Transaction) async {
        let isActive = await isSubscriptionActive(transaction: transaction)
        
        await MainActor.run {
            self.subscriptionStatus = isActive ? .active : .inactive
        }
        
        // Also update the database
        await updateSubscriptionInDatabase(transaction: transaction)
    }
    
    private func updateSubscriptionInDatabase(transaction: Transaction) async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let userId = session.user.id
            
            guard !userId.isEmpty else {
                return
            }
            
            // Check if subscription record exists
            let existingResponse = try await SupabaseService.shared.client
                .from("app_subscriptions")
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let isActive = await isSubscriptionActive(transaction: transaction)
            let status = isActive ? "active" : "expired"
            
            let existingSubscriptions = try existingResponse.decoded() as [AppSubscription]
            
            if existingSubscriptions.isEmpty {
                // Create new subscription record
                let subscriptionData: [String: Any] = [
                    "user_id": userId,
                    "product_id": transaction.productID,
                    "status": status,
                    "expires_at": transaction.expirationDate as Any
                ]
                
                try await SupabaseService.shared.client
                    .from("app_subscriptions")
                    .insert(subscriptionData)
                    .execute()
            } else {
                // Update existing subscription
                let subscriptionData: [String: Any] = [
                    "product_id": transaction.productID,
                    "status": status,
                    "expires_at": transaction.expirationDate as Any,
                    "updated_at": Date()
                ]
                
                try await SupabaseService.shared.client
                    .from("app_subscriptions")
                    .update(subscriptionData)
                    .eq("user_id", value: userId)
                    .execute()
            }
        } catch {
            print("Error updating subscription in database: \(error)")
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Error> {
        return Task.detached {
            for await verificationResult in Transaction.updates {
                switch verificationResult {
                case .verified(let transaction):
                    // Process transaction update
                    await self.updateSubscriptionStatus(transaction: transaction)
                    await transaction.finish()
                case .unverified:
                    // Handle unverified transaction
                    break
                }
            }
        }
    }
}

enum StoreKitError: Error {
    case failedVerification
    case userCancelled
    case unknown
}
