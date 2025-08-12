import Foundation
import SwiftUI
import Speech
import AVFoundation

@MainActor
@Observable
class AerialAIService {
    // MARK: - AI State
    var messages: [ChatMessage] = [] // Legacy property for backward compatibility
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Conversation Management
    let conversationHistory = ConversationHistoryManager()
    
    // MARK: - Voice State
    var isListening = false
    var isProcessingVoice = false
    var currentTranscription = ""
    var isSpeaking = false
    
    // MARK: - Services
    private let claudeService: ClaudeService
    private let openAIService: OpenAIService
    private let geminiService = GeminiService()
    private let voiceService = VoiceService()
    let airFrameService = AirFrameToolService()
    
    // MARK: - AI Provider Selection
    private var preferredProvider: AIProvider {
        // Prefer OpenAI's new model if available, fallback to Claude
        if APIKeyManager.shared.hasValidOpenAIKey {
            return .openAI
        } else if APIKeyManager.shared.hasValidClaudeKey {
            return .claude
        } else {
            return .demo
        }
    }
    
    private enum AIProvider {
        case openAI
        case claude
        case demo
    }
    
    // MARK: - Dependencies
    private weak var airFrameModel: AirFrameModel?
    
    init(airFrameModel: AirFrameModel) {
        self.airFrameModel = airFrameModel
        self.airFrameService.airFrameModel = airFrameModel
        self.claudeService = ClaudeService(toolService: airFrameService)
        self.openAIService = OpenAIService(toolService: airFrameService)
        
        // Check if API keys are available
        let hasAnyAIKey = APIKeyManager.shared.hasAnyAIKey
        let provider = preferredProvider
        let mode = hasAnyAIKey ? "Full AI Mode" : "Demo Mode"
        let providerName = provider == .openAI ? "OpenAI GPT-OSS-120B" : provider == .claude ? "Claude 4 Sonnet" : "Demo"
        
        // Initialize with welcome message if no conversations exist
        if conversationHistory.conversations.isEmpty || 
           conversationHistory.currentConversation?.messages.isEmpty == true {
            let welcomeMessage = ChatMessage(
                id: UUID(),
                content: """
                Hello! I'm Aerial, your AI assistant for the AirFrame. 
                
                **Current Status: \(mode)** (\(providerName))
                
                I can help you control your gimbal, analyze scenes for perfect shots, and much more. How can I assist you today?
                
                \(hasAnyAIKey ? "🤖 Full AI functionality enabled!" : "📝 Running in demo mode - add your API keys for full functionality.")
                """,
                isUser: false,
                timestamp: Date()
            )
            
            conversationHistory.addMessageToCurrentConversation(welcomeMessage)
        }
        
        // Sync messages with current conversation for backward compatibility
        updateLegacyMessages()
    }
    
