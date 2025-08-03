//
//  OnboardingView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var currentPage = 0
    @State private var showsGetStartedButton = false
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color.blue.opacity(0.3),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(
                            page: page,
                            geometry: geometry,
                            showsGetStartedButton: showsGetStartedButton && index == pages.count - 1
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                        showsGetStartedButton = newValue == pages.count - 1
                    }
                }
                
                // Custom page indicator
                VStack {
                    Spacer()
                    
                    if !showsGetStartedButton {
                        PageIndicator(currentPage: currentPage, totalPages: pages.count)
                            .padding(.bottom, 50)
                    }
                    
                    if showsGetStartedButton {
                        GetStartedButton {
                            appModel.completeOnboarding()
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 50)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let geometry: GeometryProxy
    let showsGetStartedButton: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
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
            
            Spacer()
                .frame(height: 60)
            
            // Title
            Text(page.title)
                .font(.system(.largeTitle, design: .default, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 24)
            
            // Description
            Text(page.description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? .primary : .secondary)
                    .opacity(index == currentPage ? 1.0 : 0.5)
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }
}

struct GetStartedButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.primary)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: false)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            action()
        }
    }
}

// MARK: - Onboarding Page Data
struct OnboardingPage {
    let iconName: String
    let title: String
    let description: String
    let gradientColors: [Color]
    
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            iconName: "scope",
            title: "Professional Stabilization",
            description: "Experience cinema-quality stabilization with AirFrame's advanced 3-axis gimbal technology. Perfect for capturing smooth, professional footage.",
            gradientColors: [.blue, .cyan]
        ),
        OnboardingPage(
            iconName: "iphone.and.arrow.forward",
            title: "Seamless Connectivity",
            description: "Connect wirelessly to your AirFrame gimbal via Bluetooth. Monitor real-time status and control modes directly from your iPhone.",
            gradientColors: [.purple, .pink]
        ),
        OnboardingPage(
            iconName: "gearshape.2.fill",
            title: "Intelligent Modes",
            description: "Choose from multiple stabilization modes: Lock for stability, Pan Follow for smooth tracking, FPV for dynamic shots, and Person Tracking for automatic subject following.",
            gradientColors: [.orange, .red]
        ),
        OnboardingPage(
            iconName: "sparkles",
            title: "Ready to Create",
            description: "Transform your mobile photography and videography. Let AirFrame handle the stabilization while you focus on capturing the perfect shot.",
            gradientColors: [.green, .mint]
        )
    ]
}

#Preview {
    OnboardingView()
        .environment(AirFrameModel())
}