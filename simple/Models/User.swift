import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserPreferences: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let hasCompletedOnboarding: Bool?
    let hasSyncedContacts: Bool?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case hasSyncedContacts = "has_synced_contacts"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
