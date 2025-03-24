import Foundation

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
    case apiError(String)
}

class AIService {
    static let shared = AIService()
    
    // API key should be stored securely and not hardcoded
    private let apiKey: String = {
        // In a real app, use a secure storage method like Keychain
        // For development, read from environment or config
        return "API_KEY_PLACEHOLDER" // Replace with secure method
    }()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    // Extract contact information from text
    func extractContactInfo(from text: String) async throws -> (name: String?, phoneNumber: String?, email: String?, description: String?) {
        let prompt = """
        Extract contact information from the following text. Return a JSON object with these fields if found:
        - name (full name)
        - phoneNumber (in E.164 format if possible)
        - email
        - description (any additional context or notes about the person)

        Text: \(text)

        JSON response:
        """
        
        let response = try await sendRequest(prompt: prompt)
        
        // Parse the JSON response
        guard let jsonData = response.data(using: .utf8) else {
            throw AIServiceError.decodingFailed
        }
        
        struct ContactInfo: Codable {
            let name: String?
            let phoneNumber: String?
            let email: String?
            let description: String?
        }
        
        do {
            let contactInfo = try JSONDecoder().decode(ContactInfo.self, from: jsonData)
            return (contactInfo.name, contactInfo.phoneNumber, contactInfo.email, contactInfo.description)
        } catch {
            print("JSON parsing error: \(error)")
            
            // Fallback: Try to extract info manually if JSON parsing fails
            return (
                name: extractNameFromText(text),
                phoneNumber: extractPhoneNumberFromText(text),
                email: extractEmailFromText(text),
                description: text
            )
        }
    }
    
    // Suggest labels for a contact based on description
    func suggestLabels(from description: String, existingLabels: [Label]) async throws -> [Label] {
        let labelNames = existingLabels.map { $0.name }.joined(separator: ", ")
        
        let prompt = """
        Based on this description of a contact, suggest up to 3 appropriate labels from the existing labels list. If none of the existing labels fit, suggest up to 2 new label names that would be appropriate.

        Description: \(description)

        Existing labels: \(labelNames)

        Return a JSON object with these fields:
        - existingLabels: array of label names from the existing list
        - newLabels: array of suggested new label names

        JSON response:
        """
        
        let response = try await sendRequest(prompt: prompt)
        
        // Parse the JSON response
        guard let jsonData = response.data(using: .utf8) else {
            throw AIServiceError.decodingFailed
        }
        
        struct LabelSuggestions: Codable {
            let existingLabels: [String]
            let newLabels: [String]
        }
        
        do {
            let suggestions = try JSONDecoder().decode(LabelSuggestions.self, from: jsonData)
            
            // Match existing labels
            let matchedLabels = existingLabels.filter { label in
                suggestions.existingLabels.contains { $0.lowercased() == label.name.lowercased() }
            }
            
            return matchedLabels
        } catch {
            print("JSON parsing error: \(error)")
            return []
        }
    }
    
    // Send a request to OpenAI API
    private func sendRequest(prompt: String) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a helpful assistant for a contact management app. You extract and organize contact information."],
            ["role": "user", "content": prompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": messages,
            "temperature": 0.1
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.requestFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? "Unknown API error"
            throw AIServiceError.apiError(errorMessage)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.decodingFailed
        }
        
        return content
    }
    
    // Helper functions for fallback extraction
    private func extractNameFromText(_ text: String) -> String? {
        // Basic name extraction - in reality would use NLP
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count >= 2 {
            return [words[0], words[1]].joined(separator: " ")
        } else if words.count == 1 {
            return words[0]
        }
        return nil
    }
    
    private func extractPhoneNumberFromText(_ text: String) -> String? {
        // Simple regex for phone numbers
        let phonePattern = "\\b(\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4}|\\+\\d{1,3}[-.\\s]?\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4})\\b"
        let regex = try? NSRegularExpression(pattern: phonePattern)
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }
        return nil
    }
    
    private func extractEmailFromText(_ text: String) -> String? {
        // Simple regex for email
        let emailPattern = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b"
        let regex = try? NSRegularExpression(pattern: emailPattern)
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }
        return nil
    }
}
