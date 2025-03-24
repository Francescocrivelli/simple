import Foundation

struct Label: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    static func == (lhs: Label, rhs: Label) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ContactLabel: Codable, Identifiable {
    let id: UUID
    let contactId: UUID
    let labelId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case labelId = "label_id"
        case createdAt = "created_at"
    }
}
