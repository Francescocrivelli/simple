import Foundation
import Supabase
import Contacts

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var labels: [Label] = []
    
    private let supabase = SupabaseService.shared.client
    private let contactStore = CNContactStore()
    private let aiService = AIService.shared
    
    // Fetch user's labels
    func fetchLabels() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        do {
            let response = try await supabase
                .from("labels")
                .select()
                .eq("user_id", value: userIdString)
                .order("name")
                .execute()
            
            let decoder = JSONDecoder()
            // data is not optional, use directly
            let responseData = response.data
            if let fetchedLabels = try? decoder.decode([Label].self, from: responseData) {
                await MainActor.run {
                    self.labels = fetchedLabels
                }
            }
        } catch {
            print("Error fetching labels: \(error)")
            throw error
        }
    }
    
    // Create a new label
    func createLabel(name: String) async throws -> Label {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        do {
            let labelData: [String: String] = [
                "user_id": userIdString,
                "name": name
            ]
            
            let response = try await supabase
                .from("labels")
                .insert(labelData)
                .select()
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            // data is not optional, use directly
            let responseData = response.data
            if let newLabel = try? decoder.decode(Label.self, from: responseData) {
                await MainActor.run {
                    self.labels.append(newLabel)
                    self.labels.sort { $0.name < $1.name }
                }
                
                return newLabel
            } else {
                throw NSError(domain: "ContactService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to decode label"])
            }
        } catch {
            print("Error creating label: \(error)")
            throw error
        }
    }
    
    // Fetch user's contacts
    func fetchContacts() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        do {
            let response = try await supabase
                .from("contacts")
                .select("*, labels(*)")
                .eq("user_id", value: userIdString)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            // data is not optional, use directly
            let responseData = response.data
            if let fetchedContacts = try? decoder.decode([Contact].self, from: responseData) {
                await MainActor.run {
                    self.contacts = fetchedContacts
                }
            }
        } catch {
            print("Error fetching contacts: \(error)")
            throw error
        }
    }
    
    // Process natural language input to create/update contact
    func processContactInput(_ input: String) async throws -> Contact {
        // Extract contact info using AI
        let (name, phoneNumber, email, description) = try await aiService.extractContactInfo(from: input)
        
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty,
              let unwrappedName = name ?? extractNameFromDescription(description) else {
            throw NSError(domain: "ContactService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract name from input"])
        }
        
        // Create contact in database
        // Create a properly typed dictionary with only String values for Encodable conformance
        var contactData: [String: String] = [
            "user_id": userIdString,
            "name": unwrappedName,
            "text_description": description ?? input
        ]
        
        // Only add optional fields if they exist
        if let phoneNumber = phoneNumber {
            contactData["phone_number"] = phoneNumber
        }
        
        if let email = email {
            contactData["email"] = email
        }
        
        do {
            // Insert contact
            let response = try await supabase
                .from("contacts")
                .insert(contactData)
                .select()
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            // data is not optional, use directly
            let responseData = response.data
            guard var newContact = try? decoder.decode(Contact.self, from: responseData) else {
                throw NSError(domain: "ContactService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to decode contact"])
            }
            
            // Suggest labels
            if let description = description, !description.isEmpty {
                try await fetchLabels() // Ensure we have latest labels
                let suggestedLabels = try await aiService.suggestLabels(from: description, existingLabels: labels)
                
                // Assign suggested labels
                for label in suggestedLabels {
                    try await assignLabel(contactId: newContact.id, labelId: label.id)
                }
                
                // Add labels to the contact object
                newContact.labels = suggestedLabels
            }
            
            // Add to system contacts if we have a phone number
            if let phoneNumber = phoneNumber {
                let _ = try await addToSystemContacts(name: unwrappedName, phoneNumber: phoneNumber, email: email)
                
                // Update contact with system ID
                // This part would need implementation after handling system contacts
            }
            
            try await fetchContacts() // Refresh contacts list
            return newContact
        } catch {
            print("Error creating contact: \(error)")
            throw error
        }
    }
    
    // Assign a label to a contact
    func assignLabel(contactId: UUID, labelId: UUID) async throws {
        let contactLabelData: [String: String] = [
            "contact_id": contactId.uuidString,
            "label_id": labelId.uuidString
        ]
        
        do {
            try await supabase
                .from("contact_labels")
                .insert(contactLabelData)
                .execute()
        } catch {
            print("Error assigning label: \(error)")
            throw error
        }
    }
    
    // Remove a label from a contact
    func removeLabel(contactId: UUID, labelId: UUID) async throws {
        do {
            try await supabase
                .from("contact_labels")
                .delete()
                .eq("contact_id", value: contactId.uuidString)
                .eq("label_id", value: labelId.uuidString)
                .execute()
        } catch {
            print("Error removing label: \(error)")
            throw error
        }
    }
    
    // Search contacts using natural language
    func searchContacts(query: String) async throws -> [Contact] {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        // First try direct query on database fields
        do {
            let directResponse = try await supabase
                .from("contacts")
                .select("*, labels(*)")
                .eq("user_id", value: userIdString)
                .or("name.ilike.%\(query)%,text_description.ilike.%\(query)%,phone_number.ilike.%\(query)%,email.ilike.%\(query)%")
                .execute()
            
            let decoder = JSONDecoder()
            // data is not optional, use directly
            let responseData = directResponse.data
            if let directResults = try? decoder.decode([Contact].self, from: responseData) {
                
                if !directResults.isEmpty {
                    return directResults
                }
            }
        } catch {
            print("Error in direct search: \(error)")
        }
        
        // If direct search yields no results, use AI to interpret the query
        // This would normally be implemented with more sophisticated embedding-based search
        // For now, we'll fetch all contacts and filter them locally with a simple relevance check
        do {
            let aiPrompt = """
            Given this search query: "\(query)"
            
            What terms or concepts should we look for in contact descriptions? 
            Return a JSON array of keywords/phrases.
            """
            
            // We're not using the actual AI service here to keep it simple
            // In a real implementation, this would use embedding search or a more sophisticated approach
            
            // Fetch all contacts and do local filtering based on the query
            try await fetchContacts()
            
            // Simple relevance scoring
            let allContacts = self.contacts
            let queryTerms = query.lowercased().split(separator: " ").map(String.init)
            
            let scoredContacts = allContacts.map { contact -> (Contact, Double) in
                var score = 0.0
                
                // Name match
                if let name = contact.name?.lowercased(), name.contains(query.lowercased()) {
                    score += 3.0
                }
                
                // Description match
                if let description = contact.textDescription?.lowercased() {
                    for term in queryTerms {
                        if description.contains(term) {
                            score += 1.0
                        }
                    }
                }
                
                // Label match
                if let labels = contact.labels {
                    for label in labels {
                        if label.name.lowercased().contains(query.lowercased()) {
                            score += 2.0
                        }
                    }
                }
                
                return (contact, score)
            }
            
            // Filter and sort by relevance
            let filteredContacts = scoredContacts
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
            
            return filteredContacts
        } catch {
            print("Error in AI search: \(error)")
            throw error
        }
    }
    
    // Sync with system contacts
    func syncWithSystemContacts() async throws {
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authStatus {
        case .authorized:
            try await performContactSync()
        case .notDetermined:
            let granted = try await contactStore.requestAccess(for: .contacts)
            if granted {
                try await performContactSync()
            } else {
                throw NSError(domain: "ContactService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permission to access contacts was denied"])
            }
        case .denied, .restricted:
            throw NSError(domain: "ContactService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Permission to access contacts was denied"])
        @unknown default:
            throw NSError(domain: "ContactService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status"])
        }
    }
    
    private func performContactSync() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        // Convert UUID to string
        let userIdString = userId.uuidString
        
        guard !userIdString.isEmpty else {
            throw AuthError.userNotFound
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var systemContacts: [CNContact] = []
        
        try contactStore.enumerateContacts(with: request) { contact, stop in
            systemContacts.append(contact)
        }
        
        // Process contacts in batches to avoid overloading the database
        let batchSize = 50
        for i in stride(from: 0, to: systemContacts.count, by: batchSize) {
            let endIndex = min(i + batchSize, systemContacts.count)
            let batch = systemContacts[i..<endIndex]
            
            for contact in batch {
                guard !contact.phoneNumbers.isEmpty else { continue }
                
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                
                guard !name.isEmpty else { continue }
                
                // Check if contact already exists in our database
                let phoneNumber = contact.phoneNumbers.first?.value.stringValue.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                
                if let phoneNumber = phoneNumber {
                    let existingResponse = try await supabase
                        .from("contacts")
                        .select()
                        .eq("user_id", value: userIdString)
                        .eq("phone_number", value: phoneNumber)
                        .execute()
                    
                    let decoder = JSONDecoder()
                    // data is not optional, use directly
                    let responseData = existingResponse.data
                    if let existingContacts = try? decoder.decode([Contact].self, from: responseData) {
                        
                        if existingContacts.isEmpty {
                            // Create new contact
                            let email = contact.emailAddresses.first?.value as String?
                            
                            var contactData: [String: String] = [
                                "user_id": userIdString,
                                "name": name,
                                "phone_number": phoneNumber,
                                "system_contact_id": contact.identifier,
                                "text_description": "Imported from phone contacts"
                            ]
                            
                            // Add email if available
                            if let email = email {
                                contactData["email"] = email
                            }
                            
                            try await supabase
                                .from("contacts")
                                .insert(contactData)
                                .execute()
                        }
                    }
                }
            }
        }
        
        // Update user preferences to mark contacts as synced
        try await AuthService.shared.updateUserPreferences(hasSyncedContacts: true)
        
        // Refresh contacts
        try await fetchContacts()
    }
    
    // Add a new contact to the system contact book
    private func addToSystemContacts(name: String, phoneNumber: String, email: String?) async throws -> String? {
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authStatus {
        case .authorized:
            return try createSystemContact(name: name, phoneNumber: phoneNumber, email: email)
        case .notDetermined:
            let granted = try await contactStore.requestAccess(for: .contacts)
            if granted {
                return try createSystemContact(name: name, phoneNumber: phoneNumber, email: email)
            } else {
                return nil
            }
        case .denied, .restricted:
            return nil
        @unknown default:
            return nil
        }
    }
    
    private func createSystemContact(name: String, phoneNumber: String, email: String?) throws -> String? {
        let nameParts = name.components(separatedBy: " ")
        
        let contact = CNMutableContact()
        if nameParts.count > 1 {
            contact.givenName = nameParts[0]
            contact.familyName = nameParts.dropFirst().joined(separator: " ")
        } else {
            contact.givenName = name
        }
        
        let phoneValue = CNPhoneNumber(stringValue: phoneNumber)
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneValue)]
        
        if let email = email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        do {
            try contactStore.execute(saveRequest)
            return contact.identifier
        } catch {
            print("Error creating system contact: \(error)")
            return nil
        }
    }
    
    // Helper function
    private func extractNameFromDescription(_ description: String?) -> String? {
        guard let description = description else { return nil }
        
        // Simple name extraction - first two words if they start with capital letters
        let words = description.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if words.count >= 2,
           let firstChar = words[0].first, firstChar.isUppercase,
           let secondFirstChar = words[1].first, secondFirstChar.isUppercase {
            return [words[0], words[1]].joined(separator: " ")
        } else if !words.isEmpty, let firstChar = words[0].first, firstChar.isUppercase {
            return words[0]
        }
        
        return nil
    }
}
