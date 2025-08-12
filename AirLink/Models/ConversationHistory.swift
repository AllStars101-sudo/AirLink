import Foundation
import SwiftUI

// MARK: - Conversation Model
@Observable
class Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var lastUpdated: Date
    var isActive: Bool
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.isActive = false
    }
    
    // Computed properties for UI
    var preview: String {
        guard let lastMessage = messages.last else {
            return "No messages yet"
        }
        
        let content = lastMessage.content
        let maxLength = 100
        
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
    
    // Auto-generate title from first message
    func updateTitleFromMessages() {
        guard title == "New Conversation" || title.hasPrefix("Chat with Aerial"),
              let firstUserMessage = messages.first(where: { $0.isUser }) else {
            return
        }
        
        let content = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 50
        
        if content.count > maxLength {
            title = String(content.prefix(maxLength)) + "..."
        } else {
            title = content.isEmpty ? "Chat with Aerial" : content
        }
    }
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastUpdated = Date()
        updateTitleFromMessages()
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, title, messages, createdAt, lastUpdated, isActive
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(messages, forKey: .messages)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(isActive, forKey: .isActive)
    }
}

// MARK: - ChatMessage Codable Extension
extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Conversation History Manager
@MainActor
@Observable
class ConversationHistoryManager {
    private(set) var conversations: [Conversation] = []
    private(set) var currentConversation: Conversation?
    
    private let storageKey = "AerialConversationHistory"
    private let maxConversations = 50 // Limit to prevent storage bloat
    
    init() {
        loadConversations()
        
        // Create initial conversation if none exist
        if conversations.isEmpty {
            createNewConversation()
        } else {
            // Set the most recent conversation as current
            currentConversation = conversations.first
            currentConversation?.isActive = true
        }
    }
    
    // MARK: - Conversation Management
    
    func createNewConversation(title: String = "New Conversation") -> Conversation {
        // Deactivate current conversation
        currentConversation?.isActive = false
        
        let newConversation = Conversation(title: title)
        newConversation.isActive = true
        
        conversations.insert(newConversation, at: 0)
        currentConversation = newConversation
        
        // Limit total conversations
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }
        
        saveConversations()
        return newConversation
    }
    
    func switchToConversation(_ conversation: Conversation) {
        // Deactivate current conversation
        currentConversation?.isActive = false
        
        // Activate selected conversation
        conversation.isActive = true
        currentConversation = conversation
        
        // Move to front of list (most recent)
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
        }
        
        saveConversations()
    }
    
    func deleteConversation(_ conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        
        let wasCurrentConversation = conversation.id == currentConversation?.id
        conversations.remove(at: index)
        
        if wasCurrentConversation {
            // Switch to next available conversation or create new one
            if let nextConversation = conversations.first {
                switchToConversation(nextConversation)
            } else {
                createNewConversation()
            }
        }
        
        saveConversations()
    }
    
    func addMessageToCurrentConversation(_ message: ChatMessage) {
        guard let current = currentConversation else {
            // Create new conversation if none exists
            let newConversation = createNewConversation()
            newConversation.addMessage(message)
            return
        }
        
        current.addMessage(message)
        
        // Move current conversation to front of list
        if let index = conversations.firstIndex(where: { $0.id == current.id }), index > 0 {
            conversations.remove(at: index)
            conversations.insert(current, at: 0)
        }
        
        saveConversations()
    }
    
    func renameConversation(_ conversation: Conversation, to newTitle: String) {
        conversation.title = newTitle
        conversation.lastUpdated = Date()
        saveConversations()
    }
    
    func clearAllConversations() {
        conversations.removeAll()
        currentConversation = nil
        createNewConversation()
        saveConversations()
    }
    
    // MARK: - Persistence
    
    private func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 Saved \(conversations.count) conversations")
        } catch {
            print("❌ Failed to save conversations: \(error)")
        }
    }
    
    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📚 No saved conversations found")
            return
        }
        
        do {
            conversations = try JSONDecoder().decode([Conversation].self, from: data)
            print("📚 Loaded \(conversations.count) conversations")
            
            // Find active conversation or set first as active
            if let activeConversation = conversations.first(where: { $0.isActive }) {
                currentConversation = activeConversation
            } else if let firstConversation = conversations.first {
                firstConversation.isActive = true
                currentConversation = firstConversation
            }
        } catch {
            print("❌ Failed to load conversations: \(error)")
            conversations = []
        }
    }
    
    // MARK: - Computed Properties
    
    var hasMultipleConversations: Bool {
        conversations.count > 1
    }
    
    var sortedConversations: [Conversation] {
        conversations.sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    // MARK: - Search and Filtering
    
    func searchConversations(query: String) -> [Conversation] {
        guard !query.isEmpty else { return sortedConversations }
        
        let lowercaseQuery = query.lowercased()
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowercaseQuery) ||
            conversation.messages.contains { message in
                message.content.lowercased().contains(lowercaseQuery)
            }
        }.sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    func conversationsFromLastWeek() -> [Conversation] {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return conversations.filter { $0.lastUpdated >= weekAgo }
    }
    
    func conversationsFromLastMonth() -> [Conversation] {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return conversations.filter { $0.lastUpdated >= monthAgo }
    }
}