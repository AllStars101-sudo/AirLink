//
//  AerialOnboardingView.swift
//  AirLink
//
//  Advanced onboarding experience for Aerial AI assistant
//  Created with Apple's latest WWDC25 design guidelines and Liquid Glass effects
//

import SwiftUI

struct AerialOnboardingView: View {
    @Environment(AirFrameModel.self) private var airFrameModel
    @State private var currentPage = 0
    @State private var showsPrivacyAgreement = false
    @State private var hasAgreedToPrivacy = false
    @State private var showsContinueButton = false
    @State private var backgroundGradientOffset: CGFloat = 0
    @State private var iconRotation: Double = 0
    @State private var iconScale: CGFloat = 1.0
    
    private let pages = AerialOnboardingPage.allPages
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic Liquid Glass Background with subtle movement
                liquidGlassBackground
                    .ignoresSafeArea()
                
                if !showsPrivacyAgreement {
                    // Main onboarding content
                    mainOnboardingContent(geometry: geometry)
                } else {
                    // Privacy agreement screen
                    privacyAgreementContent(geometry: geometry)
                }
            }
        }
        .animation(.smooth(duration: 0.8, extraBounce: 0.1), value: showsPrivacyAgreement)
        .animation(.smooth(duration: 0.6), value: currentPage)
        .onAppear {
            startBackgroundAnimation()
            startIconAnimation()
        }
    }
    
    // MARK: - Background
    private var liquidGlassBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.06),
                    Color(.systemBackground)
                ],
                startPoint: UnitPoint(x: 0.2 + backgroundGradientOffset * 0.1, y: 0.1),
                endPoint: UnitPoint(x: 0.8 - backgroundGradientOffset * 0.1, y: 0.9)
            )
            
            // Subtle overlay gradients
            RadialGradient(
                colors: [
                    .blue.opacity(0.03),
                    .purple.opacity(0.02),
                    .clear
                ],
                center: UnitPoint(x: 0.3 + backgroundGradientOffset * 0.1, y: 0.3),
                startRadius: 50,
                endRadius: 300
            )
            .blendMode(.overlay)
            
            RadialGradient(
                colors: [
                    .mint.opacity(0.02),
                    .cyan.opacity(0.03),
                    .clear
                ],
                center: UnitPoint(x: 0.7 - backgroundGradientOffset * 0.1, y: 0.7),
                startRadius: 50,
                endRadius: 300
            )
            .blendMode(.overlay)
        }
    }
    
    // MARK: - Main Onboarding Content
    private func mainOnboardingContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    AerialOnboardingPageView(
                        page: page,
                        geometry: geometry,
                        iconRotation: iconRotation,
                        iconScale: iconScale
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, newValue in
                withAnimation(.smooth(duration: 0.5).delay(0.2)) {
                    showsContinueButton = newValue == pages.count - 1
                }
            }
            
            // Bottom controls
            VStack(spacing: 24) {
                if !showsContinueButton {
                    // Page indicator with Liquid Glass effect
                    LiquidPageIndicator(currentPage: currentPage, totalPages: pages.count)
                } else {
                    // Continue button
                    LiquidContinueButton {
                        withAnimation(.smooth(duration: 0.8, extraBounce: 0.1)) {
                            showsPrivacyAgreement = true
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                        removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom))
                    ))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Privacy Agreement Content
    private func privacyAgreementContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                // Privacy icon with subtle glow
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 0)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation * 0.5))
                
                Text("Privacy & AI")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Before we begin")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Privacy content with Liquid Glass container
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacySection(
                        icon: "apple.intelligence",
                        title: "AI-Powered Assistant",
                        description: "Aerial uses advanced AI to help you control your AirFrame gimbal and analyze scenes for perfect shots."
                    )
                    
                    privacySection(
                        icon: "cloud",
                        title: "Technology Partners",
                        description: "Your conversations may be processed by Aither's technology partners, including Anthropic (Claude) and Google (Gemini), to provide intelligent responses."
                    )
                    
                    privacySection(
                        icon: "lock.shield",
                        title: "Data Protection",
                        description: "We prioritize your privacy. Conversations are processed securely and are not stored permanently on our servers."
                    )
                    
                    privacySection(
                        icon: "gear",
                        title: "Device Control",
                        description: "Aerial can control your AirFrame gimbal settings, modes, and calibration to provide seamless integration."
                    )
                }
                .padding(24)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            
            Spacer()
            
            // Agreement controls
            VStack(spacing: 16) {
                // Privacy toggle with smooth animation
                HStack {
                    Toggle("I agree to the privacy terms above", isOn: $hasAgreedToPrivacy)
                        .toggleStyle(LiquidGlassToggleStyle())
                        .animation(.smooth(duration: 0.4, extraBounce: 0.2), value: hasAgreedToPrivacy)
                }
                .padding(.horizontal, 32)
                
                // Action buttons
                HStack(spacing: 16) {
                    // Not now button
                    Button {
                        withAnimation(.smooth(duration: 0.6)) {
                            showsPrivacyAgreement = false
                        }
                    } label: {
                        Text("Not Now")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(hasAgreedToPrivacy)
                    .opacity(hasAgreedToPrivacy ? 0.5 : 1.0)
                    
                    // Agree and continue button
                    Button {
                        completeOnboarding()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Agree and Continue")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            hasAgreedToPrivacy
                            ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!hasAgreedToPrivacy)
                    .scaleEffect(hasAgreedToPrivacy ? 1.0 : 0.95)
                    .animation(.smooth(duration: 0.4, extraBounce: 0.2), value: hasAgreedToPrivacy)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 50)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Privacy Section
    private func privacySection(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Actions
    private func completeOnboarding() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Complete onboarding with animation
        withAnimation(.smooth(duration: 1.0, extraBounce: 0.1)) {
            airFrameModel.completeAerialOnboarding()
        }
    }
    
    // MARK: - Animations
    private func startBackgroundAnimation() {
        withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
            backgroundGradientOffset = 1.0
        }
    }
    
    private func startIconAnimation() {
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            iconRotation = 360
        }
        
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            iconScale = 1.1
        }
    }
}

