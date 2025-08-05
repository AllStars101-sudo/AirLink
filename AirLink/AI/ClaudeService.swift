import Foundation

class ClaudeService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private weak var toolService: AirFrameToolService?
    
    init(toolService: AirFrameToolService? = nil) {
        self.apiKey = APIKeyManager.shared.claudeAPIKey
        self.toolService = toolService
        
        // Debug logging
        print("🔑 Claude Service Initialized:")
        print("  - Key present: \(!apiKey.isEmpty)")
        print("  - Tool service: \(toolService != nil ? "✅" : "❌")")
        if !apiKey.isEmpty {
            print("  - Key length: \(apiKey.count)")
            print("  - Key preview: \(String(apiKey.prefix(8)))...")
        }
    }
    
    func sendMessage(
        _ content: String,
        tools: [AITool] = [],
        conversationHistory: [ChatMessage] = []
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            print("🚨 Missing Claude API Key")
            print("Please set ANTHROPIC_API_KEY in your environment variables")
            throw AIError.missingAPIKey
        }
        
        print("🤖 Claude API Request:")
        print("Message: \(content)")
        print("Tools: \(tools.count)")
        print("History: \(conversationHistory.count) messages")
        
        let request = ClaudeRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024,
            messages: buildMessages(from: conversationHistory, newContent: content),
            tools: tools.map { $0.toClaudeFormat() }
        )
        
        let data = try JSONEncoder().encode(request)
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("Invalid response type from Claude API")
        }
        
        // Enhanced error handling with specific status codes
        if httpResponse.statusCode != 200 {
            let errorMessage: String
            if let errorData = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                errorMessage = "Claude API Error (\(httpResponse.statusCode)): \(message)"
            } else {
                switch httpResponse.statusCode {
                case 401:
                    errorMessage = "Claude API: Unauthorized - Please check your API key"
                case 400:
                    errorMessage = "Claude API: Bad Request - Invalid request format"
                case 429:
                    errorMessage = "Claude API: Rate limit exceeded - Please try again later"
                case 500...599:
                    errorMessage = "Claude API: Server error (\(httpResponse.statusCode)) - Please try again"
                default:
                    errorMessage = "Claude API: HTTP \(httpResponse.statusCode) error"
                }
            }
            
            print("🚨 Claude API Error Details:")
            print("Status Code: \(httpResponse.statusCode)")
            print("Response: \(String(data: responseData, encoding: .utf8) ?? "No response data")")
            
            throw AIError.apiError(errorMessage)
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseData)
        
        // Handle tool calls if present
        if let toolCall = claudeResponse.content.first(where: { $0.type == "tool_use" }) {
            print("🔧 Tool call detected: \(toolCall.name ?? "unknown")")
            return try await handleToolCall(toolCall, originalResponse: claudeResponse)
        }
        
        return claudeResponse.content.first(where: { $0.type == "text" })?.text ?? "I apologize, but I couldn't process your request."
    }
    
    private func buildMessages(from history: [ChatMessage], newContent: String) -> [ClaudeMessage] {
        var messages: [ClaudeMessage] = []
        
        // Add conversation history (excluding system messages)
        for message in history.suffix(10) { // Keep last 10 messages for context
            if message.content != "Hello! I'm Aerial, your AI assistant for the AirFrame. I can help you control your gimbal, analyze scenes for perfect shots, and much more. How can I assist you today?" {
                messages.append(ClaudeMessage(
                    role: message.isUser ? "user" : "assistant",
                    content: message.content
                ))
            }
        }
        
        // Add new user message
        messages.append(ClaudeMessage(role: "user", content: newContent))
        
        return messages
    }
    
    private func handleToolCall(_ toolCall: ClaudeContent, originalResponse: ClaudeResponse) async throws -> String {
        guard let toolName = toolCall.name else {
            throw AIError.invalidToolCall
        }
        
        print("🔧 Executing tool: \(toolName)")
        
        // Execute the tool call through the provided AirFrameToolService
        guard let toolService = self.toolService else {
            return "Tool service not available. Please ensure AirFrame is properly initialized."
        }
        
        // For now, pass empty input - we'll enhance this later
        let toolResult = try await toolService.executeTool(name: toolName, input: [:])
        
        // Send tool result back to Claude for final response
        let followUpRequest = ClaudeRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024,
            messages: [
                ClaudeMessage(role: "user", content: "Tool execution result: \(toolResult)")
            ]
        )
        
        let data = try JSONEncoder().encode(followUpRequest)
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = data
        
        let (responseData, _) = try await URLSession.shared.data(for: urlRequest)
        let finalResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseData)
        
        return finalResponse.content.first(where: { $0.type == "text" })?.text ?? "Tool executed successfully."
    }
}

// MARK: - Claude API Models
struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let tools: [ClaudeToolFormat]?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, tools
        case maxTokens = "max_tokens"
    }
    
    init(model: String, maxTokens: Int, messages: [ClaudeMessage], tools: [ClaudeToolFormat] = []) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.tools = tools.isEmpty ? nil : tools
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
    let model: String
    let role: String
    let stopReason: String?
    let usage: ClaudeUsage
    
    enum CodingKeys: String, CodingKey {
        case content, model, role, usage
        case stopReason = "stop_reason"
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
    let name: String?
    let input: [String: Any]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        // Simplified input handling - just store as nil for now
        // Tool input parsing will be handled separately if needed
        input = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(name, forKey: .name)
        // Skip input encoding for now
    }
    
    enum CodingKeys: String, CodingKey {
        case type, text, name, input
    }
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct ClaudeToolFormat: Codable {
    let name: String
    let description: String
    let inputSchema: ClaudeToolSchema
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
    
    init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = ClaudeToolSchema(from: inputSchema)
    }
}

struct ClaudeToolSchema: Codable {
    let type: String
    let properties: [String: ClaudeToolProperty]
    let required: [String]
    
    init(from dict: [String: Any]) {
        self.type = dict["type"] as? String ?? "object"
        
        let propsDict = dict["properties"] as? [String: [String: Any]] ?? [:]
        var properties: [String: ClaudeToolProperty] = [:]
        
        for (key, value) in propsDict {
            properties[key] = ClaudeToolProperty(from: value)
        }
        
        self.properties = properties
        self.required = dict["required"] as? [String] ?? []
    }
}

struct ClaudeToolProperty: Codable {
    let type: String
    let description: String
    let enumValues: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }
    
    init(from dict: [String: Any]) {
        self.type = dict["type"] as? String ?? "string"
        self.description = dict["description"] as? String ?? ""
        self.enumValues = dict["enum"] as? [String]
    }
}

// MARK: - Error Types
enum AIError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case invalidToolCall
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key not found. Please add your API key to environment variables."
        case .apiError(let message):
            return "API Error: \(message)"
        case .invalidToolCall:
            return "Invalid tool call received from AI"
        case .decodingError:
            return "Failed to decode AI response"
        }
    }
}
