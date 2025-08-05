import Foundation

class APIKeyManager {
    static let shared = APIKeyManager()
    
    private init() {}
    
    // MARK: - API Key Retrieval
    
    var claudeAPIKey: String {
        // Try multiple sources in order of preference
        
        // 1. Environment variables (works when running from Xcode)
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            print("🔑 Claude API key loaded from environment variables")
            return envKey
        }
        
        // 2. UserDefaults (for development - not secure for production)
        if let userDefaultsKey = UserDefaults.standard.string(forKey: "ANTHROPIC_API_KEY"), !userDefaultsKey.isEmpty {
            print("🔑 Claude API key loaded from UserDefaults")
            return userDefaultsKey
        }
        
        // 3. Config file (if exists)
        if let configKey = loadFromConfigFile(key: "ANTHROPIC_API_KEY"), !configKey.isEmpty {
            print("🔑 Claude API key loaded from config file")
            return configKey
        }
        
        print("🚨 No Claude API key found")
        return ""
    }
    
    var geminiAPIKey: String {
        // Try multiple sources in order of preference
        
        // 1. Environment variables
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            print("🔑 Gemini API key loaded from environment variables")
            return envKey
        }
        
        // 2. UserDefaults
        if let userDefaultsKey = UserDefaults.standard.string(forKey: "GEMINI_API_KEY"), !userDefaultsKey.isEmpty {
            print("🔑 Gemini API key loaded from UserDefaults")
            return userDefaultsKey
        }
        
        // 3. Config file
        if let configKey = loadFromConfigFile(key: "GEMINI_API_KEY"), !configKey.isEmpty {
            print("🔑 Gemini API key loaded from config file")
            return configKey
        }
        
        print("🚨 No Gemini API key found")
        return ""
    }
    
    // MARK: - Development Helpers
    
    func setClaudeAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "ANTHROPIC_API_KEY")
        print("🔑 Claude API key saved to UserDefaults")
    }
    
    func setGeminiAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "GEMINI_API_KEY")
        print("🔑 Gemini API key saved to UserDefaults")
    }
    
    func clearAllKeys() {
        UserDefaults.standard.removeObject(forKey: "ANTHROPIC_API_KEY")
        UserDefaults.standard.removeObject(forKey: "GEMINI_API_KEY")
        print("🔑 All API keys cleared from UserDefaults")
    }
    
    // MARK: - Private Helpers
    
    private func loadFromConfigFile(key: String) -> String? {
        // Look for a config.plist file in the bundle
        guard let path = Bundle.main.path(forResource: "APIConfig", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let value = plist[key] as? String else {
            return nil
        }
        return value
    }
    
    // MARK: - Status Helpers
    
    var hasValidClaudeKey: Bool {
        !claudeAPIKey.isEmpty
    }
    
    var hasValidGeminiKey: Bool {
        !geminiAPIKey.isEmpty
    }
    
    var isFullyConfigured: Bool {
        hasValidClaudeKey && hasValidGeminiKey
    }
    
    func printStatus() {
        print("🔑 API Key Status:")
        print("  Claude: \(hasValidClaudeKey ? "✅ SET" : "❌ MISSING")")
        print("  Gemini: \(hasValidGeminiKey ? "✅ SET" : "❌ MISSING")")
        print("  Mode: \(isFullyConfigured ? "🤖 Full AI" : "📝 Demo")")
    }
}