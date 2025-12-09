//
//  NeumorphicComponents.swift
//  ProjectEstimate
//
//  Custom neumorphic UI components with modern design aesthetic
//  Supports dark/light mode with appropriate shadow adjustments
//

import SwiftUI

// MARK: - Neumorphic Button Style

/// Soft, embossed button style with depth effect
struct NeumorphicButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    var cornerRadius: CGFloat = 16
    var isPressed: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Group {
                    if configuration.isPressed || isPressed {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(innerShadowColor, lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: 2, y: 2)
                                    .mask(RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(
                                        colors: [.black, .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(highlightColor, lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: -2, y: -2)
                                    .mask(RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(
                                        colors: [.clear, .black],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                            .shadow(color: shadowColor, radius: 10, x: 5, y: 5)
                            .shadow(color: highlightColor, radius: 10, x: -5, y: -5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.15)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.8)
    }

    private var innerShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
}

// MARK: - Neumorphic Card

/// Card with soft shadow depth effect
struct NeumorphicCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme

    let cornerRadius: CGFloat
    let content: () -> Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(color: shadowColor, radius: 10, x: 5, y: 5)
                    .shadow(color: highlightColor, radius: 10, x: -5, y: -5)
            )
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.12)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.9)
    }
}

// MARK: - Neumorphic Text Field

/// Text field with inset neumorphic styling
struct NeumorphicTextField: View {
    @Environment(\.colorScheme) var colorScheme

    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String?

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(innerShadowColor, lineWidth: 2)
                        .blur(radius: 2)
                        .offset(x: 1, y: 1)
                        .mask(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlightColor, lineWidth: 2)
                        .blur(radius: 2)
                        .offset(x: -1, y: -1)
                        .mask(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )))
                )
        )
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }

    private var innerShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.08)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.7)
    }
}

// MARK: - Gradient Button

/// Modern gradient button with animation
struct GradientButton: View {
    let title: String
    let icon: String?
    let colors: [Color]
    let action: () -> Void

    @State private var isPressed = false

    init(
        title: String,
        icon: String? = nil,
        colors: [Color] = [.blue, .purple],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.colors = colors
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: colors.first?.opacity(0.4) ?? .blue.opacity(0.4), radius: 8, y: 4)
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Animated Loading Indicator

/// Custom loading indicator with smooth animation
struct LoadingIndicator: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat

    init(color: Color = .blue, size: CGFloat = 40) {
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: size * 0.1)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Progress Ring

/// Circular progress indicator with percentage
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let colors: [Color]

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 80,
        colors: [Color] = [.blue, .purple]
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.colors = colors
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: colors + [colors.first!],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(animatedProgress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Shimmer Effect

/// Skeleton loading shimmer effect
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: phase)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 300
            }
        }
    }
}

// MARK: - Skeleton Loading Views

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerView()
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            ShimmerView()
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            ShimmerView()
                .frame(width: 150, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Neumorphic Components") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Neumorphic Components")
                .font(.title.bold())

            Button("Neumorphic Button") {}
                .buttonStyle(NeumorphicButtonStyle())

            NeumorphicCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Neumorphic Card")
                        .font(.headline)
                    Text("This is a card with soft shadow effects")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            NeumorphicTextField(
                placeholder: "Enter text...",
                text: .constant(""),
                icon: "magnifyingglass"
            )
            .padding(.horizontal)

            GradientButton(title: "Get Started", icon: "arrow.right") {}

            HStack(spacing: 30) {
                LoadingIndicator()
                ProgressRing(progress: 0.75)
            }

            SkeletonCard()
                .padding(.horizontal)
        }
        .padding()
    }
}
