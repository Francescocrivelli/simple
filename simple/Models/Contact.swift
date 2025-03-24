import Foundation

struct Contact: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String?
    let phoneNumber: String?
    let email: String?
    let systemContactId: String?
    let textDescription: String?
    let createdAt: Date
    let updatedAt: Date
    var labels: [Label]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case phoneNumber = "phone_number"
        case email
        case systemContactId = "system_contact_id"
        case textDescription = "text_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case labels
    }
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
