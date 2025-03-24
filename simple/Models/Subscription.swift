import Foundation

struct AppSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: String?
    let status: String?
    let expiresAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