// MARK: - Liquid Glass Components
private struct LiquidPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == currentPage ? .primary : .secondary)
                    .opacity(index == currentPage ? 1.0 : 0.4)
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.smooth(duration: 0.4, extraBounce: 0.2), value: currentPage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct LiquidContinueButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            withAnimation(.smooth(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.smooth(duration: 0.2)) {
                    isPressed = false
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                action()
            }
        }
    }
}

private struct LiquidGlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? .blue : .secondary.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay {
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.smooth(duration: 0.3, extraBounce: 0.2), value: configuration.isOn)
                }
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

// MARK: - Onboarding Page View
private struct AerialOnboardingPageView: View {
    let page: AerialOnboardingPage
    let geometry: GeometryProxy
    let iconRotation: Double
    let iconScale: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated icon with Liquid Glass effect
            Image(systemName: page.iconName)
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation * page.rotationMultiplier))
                .shadow(color: page.gradientColors.first?.opacity(0.3) ?? .clear, radius: 15, x: 0, y: 0)
            
            Spacer()
                .frame(height: 60)
            
            // Title with enhanced typography
            Text(page.title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 24)
            
            // Description with improved readability
            Text(page.description)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Onboarding Page Data
private struct AerialOnboardingPage {
    let iconName: String
    let title: String
    let description: String
    let gradientColors: [Color]
    let rotationMultiplier: Double
    
    static let allPages: [AerialOnboardingPage] = [
        AerialOnboardingPage(
            iconName: "apple.intelligence",
            title: "Meet Aerial",
            description: "Your intelligent AI assistant for AirFrame. Get personalized help, real-time analysis, and seamless gimbal control through natural conversation.",
            gradientColors: [.blue, .cyan],
            rotationMultiplier: 0.1
        ),
        AerialOnboardingPage(
            iconName: "message.badge.waveform",
            title: "Voice & Text Control",
            description: "Speak naturally or type your commands. Aerial understands context and provides intelligent responses to help you capture the perfect shot.",
            gradientColors: [.purple, .pink],
            rotationMultiplier: 0.2
        ),
        AerialOnboardingPage(
            iconName: "camera.aperture",
            title: "Scene Analysis",
            description: "Advanced AI vision analyzes your shots and suggests optimal gimbal positioning, framing, and settings for professional results.",
            gradientColors: [.orange, .red],
            rotationMultiplier: 0.15
        ),
        AerialOnboardingPage(
            iconName: "sparkles",
            title: "Intelligent Automation",
            description: "From calibration to complex maneuvers, Aerial handles the technical details so you can focus on creativity and storytelling.",
            gradientColors: [.green, .mint],
            rotationMultiplier: 0.3
        )
    ]
}

#Preview {
    AerialOnboardingView()
        .environment(AirFrameModel())
}