    // MARK: - Chat Methods
    func sendMessage(_ content: String) async {
        let userMessage = ChatMessage(
            id: UUID(),
            content: content,
            isUser: true,
            timestamp: Date()
        )
        
        // Add to conversation history
        conversationHistory.addMessageToCurrentConversation(userMessage)
        updateLegacyMessages()
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response: String
            let conversationMessages = conversationHistory.currentConversation?.messages ?? []
            
            switch preferredProvider {
            case .openAI:
                response = try await openAIService.sendMessage(
                    content,
                    tools: airFrameService.availableTools(),
                    conversationHistory: conversationMessages
                )
            case .claude:
                response = try await claudeService.sendMessage(
                    content,
                    tools: airFrameService.availableTools(),
                    conversationHistory: conversationMessages
                )
            case .demo:
                throw AIError.missingAPIKey
            }
            
            let aiMessage = ChatMessage(
                id: UUID(),
                content: response,
                isUser: false,
                timestamp: Date()
            )
            
            // Add AI response to conversation history
            conversationHistory.addMessageToCurrentConversation(aiMessage)
            updateLegacyMessages()
        } catch AIError.missingAPIKey {
            // Demo mode - provide helpful responses without API
            let demoResponse = generateDemoResponse(for: content)
            let aiMessage = ChatMessage(
                id: UUID(),
                content: demoResponse,
                isUser: false,
                timestamp: Date()
            )
            
            conversationHistory.addMessageToCurrentConversation(aiMessage)
            updateLegacyMessages()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Voice Methods
    func startListening() async {
        guard !isListening else { return }
        
        do {
            isListening = true
            currentTranscription = ""
            
            let transcription = try await voiceService.startListening()
            currentTranscription = transcription
            
            if !transcription.isEmpty {
                await sendMessage(transcription)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isListening = false
    }
    
    func stopListening() {
        voiceService.stopListening()
        isListening = false
    }
    
    func speakResponse(_ text: String) async {
        guard !isSpeaking else { return }
        
        isSpeaking = true
        await voiceService.speak(text)
        isSpeaking = false
    }
    
    // MARK: - Scene Analysis
    func analyzeSceneForBestShot(image: UIImage) async -> String {
        do {
            let analysis = try await geminiService.analyzeScene(image: image)
            
            // Add analysis result as a message
            let analysisMessage = ChatMessage(
                id: UUID(),
                content: "📸 **Scene Analysis Complete**\n\n\(analysis)",
                isUser: false,
                timestamp: Date()
            )
            messages.append(analysisMessage)
            
            return analysis
        } catch {
            let errorMessage = "I'm having trouble analyzing the scene right now. Please try again."
            let analysisMessage = ChatMessage(
                id: UUID(),
                content: errorMessage,
                isUser: false,
                timestamp: Date()
            )
            messages.append(analysisMessage)
            return errorMessage
        }
    }
    
    func analyzeCurrentCameraView() async {
        // This would need to be implemented with camera access
        // For now, return a placeholder message
        let message = ChatMessage(
            id: UUID(),
            content: "I'd love to analyze the current camera view! To do this, I'll need access to the camera feed. This feature will be available when you're in the Camera tab with an active preview.",
            isUser: false,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    // MARK: - Voice-Only Mode (for Camera View)
    func handleVoiceCommand() async {
        await startListening()
        
        // After processing the voice command, speak the response
        if let lastMessage = messages.last, !lastMessage.isUser {
            await speakResponse(lastMessage.content)
        }
    }
    
    // MARK: - Demo Mode
    private func generateDemoResponse(for input: String) -> String {
        let lowercaseInput = input.lowercased()
        
        if lowercaseInput.contains("status") || lowercaseInput.contains("gimbal") {
            return """
            🎯 **AirFrame Status** (Demo Mode)
            
            • Connection: Connected
            • Mode: Locked
            • Pitch: 0.0°
            • Roll: 0.0°
            • Yaw: 0.0°
            
            Everything looks good! Your AirFrame is ready for action. 
            
            *Note: This is demo mode. Add your Anthropic API key in Xcode environment variables for full AI functionality.*
            """
        } else if lowercaseInput.contains("calibrate") {
            return """
            🎯 **Calibration Started** (Demo Mode)
            
            I've initiated gimbal calibration. Please keep your AirFrame steady during this process.
            
            The calibration will:
            • Reset sensor offsets
            • Level the gimbal
            • Optimize PID settings
            
            *Note: Add your API key for real gimbal control.*
            """
        } else if lowercaseInput.contains("mode") || lowercaseInput.contains("locked") || lowercaseInput.contains("tracking") {
            return """
            🎯 **Mode Change** (Demo Mode)
            
            I understand you want to change the gimbal mode. In full mode, I can:
            
            • Switch between Locked, Pan Follow, FPV modes
            • Enable Person Tracking
            • Optimize settings for different scenarios
            
            *Add your Anthropic API key to enable real gimbal control.*
            """
        } else if lowercaseInput.contains("photo") || lowercaseInput.contains("picture") || lowercaseInput.contains("shot") {
            return """
            📸 **Perfect Shot Analysis** (Demo Mode)
            
            For the best shot, I recommend:
            
            • Setting gimbal to Locked mode for stability
            • Positioning at eye level for natural perspective
            • Using rule of thirds for composition
            
            With your API keys configured, I can analyze the live camera feed and provide real-time positioning suggestions!
            
            *Configure both Anthropic and Gemini API keys for full scene analysis.*
            """
        } else {
            return """
            👋 **Hello!** (Demo Mode)
            
            I'm Aerial, your AirFrame AI assistant. I can help you:
            
            • Control gimbal modes and settings
            • Analyze scenes for perfect shots
            • Provide real-time status updates
            • Troubleshoot issues
            
            **To unlock full functionality:**
            1. Get API keys from Anthropic (Claude) and Google (Gemini)
            2. Add them to your Xcode environment variables
            3. See AI_SETUP.md for detailed instructions
            
            Try asking me about gimbal status, calibration, or photo tips!
            """
        }
    }
    
    // MARK: - Conversation Management
    
    func createNewConversation() {
        let newConversation = conversationHistory.createNewConversation()
        updateLegacyMessages()
        
        // Add welcome message to new conversation
        let hasAnyAIKey = APIKeyManager.shared.hasAnyAIKey
        let provider = preferredProvider
        let mode = hasAnyAIKey ? "Full AI Mode" : "Demo Mode"
        let providerName = provider == .openAI ? "OpenAI GPT-OSS-120B" : provider == .claude ? "Claude 4 Sonnet" : "Demo"
        
        let welcomeMessage = ChatMessage(
            id: UUID(),
            content: """
            Hello! I'm Aerial, your AI assistant for the AirFrame. 
            
            **Current Status: \(mode)** (\(providerName))
            
            I can help you control your gimbal, analyze scenes for perfect shots, and much more. How can I assist you today?
            
            \(hasAnyAIKey ? "🤖 Full AI functionality enabled!" : "📝 Running in demo mode - add your API keys for full functionality.")
            """,
            isUser: false,
            timestamp: Date()
        )
        
        conversationHistory.addMessageToCurrentConversation(welcomeMessage)
        updateLegacyMessages()
    }
    
    func switchToConversation(_ conversation: Conversation) {
        conversationHistory.switchToConversation(conversation)
        updateLegacyMessages()
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversationHistory.deleteConversation(conversation)
        updateLegacyMessages()
    }
    
    func renameCurrentConversation(to title: String) {
        guard let current = conversationHistory.currentConversation else { return }
        conversationHistory.renameConversation(current, to: title)
    }
    
    // MARK: - Private Helpers
    
    private func updateLegacyMessages() {
        // Keep the legacy messages property in sync for backward compatibility
        messages = conversationHistory.currentConversation?.messages ?? []
    }
}

// MARK: - Supporting Types
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
