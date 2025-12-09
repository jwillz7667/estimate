
//
//  GlassmorphicComponents.swift
//  ProjectEstimate
//
//  Modern glassmorphic UI components with blur effects and translucency
//  Implements fluid micro-animations and smooth transitions
//

import SwiftUI

// MARK: - Glassmorphic Card

/// Translucent card with frosted glass effect
struct GlassmorphicCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme

    let cornerRadius: CGFloat
    let blur: CGFloat
    let opacity: Double
    let content: () -> Content

    init(
        cornerRadius: CGFloat = 24,
        blur: CGFloat = 20,
        opacity: Double = 0.7,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.blur = blur
        self.opacity = opacity
        self.content = content
    }

    var body: some View {
        content()
            .background(
                ZStack {
                    // Blur background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
    }
}

// MARK: - Glassmorphic Button

struct GlassmorphicButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolEffect(.bounce, value: isPressed)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.15), radius: isPressed ? 5 : 15, y: isPressed ? 2 : 8)
        }
        .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation { isPressed = false }
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    let colors: [Color]

    init(colors: [Color] = [.blue, .purple, .pink]) {
        self.colors = colors
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Floating Orbs Background

struct FloatingOrbsBackground: View {
    @State private var positions: [(CGFloat, CGFloat)] = []

    let orbCount: Int
    let colors: [Color]

    init(orbCount: Int = 5, colors: [Color] = [.blue, .purple, .pink, .orange]) {
        self.orbCount = orbCount
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<orbCount, id: \.self) { index in
                    OrbView(
                        color: colors[index % colors.count],
                        size: CGFloat.random(in: 100...250),
                        geometry: geo
                    )
                }
            }
        }
        .blur(radius: 60)
        .ignoresSafeArea()
    }
}

struct OrbView: View {
    let color: Color
    let size: CGFloat
    let geometry: GeometryProxy

    @State private var position: CGPoint = .zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.8), color.opacity(0.2)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(position)
            .scaleEffect(scale)
            .onAppear {
                position = CGPoint(
                    x: CGFloat.random(in: 0...geometry.size.width),
                    y: CGFloat.random(in: 0...geometry.size.height)
                )
                animateOrb()
            }
    }

    private func animateOrb() {
        let duration = Double.random(in: 8...15)

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            position = CGPoint(
                x: CGFloat.random(in: size/2...(geometry.size.width - size/2)),
                y: CGFloat.random(in: size/2...(geometry.size.height - size/2))
            )
            scale = CGFloat.random(in: 0.8...1.2)
        }
    }
}

// MARK: - Micro Animation Modifiers

extension View {
    /// Adds a subtle bounce animation on appear
    func bounceOnAppear(delay: Double = 0) -> some View {
        modifier(BounceOnAppearModifier(delay: delay))
    }

    /// Adds a smooth fade and slide animation on appear
    func fadeSlideIn(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        modifier(FadeSlideInModifier(edge: edge, delay: delay))
    }

    /// Adds a scale animation on appear
    func scaleOnAppear(delay: Double = 0) -> some View {
        modifier(ScaleOnAppearModifier(delay: delay))
    }

    /// Adds a continuous floating animation
    func floating(amount: CGFloat = 5, duration: Double = 2) -> some View {
        modifier(FloatingModifier(amount: amount, duration: duration))
    }

    /// Adds a shimmer effect
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Adds a pulse animation
    func pulse(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05) -> some View {
        modifier(PulseModifier(minScale: minScale, maxScale: maxScale))
    }
}

// MARK: - Animation Modifiers

struct BounceOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

struct FadeSlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double

    @State private var offset: CGFloat = 30
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(
                x: edge == .leading ? -offset : (edge == .trailing ? offset : 0),
                y: edge == .top ? -offset : (edge == .bottom ? offset : 0)
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    offset = 0
                    opacity = 1.0
                }
            }
    }
}

struct ScaleOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

struct FloatingModifier: ViewModifier {
    let amount: CGFloat
    let duration: Double
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amount : amount)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            )
            .mask(content)
    }
}

struct PulseModifier: ViewModifier {
    let minScale: CGFloat
    let maxScale: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Spring Transition

extension AnyTransition {
    static var springScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }

    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    static var slideFromLeading: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(isActive: true),
            identity: BlurModifier(isActive: false)
        )
    }
}

struct BlurModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? 10 : 0)
            .opacity(isActive ? 0 : 1)
    }
}

// MARK: - Interactive Spring Animation

struct InteractiveSpring {
    static func standard() -> Animation {
        .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    }

    static func bouncy() -> Animation {
        .spring(response: 0.35, dampingFraction: 0.5, blendDuration: 0)
    }

    static func smooth() -> Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }

    static func snappy() -> Animation {
        .spring(response: 0.25, dampingFraction: 0.65, blendDuration: 0)
    }
}

// MARK: - Preview

#Preview("Glassmorphic Components") {
    ZStack {
        FloatingOrbsBackground()

        VStack(spacing: 24) {
            GlassmorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glassmorphic Card")
                        .font(.headline)
                    Text("This card has a frosted glass effect with blur and translucency.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .fadeSlideIn(delay: 0.1)

            GlassmorphicButton(title: "Get Started", icon: "arrow.right") {}
                .bounceOnAppear(delay: 0.2)

            HStack(spacing: 16) {
                Circle()
                    .fill(.blue)
                    .frame(width: 60, height: 60)
                    .floating()

                Circle()
                    .fill(.purple)
                    .frame(width: 60, height: 60)
                    .pulse()

                Circle()
                    .fill(.orange)
                    .frame(width: 60, height: 60)
                    .scaleOnAppear(delay: 0.3)
            }
        }
        .padding()
    }
}
