import Foundation

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private weak var toolService: AirFrameToolService?
    
    init(toolService: AirFrameToolService? = nil) {
        self.apiKey = APIKeyManager.shared.openAIAPIKey
        self.toolService = toolService
        
        // Debug logging
        print("🔑 OpenAI Service Initialized:")
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
            print("🚨 Missing OpenAI API Key")
            print("Please set OPENAI_API_KEY in your environment variables")
            throw AIError.missingAPIKey
        }
        
        print("🤖 OpenAI API Request:")
        print("Message: \(content)")
        print("Tools: \(tools.count)")
        print("History: \(conversationHistory.count) messages")
        
        let request = OpenAIRequest(
            model: "openai/gpt-oss-120b",
            messages: buildMessages(from: conversationHistory, newContent: content),
            tools: tools.isEmpty ? nil : tools.map { $0.toOpenAIFormat() },
            toolChoice: tools.isEmpty ? nil : "auto"
        )
        
        let data = try JSONEncoder().encode(request)
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("AirLink/1.0", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("AirLink", forHTTPHeaderField: "X-Title")
        urlRequest.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("Invalid response type from OpenAI API")
        }
        
        // Enhanced error handling with specific status codes
        if httpResponse.statusCode != 200 {
            let errorMessage: String
            if let errorData = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                errorMessage = "OpenAI API Error (\(httpResponse.statusCode)): \(message)"
            } else {
                switch httpResponse.statusCode {
                case 401:
                    errorMessage = "OpenAI API: Unauthorized - Please check your API key"
                case 400:
                    errorMessage = "OpenAI API: Bad Request - Invalid request format"
                case 429:
                    errorMessage = "OpenAI API: Rate limit exceeded - Please try again later"
                case 500...599:
                    errorMessage = "OpenAI API: Server error (\(httpResponse.statusCode)) - Please try again"
                default:
                    errorMessage = "OpenAI API: HTTP \(httpResponse.statusCode) error"
                }
            }
            
            print("🚨 OpenAI API Error Details:")
            print("Status Code: \(httpResponse.statusCode)")
            print("Response: \(String(data: responseData, encoding: .utf8) ?? "No response data")")
            
            throw AIError.apiError(errorMessage)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: responseData)
        
        guard let choice = openAIResponse.choices.first else {
            throw AIError.apiError("No response choices received")
        }
        
        // Handle tool calls if present
        if let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty {
            print("🔧 Tool calls detected: \(toolCalls.count)")
            return try await handleToolCalls(toolCalls, originalResponse: openAIResponse)
        }
        
        return choice.message.content ?? "I apologize, but I couldn't process your request."
    }
    
    private func buildMessages(from history: [ChatMessage], newContent: String) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        
        // Add system message
        messages.append(OpenAIMessage(
            role: "system",
            content: """
            You are Aerial, an AI assistant for the AirFrame gimbal system. You help users control their gimbal, analyze scenes for perfect shots, and provide expert photography advice.
            
            You have access to tools to control the gimbal directly. Always use the appropriate tools when users ask you to perform actions like changing modes, calibrating, or getting status.
            
            Be helpful, concise, and focused on providing the best gimbal and photography experience.
            """
        ))
        
        // Add conversation history (excluding system messages)
        for message in history.suffix(10) { // Keep last 10 messages for context
            if message.content != "Hello! I'm Aerial, your AI assistant for the AirFrame. I can help you control your gimbal, analyze scenes for perfect shots, and much more. How can I assist you today?" {
                messages.append(OpenAIMessage(
                    role: message.isUser ? "user" : "assistant",
                    content: message.content
                ))
            }
        }
        
        // Add new user message
        messages.append(OpenAIMessage(role: "user", content: newContent))
        
        return messages
    }
    
    private func handleToolCalls(_ toolCalls: [OpenAIToolCall], originalResponse: OpenAIResponse) async throws -> String {
        var toolResults: [String] = []
        
        guard let toolService = self.toolService else {
            return "Tool service not available. Please ensure AirFrame is properly initialized."
        }
        
        for toolCall in toolCalls {
            print("🔧 Executing tool: \(toolCall.function.name)")
            
            // Parse tool arguments
            var input: [String: Any] = [:]
            if let argumentsData = toolCall.function.arguments.data(using: .utf8),
               let parsedArgs = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
                input = parsedArgs
            }
            
            let toolResult = try await toolService.executeTool(name: toolCall.function.name, input: input)
            toolResults.append(toolResult)
        }
        
        // Return the combined tool results
        if toolResults.count == 1 {
            return toolResults.first!
        } else {
            return toolResults.enumerated().map { index, result in
                "Tool \(index + 1) result: \(result)"
            }.joined(separator: "\n\n")
        }
    }
}

// MARK: - OpenAI API Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAIToolFormat]?
    let toolChoice: String?
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, tools
        case toolChoice = "tool_choice"
        case maxTokens = "max_tokens"
    }
    
    init(model: String, messages: [OpenAIMessage], tools: [OpenAIToolFormat]? = nil, toolChoice: String? = nil, maxTokens: Int = 1024) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.maxTokens = maxTokens
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
    
    init(role: String, content: String, toolCalls: [OpenAIToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let model: String
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenAIToolFormat: Codable {
    let type: String
    let function: OpenAIFunctionDefinition
    
    init(name: String, description: String, parameters: [String: Any]) {
        self.type = "function"
        self.function = OpenAIFunctionDefinition(
            name: name,
            description: description,
            parameters: OpenAIFunctionParameters(from: parameters)
        )
    }
}

struct OpenAIFunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: OpenAIFunctionParameters
}

struct OpenAIFunctionParameters: Codable {
    let type: String
    let properties: [String: OpenAIProperty]
    let required: [String]
    
    init(from dict: [String: Any]) {
        self.type = dict["type"] as? String ?? "object"
        
        let propsDict = dict["properties"] as? [String: [String: Any]] ?? [:]
        var properties: [String: OpenAIProperty] = [:]
        
        for (key, value) in propsDict {
            properties[key] = OpenAIProperty(from: value)
        }
        
        self.properties = properties
        self.required = dict["required"] as? [String] ?? []
    }
}

struct OpenAIProperty: Codable {
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

// MARK: - AITool Extension
extension AITool {
    func toOpenAIFormat() -> OpenAIToolFormat {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for (paramName, param) in parameters {
            var paramSchema: [String: Any] = [
                "type": param.type,
                "description": param.description
            ]
            
            if !param.enumValues.isEmpty {
                paramSchema["enum"] = param.enumValues
            }
            
            properties[paramName] = paramSchema
            
            if param.required {
                required.append(paramName)
            }
        }
        
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": required
        ]
        
        return OpenAIToolFormat(name: name, description: description, parameters: schema)
    }
}