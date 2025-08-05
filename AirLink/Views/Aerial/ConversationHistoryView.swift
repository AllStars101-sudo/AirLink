import SwiftUI

struct ConversationHistoryView: View {
    @Environment(AirFrameModel.self) private var airFrameModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var conversationToDelete: Conversation?
    @State private var showingRenameDialog = false
    @State private var conversationToRename: Conversation?
    @State private var newConversationTitle = ""
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return airFrameModel.aerial.conversationHistory.sortedConversations
        } else {
            return airFrameModel.aerial.conversationHistory.searchConversations(query: searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Stats
                    headerStatsView
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    // Conversations List
                    if filteredConversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsList
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search conversations...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            airFrameModel.aerial.createNewConversation()
                            dismiss()
                        } label: {
                            Label("New Conversation", systemImage: "plus.message")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear All Conversations",
            isPresented: $showingDeleteConfirmation,
            presenting: conversationToDelete
        ) { conversation in
            if conversation != nil {
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        airFrameModel.aerial.deleteConversation(conversation)
                    }
                    conversationToDelete = nil
                }
            } else {
                Button("Clear All", role: .destructive) {
                    airFrameModel.aerial.conversationHistory.clearAllConversations()
                }
            }
            
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
        } message: { conversation in
            if conversation != nil {
                Text("This will permanently delete this conversation and cannot be undone.")
            } else {
                Text("This will permanently delete all conversations and cannot be undone.")
            }
        }
        .alert("Rename Conversation", isPresented: $showingRenameDialog) {
            TextField("Conversation Title", text: $newConversationTitle)
            Button("Cancel", role: .cancel) {
                conversationToRename = nil
                newConversationTitle = ""
            }
            Button("Rename") {
                if let conversation = conversationToRename {
                    airFrameModel.aerial.conversationHistory.renameConversation(
                        conversation, 
                        to: newConversationTitle
                    )
                }
                conversationToRename = nil
                newConversationTitle = ""
            }
        } message: {
            Text("Enter a new title for this conversation.")
        }
    }
    
    private var headerStatsView: some View {
        HStack(spacing: 20) {
            statCard(
                title: "Total",
                value: "\(airFrameModel.aerial.conversationHistory.conversations.count)",
                icon: "message",
                color: .blue
            )
            
            statCard(
                title: "This Week",
                value: "\(airFrameModel.aerial.conversationHistory.conversationsFromLastWeek().count)",
                icon: "calendar",
                color: .green
            )
            
            statCard(
                title: "Messages",
                value: "\(totalMessageCount)",
                icon: "bubble.left.and.bubble.right",
                color: .purple
            )
        }
        .padding(.bottom)
    }
    
    private var totalMessageCount: Int {
        airFrameModel.aerial.conversationHistory.conversations.reduce(0) { total, conversation in
            total + conversation.messageCount
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.badge")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Conversations Found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Text(searchText.isEmpty 
                 ? "Start a new conversation with Aerial to see your chat history here."
                 : "No conversations match your search.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if searchText.isEmpty {
                Button {
                    airFrameModel.aerial.createNewConversation()
                    dismiss()
                } label: {
                    Label("Start New Conversation", systemImage: "plus.message")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue, in: Capsule())
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var conversationsList: some View {
        List {
            ForEach(filteredConversations) { conversation in
                ConversationRowView(
                    conversation: conversation,
                    isActive: conversation.id == airFrameModel.aerial.conversationHistory.currentConversation?.id,
                    onSelect: {
                        airFrameModel.aerial.switchToConversation(conversation)
                        dismiss()
                    },
                    onRename: {
                        conversationToRename = conversation
                        newConversationTitle = conversation.title
                        showingRenameDialog = true
                    },
                    onDelete: {
                        conversationToDelete = conversation
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
        .listStyle(.plain)
        .background(.clear)
    }
}

private struct ConversationRowView: View {
    let conversation: Conversation
    let isActive: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(isActive ? .blue : .clear)
                    .stroke(isActive ? .clear : .secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.title)
                            .font(.headline)
                            .fontWeight(isActive ? .semibold : .medium)
                            .foregroundStyle(isActive ? .blue : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(conversation.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(conversation.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        Label("\(conversation.messageCount)", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        if isActive {
                            Label("Active", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                    }
                }
                
                // Action Menu
                Menu {
                    Button {
                        onSelect()
                    } label: {
                        Label("Switch to Conversation", systemImage: "arrow.right.circle")
                    }
                    
                    Button {
                        onRename()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.regularMaterial, in: Circle())
                }
                .menuStyle(.borderlessButton)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? .blue.opacity(0.1) : .clear)
                .stroke(isActive ? .blue.opacity(0.3) : .clear, lineWidth: 1)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

#Preview {
    ConversationHistoryView()
        .environment(AirFrameModel())
}
