import SwiftUI

struct AerialView: View {
    @Environment(AirFrameModel.self) private var airFrameModel
    @State private var messageText = ""
    @State private var isKeyboardVisible = false
    
    var body: some View {
        ZStack {
            if !airFrameModel.hasCompletedAerialOnboarding {
                AerialOnboardingView()
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            } else {
                aerialChatView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .identity
                    ))
            }
        }
        .animation(.smooth(duration: 1.0, extraBounce: 0.1), value: airFrameModel.hasCompletedAerialOnboarding)
        .onAppear {
            print("🔍 AerialView Debug:")
            print("  hasCompletedAerialOnboarding: \(airFrameModel.hasCompletedAerialOnboarding)")
            print("  Should show onboarding: \(!airFrameModel.hasCompletedAerialOnboarding)")
        }
    }
    
    private var aerialChatView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(airFrameModel.aerial.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if airFrameModel.aerial.isLoading {
                                LoadingBubbleView()
                            }
                            
                            if let error = airFrameModel.aerial.errorMessage {
                                ErrorBubbleView(error: error)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: airFrameModel.aerial.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(airFrameModel.aerial.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Input Area
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Voice Input Button
                        Button {
                            Task {
                                if airFrameModel.aerial.isListening {
                                    airFrameModel.aerial.stopListening()
                                } else {
                                    await airFrameModel.aerial.startListening()
                                }
                            }
                        } label: {
                            Image(systemName: airFrameModel.aerial.isListening ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                                .foregroundStyle(airFrameModel.aerial.isListening ? .red : .blue)
                        }
                        .disabled(airFrameModel.aerial.isProcessingVoice)
                        .accessibilityLabel(airFrameModel.aerial.isListening ? "Stop listening" : "Start voice input")
                        
                        // Text Input
                        HStack {
                            TextField("Ask Aerial anything about your AirFrame...", text: $messageText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...4)
                                .onSubmit {
                                    sendMessage()
                                }
                            
                            if !messageText.isEmpty {
                                Button {
                                    sendMessage()
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                                .disabled(airFrameModel.aerial.isLoading)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                    }
                    
                    // Voice Transcription Display
                    if airFrameModel.aerial.isListening && !airFrameModel.aerial.currentTranscription.isEmpty {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundStyle(.blue)
                            Text(airFrameModel.aerial.currentTranscription)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .slide))
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Aerial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        airFrameModel.resetAerialOnboarding()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reset Aerial Onboarding")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Show help or settings
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
        .animation(.easeInOut, value: airFrameModel.aerial.isListening)
        .animation(.easeInOut, value: airFrameModel.aerial.currentTranscription)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await airFrameModel.aerial.sendMessage(message)
        }
    }
}

// MARK: - Chat Bubble Views
private struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "apple.intelligence")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(6)
                            .background(.blue.opacity(0.1), in: Circle())
                        
                        Text(message.content)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    
                    HStack {
                        Text("Aerial")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text("• \(message.timestamp, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 42)
                }
                Spacer()
            }
        }
    }
}

private struct LoadingBubbleView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "apple.intelligence")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(6)
                    .background(.blue.opacity(0.1), in: Circle())
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.secondary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animationPhase == Double(index) ? 1.2 : 0.8)
                            .opacity(animationPhase == Double(index) ? 1.0 : 0.5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: false)) {
                animationPhase = 2.0
            }
        }
    }
}

private struct ErrorBubbleView: View {
    let error: String
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(.red.opacity(0.1), in: Circle())
                
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer()
        }
    }
}

#Preview {
    AerialView()
        .environment(AirFrameModel())
}