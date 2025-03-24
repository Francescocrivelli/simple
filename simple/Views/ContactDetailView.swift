import SwiftUI

struct ContactDetailView: View {
    let contact: Contact
    @State private var newLabelName = ""
    @State private var showingAddLabelSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var contactService = ContactService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Contact avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(contactInitials)
                            .font(.title)
                            .foregroundColor(.blue)
                    )
                    .padding(.bottom, 10)
                
                // Contact info
                VStack(alignment: .leading, spacing: 8) {
                    Text(contact.name ?? "Unnamed Contact")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let phoneNumber = contact.phoneNumber {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.secondary)
                            Text(phoneNumber)
                        }
                        .padding(.top, 2)
                    }
                    
                    if let email = contact.email {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.secondary)
                            Text(email)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                // Description
                if let description = contact.textDescription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(description)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                // Labels
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Labels")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddLabelSheet = true
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let labels = contact.labels, !labels.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(labels) { label in
                                LabelChip(label: label) {
                                    removeLabel(label)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        Text("No labels")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitle("Contact Details", displayMode: .inline)
        .sheet(isPresented: $showingAddLabelSheet) {
            addLabelView
        }
        .overlay(
            isLoading ? 
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                }
                .edgesIgnoringSafeArea(.all)
                : nil
        )
    }
    
    private var contactInitials: String {
        guard let name = contact.name, !name.isEmpty else {
            return "?"
        }
        
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        let validComponents = components.filter { !$0.isEmpty }
        
        if validComponents.count >= 2 {
            let firstInitial = validComponents[0].prefix(1)
            let secondInitial = validComponents[1].prefix(1)
            return "\(firstInitial)\(secondInitial)"
        } else if validComponents.count == 1 {
            return String(validComponents[0].prefix(1))
        } else {
            return "?"
        }
    }
    
    private var addLabelView: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Create New Label")) {
                        HStack {
                            TextField("New label name", text: $newLabelName)
                            
                            Button(action: createNewLabel) {
                                Text("Create")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            .disabled(newLabelName.isEmpty)
                        }
                    }
                    
                    Section(header: Text("Existing Labels")) {
                        ForEach(contactService.labels.filter { label in
                            guard let contactLabels = contact.labels else { return true }
                            return !contactLabels.contains(where: { $0.id == label.id })
                        }) { label in
                            Button(action: {
                                assignExistingLabel(label)
                            }) {
                                HStack {
                                    Text(label.name)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Add Label")
            .navigationBarItems(trailing: Button("Done") {
                showingAddLabelSheet = false
            })
        }
    }
    
    private func createNewLabel() {
        guard !newLabelName.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let newLabel = try await contactService.createLabel(name: newLabelName)
                try await contactService.assignLabel(contactId: contact.id, labelId: newLabel.id)
                
                // Refresh contact data to include the new label
                try await contactService.fetchContacts()
                
                await MainActor.run {
                    isLoading = false
                    newLabelName = ""
                    showingAddLabelSheet = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create label: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func assignExistingLabel(_ label: Label) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await contactService.assignLabel(contactId: contact.id, labelId: label.id)
                
                // Refresh contact data to include the new label
                try await contactService.fetchContacts()
                
                await MainActor.run {
                    isLoading = false
                    showingAddLabelSheet = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to assign label: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func removeLabel(_ label: Label) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await contactService.removeLabel(contactId: contact.id, labelId: label.id)
                
                // Refresh contact data
                try await contactService.fetchContacts()
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to remove label: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct LabelChip: View {
    let label: Label
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label.name)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

// Flow layout for labels
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for size in sizes {
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        
        return CGSize(width: maxWidth, height: currentY + maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for (index, size) in sizes.enumerated() {
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            subviews[index].place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}
