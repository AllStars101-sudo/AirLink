import SwiftUI

struct AerialView: View {
    @Environment(AirFrameModel.self) private var airFrameModel
    @State private var messageText = ""
    @State private var isKeyboardVisible = false
    @State private var showingAboutAerial = false
    @State private var animationPhase: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
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
            ZStack {
                // Animated Background
                AnimatedBackgroundView(animationPhase: $animationPhase)
                    .ignoresSafeArea()
                
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
                    .background(.clear)
                    .onChange(of: airFrameModel.aerial.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(airFrameModel.aerial.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                    // Input Area - iMessage Style with Liquid Glass
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Voice Input Button - iMessage Style
                            Button {
                                Task {
                                    if airFrameModel.aerial.isListening {
                                        airFrameModel.aerial.stopListening()
                                    } else {
                                        await airFrameModel.aerial.startListening()
                                    }
                                }
                            } label: {
                                Image(systemName: airFrameModel.aerial.isListening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(airFrameModel.aerial.isListening ? .white : .white)
                            }
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(airFrameModel.aerial.isListening ? .red : .blue)
                                    .shadow(color: airFrameModel.aerial.isListening ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                            .scaleEffect(airFrameModel.aerial.isListening ? 1.1 : 1.0)
                            .animation(.spring(duration: 0.3), value: airFrameModel.aerial.isListening)
                            .disabled(airFrameModel.aerial.isProcessingVoice)
                            .accessibilityLabel(airFrameModel.aerial.isListening ? "Stop listening" : "Start voice input")
                            
                            // Text Input - Floating Style
                            HStack(spacing: 8) {
                                TextField("Ask Aerial anything...", text: $messageText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .lineLimit(1...4)
                                    .font(.system(size: 16))
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        sendMessage()
                                        dismissKeyboard()
                                    }
                                
                                if !messageText.isEmpty {
                                    Button {
                                        sendMessage()
                                        dismissKeyboard()
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(.blue)
                                            .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
                                    )
                                    .disabled(airFrameModel.aerial.isLoading)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            }
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
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
                        showingAboutAerial = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .help("About Aerial")
                }
            }
        }
        .animation(.easeInOut, value: airFrameModel.aerial.isListening)
        .animation(.easeInOut, value: airFrameModel.aerial.currentTranscription)
        .onAppear {
            startBackgroundAnimation()
        }
        .onTapGesture {
            dismissKeyboard()
        }
        .sheet(isPresented: $showingAboutAerial) {
            AboutAerialView()
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await airFrameModel.aerial.sendMessage(message)
        }
    }
    
    // Background animation function
    private func startBackgroundAnimation() {
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            animationPhase = 2 * .pi
        }
    }
    
    // Keyboard dismissal function
    private func dismissKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

// MARK: - Animated Background
private struct AnimatedBackgroundView: View {
    @Binding var animationPhase: CGFloat
    
    var body: some View {
        // Clean gradient background with more visible animation
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.12),
                Color.purple.opacity(0.08),
                Color(.systemBackground)
            ],
            startPoint: UnitPoint(
                x: 0.5 + 0.3 * cos(animationPhase * 0.3),
                y: 0.5 + 0.3 * sin(animationPhase * 0.2)
            ),
            endPoint: UnitPoint(
                x: 0.5 - 0.3 * cos(animationPhase * 0.3),
                y: 0.5 - 0.3 * sin(animationPhase * 0.2)
            )
        )
    }
}

// MARK: - About Aerial View
private struct AboutAerialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Aerial")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("Your AI Assistant")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(spacing: 16) {
                        Text("Intelligent AirFrame Control")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("Aerial is your intelligent AI assistant for the AirFrame gimbal system. Using advanced natural language processing and computer vision, Aerial understands your creative needs and helps you achieve the perfect shot.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Capabilities")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        AerialFeatureRow(
                            iconName: "mic.fill",
                            title: "Voice Commands",
                            description: "Natural language control of your gimbal"
                        )
                        
                        AerialFeatureRow(
                            iconName: "camera.viewfinder",
                            title: "Scene Analysis",
                            description: "AI-powered scene understanding and tracking"
                        )
                        
                        AerialFeatureRow(
                            iconName: "brain.head.profile",
                            title: "Smart Suggestions",
                            description: "Intelligent recommendations for better shots"
                        )
                        
                        AerialFeatureRow(
                            iconName: "waveform.path.ecg",
                            title: "Adaptive Learning",
                            description: "Learns your preferences and shooting style"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color.blue.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
    }
}

private struct AerialFeatureRow: View {
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
        }
    }
}

#Preview {
    AerialView()
        .environment(AirFrameModel())
}
