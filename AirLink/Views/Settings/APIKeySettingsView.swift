import SwiftUI

struct APIKeySettingsView: View {
    @State private var claudeAPIKey = ""
    @State private var geminiAPIKey = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Configure your AI API keys for full functionality.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } header: {
                    Text("AI Configuration")
                }
                
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.blue)
                        Text("Status")
                        Spacer()
                        Text(APIKeyManager.shared.isFullyConfigured ? "Full AI Mode" : "Demo Mode")
                            .foregroundStyle(APIKeyManager.shared.isFullyConfigured ? .green : .orange)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Current Status")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundStyle(.blue)
                            Text("Claude API Key")
                            Spacer()
                            if APIKeyManager.shared.hasValidClaudeKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        SecureField("sk-ant-api03-...", text: $claudeAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundStyle(.orange)
                            Text("Gemini API Key")
                            Spacer()
                            if APIKeyManager.shared.hasValidGeminiKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        SecureField("AIza...", text: $geminiAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("These keys are stored locally on your device. For production use, consider using Xcode environment variables or Keychain storage.")
                        .font(.caption)
                }
                
                Section {
                    Button("Save API Keys") {
                        saveAPIKeys()
                    }
                    .disabled(claudeAPIKey.isEmpty && geminiAPIKey.isEmpty)
                    
                    Button("Clear All Keys", role: .destructive) {
                        clearAPIKeys()
                    }
                } header: {
                    Text("Actions")
                }
                
                Section {
                    Link("Get Claude API Key", destination: URL(string: "https://console.anthropic.com")!)
                    Link("Get Gemini API Key", destination: URL(string: "https://makersuite.google.com")!)
                    Link("Setup Guide", destination: URL(string: "https://docs.anthropic.com/en/api/getting-started")!)
                } header: {
                    Text("Resources")
                }
            }
            .navigationTitle("AI Settings")
            .onAppear {
                loadCurrentKeys()
            }
            .alert("API Keys", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentKeys() {
        // Don't show the actual keys for security, just show if they exist
        claudeAPIKey = APIKeyManager.shared.hasValidClaudeKey ? "••••••••••••••••" : ""
        geminiAPIKey = APIKeyManager.shared.hasValidGeminiKey ? "••••••••••••••••" : ""
    }
    
    private func saveAPIKeys() {
        var saved = false
        
        if !claudeAPIKey.isEmpty && claudeAPIKey != "••••••••••••••••" {
            APIKeyManager.shared.setClaudeAPIKey(claudeAPIKey)
            saved = true
        }
        
        if !geminiAPIKey.isEmpty && geminiAPIKey != "••••••••••••••••" {
            APIKeyManager.shared.setGeminiAPIKey(geminiAPIKey)
            saved = true
        }
        
        if saved {
            alertMessage = "API keys saved successfully! Restart the app to use Full AI Mode."
            showingAlert = true
            
            // Clear the text fields
            claudeAPIKey = ""
            geminiAPIKey = ""
            
            // Reload to show status
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadCurrentKeys()
            }
        }
    }
    
    private func clearAPIKeys() {
        APIKeyManager.shared.clearAllKeys()
        claudeAPIKey = ""
        geminiAPIKey = ""
        alertMessage = "All API keys cleared. The app will now run in Demo Mode."
        showingAlert = true
    }
}

#Preview {
    APIKeySettingsView()
}