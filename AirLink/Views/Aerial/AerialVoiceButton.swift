import SwiftUI

struct AerialVoiceButton: View {
    @Environment(AirFrameModel.self) private var airFrameModel
    @State private var isListening = false
    @State private var showingFeedback = false
    
    var body: some View {
        Button {
            handleAerialVoiceInteraction()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                
                if isListening {
                    // Listening state with pulsing animation
                    Circle()
                        .stroke(.blue, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(showingFeedback ? 1.2 : 1.0)
                        .opacity(showingFeedback ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showingFeedback)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                } else if airFrameModel.aerial.isSpeaking {
                    // Speaking state
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    // Default state
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .disabled(airFrameModel.aerial.isLoading || airFrameModel.aerial.isProcessingVoice)
        .accessibilityLabel("Talk to Aerial AI")
        .onChange(of: isListening) { _, newValue in
            showingFeedback = newValue
        }
    }
    
    private func handleAerialVoiceInteraction() {
        guard !isListening && !airFrameModel.aerial.isSpeaking else { return }
        
        Task {
            isListening = true
            await airFrameModel.aerial.handleVoiceCommand()
            isListening = false
        }
    }
}

#Preview {
    AerialVoiceButton()
        .environment(AirFrameModel())
}