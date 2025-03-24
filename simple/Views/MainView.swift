import SwiftUI

struct MainView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @StateObject private var contactService = ContactService.shared
    
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showSubscriptionSheet = false
    @State private var searchResults: [Contact] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // AI Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add or search contacts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Add or search contacts...", text: $inputText)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: inputText) { newValue in
                                // If the user clears the field, reset search results
                                if newValue.isEmpty {
                                    searchResults = []
                                    isSearching = false
                                }
                            }
                        
                        Button(action: processInput) {
                            Image(systemName: isProcessing ? "hourglass" : "paperplane.fill")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(inputText.isEmpty || isProcessing)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                
                // Results
                if isSearching {
                    if searchResults.isEmpty {
                        VStack {
                            Spacer()
                            Text("No contacts found")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(searchResults) { contact in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    ContactRow(contact: contact)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    if contactService.contacts.isEmpty {
                        VStack {
                            Spacer()
                            Text("No contacts yet")
                                .foregroundColor(.secondary)
                            Text("Add your first contact using the field above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(contactService.contacts) { contact in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    ContactRow(contact: contact)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("NoteAI")
            .navigationBarItems(
                trailing: Menu {
                    Button(action: {
                        showSubscriptionSheet = true
                    }) {
                        HStack {
                            Text("Subscription")
                            Image(systemName: "creditcard")
                        }
                    }
                    
                    Button(action: signOut) {
                        HStack {
                            Text("Sign Out")
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView()
            }
            .onAppear {
                // Load contacts and labels when view appears
                Task {
                    do {
                        try await contactService.fetchContacts()
                        try await contactService.fetchLabels()
                    } catch {
                        errorMessage = "Failed to load data: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func processInput() {
        // Trim whitespace from input
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        errorMessage = nil
        isProcessing = true
        
        // Check if this is a search query or a new contact
        if trimmedInput.lowercased().starts(with: "search") ||
           trimmedInput.lowercased().starts(with: "find") ||
           trimmedInput.lowercased().starts(with: "look for") ||
           trimmedInput.contains("?") {
            // This looks like a search query
            searchContacts(query: trimmedInput)
        } else {
            // This looks like a new contact
            createContact(input: trimmedInput)
        }
    }
    
    private func searchContacts(query: String) {
        Task {
            do {
                let results = try await contactService.searchContacts(query: query)
                
                await MainActor.run {
                    searchResults = results
                    isSearching = true
                    isProcessing = false
                    
                    if results.isEmpty {
                        errorMessage = "No matching contacts found."
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createContact(input: String) {
        Task {
            do {
                let _ = try await contactService.processContactInput(input)
                
                await MainActor.run {
                    inputText = ""
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to create contact: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await authService.signOut()
            } catch {
                errorMessage = "Failed to sign out: \(error.localizedDescription)"
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unnamed Contact")
                .font(.headline)
            
            if let phoneNumber = contact.phoneNumber {
                Text(phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let labels = contact.labels, !labels.isEmpty {
                HStack {
                    ForEach(labels.prefix(3)) { label in
                        Text(label.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if (labels.count > 3) {
                        Text("+\(labels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AuthService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}
