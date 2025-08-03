//
//  FlexibleHeader.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

// MARK: - Liquid Glass Flexible Header System

@Observable fileprivate class FlexibleHeaderGeometry {
    var offset: CGFloat = 0
    var windowSize: CGSize = .zero
}

/// A view modifier that implements Liquid Glass flexible header behavior
private struct FlexibleHeaderContentModifier: ViewModifier {
    @Environment(\.flexibleHeaderGeometry) private var geometry
    
    func body(content: Content) -> some View {
        let height = max(200, (geometry.windowSize.height / 2.5) - geometry.offset)
        
        content
            .frame(height: height)
            .clipped()
            .offset(y: min(0, geometry.offset))
            .animation(.easeOut(duration: 0.1), value: geometry.offset)
    }
}

/// A view modifier that tracks scroll geometry for flexible headers
private struct FlexibleHeaderScrollViewModifier: ViewModifier {
    @State private var geometry = FlexibleHeaderGeometry()
    
    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
                min(scrollGeometry.contentOffset.y + scrollGeometry.contentInsets.top, 0)
            } action: { _, offset in
                geometry.offset = offset
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                geometry.windowSize = newSize
            }
            .environment(\.flexibleHeaderGeometry, geometry)
    }
}

// MARK: - Liquid Glass Background Extension Effect

/// A view modifier that creates the Liquid Glass background extension effect
private struct BackgroundExtensionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        .black.opacity(0.3),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .allowsHitTesting(false)
            )
    }
}

// MARK: - Environment Key

fileprivate struct FlexibleHeaderGeometryKey: EnvironmentKey {
    static let defaultValue = FlexibleHeaderGeometry()
}

extension EnvironmentValues {
    fileprivate var flexibleHeaderGeometry: FlexibleHeaderGeometry {
        get { self[FlexibleHeaderGeometryKey.self] }
        set { self[FlexibleHeaderGeometryKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension ScrollView {
    /// Enables flexible header behavior for the scroll view
    func flexibleHeaderScrollView() -> some View {
        modifier(FlexibleHeaderScrollViewModifier())
    }
}

extension View {
    /// Makes the view behave as flexible header content
    func flexibleHeaderContent() -> some View {
        modifier(FlexibleHeaderContentModifier())
    }
    
    /// Adds Liquid Glass background extension effect
    func backgroundExtensionEffect() -> some View {
        modifier(BackgroundExtensionModifier())
    }
}

// MARK: - Liquid Glass Glass Effect Container

/// A container that groups glass effect elements for coordinated animations
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Glass Effect Modifier

private struct GlassEffectModifier: ViewModifier {
    let style: GlassStyle
    let shape: AnyShape
    
    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(style.material)
                    .opacity(style.materialOpacity)
                    .background(
                        shape
                            .stroke(.white.opacity(style.borderOpacity), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Glass Styles

enum GlassStyle {
    case regular
    case clear
    
    var material: Material {
        switch self {
        case .regular:
            return .ultraThinMaterial
        case .clear:
            return .thinMaterial
        }
    }
    
    var materialOpacity: Double {
        switch self {
        case .regular:
            return 1.0
        case .clear:
            return 0.5
        }
    }
    
    var borderOpacity: Double {
        switch self {
        case .regular:
            return 0.2
        case .clear:
            return 0.1
        }
    }
}

extension View {
    /// Applies Liquid Glass effect to the view
    func glassEffect(_ style: GlassStyle = .regular, in shape: some Shape) -> some View {
        modifier(GlassEffectModifier(style: style, shape: AnyShape(shape)))
    }
    
    /// Adds a glass effect ID for animation coordination
    func glassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

// MARK: - Shape Type Erasure

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}