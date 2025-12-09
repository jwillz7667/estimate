//
//  BuildPeekDesignSystem.swift
//  BuildPeek
//
//  Comprehensive design system for BUILD PEEK brand identity
//  Modern construction-focused aesthetic with bold typography and clean colors
//

import SwiftUI

// MARK: - Brand Colors

/// BUILD PEEK color palette - matches app icon colors exactly
/// Left side of house icon: Slate Blue (#5B7FB0)
/// Right side of house icon: Sky Blue (#6BB8E8)
struct BuildPeekColors {
    // Primary brand colors - MATCHING APP ICON
    static let primaryBlue = Color(hex: "5B7FB0")      // Slate Blue (left side of app icon house)
    static let secondaryBlue = Color(hex: "6BB8E8")    // Sky Blue (right side of app icon house)
    static let accentBlue = Color(hex: "6BB8E8")       // Sky Blue for highlights
    static let accentYellow = Color(hex: "FFD700")     // Gold accent for emphasis (optional)

    // Legacy alias for compatibility
    static let secondaryOrange = primaryBlue

    // Backgrounds - WHITE/LIGHT
    static let background = Color.white
    static let backgroundSecondary = Color(hex: "F8FAFC")  // Very light gray
    static let backgroundTertiary = Color(hex: "F1F5F9")   // Light gray
    static let cardBackground = Color.white

    // Text colors
    static let textPrimary = Color(hex: "1E293B")      // Dark slate for text
    static let textSecondary = Color(hex: "64748B")    // Medium gray
    static let textTertiary = Color(hex: "94A3B8")     // Light gray

    // Semantic colors
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "5B7FB0")             // Using app icon slate blue

    // Accent gradients - App Icon Colors (Slate Blue to Sky Blue)
    static let primaryGradient = LinearGradient(
        colors: [primaryBlue, Color(hex: "4A6A9A")],   // Slate blue gradient
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [primaryBlue, secondaryBlue],          // App icon gradient (slate to sky)
        startPoint: .leading,
        endPoint: .trailing
    )

    static let blueGradient = LinearGradient(
        colors: [primaryBlue, secondaryBlue],          // App icon gradient
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Light background gradient (subtle)
    static let lightGradient = LinearGradient(
        colors: [background, backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )

    // For backwards compatibility
    static let darkNavy = textPrimary
    static let slate = textSecondary
    static let concrete = backgroundTertiary
    static let steel = textSecondary
}

// MARK: - Brand Typography

struct BuildPeekTypography {
    // Display - Hero text
    static let displayLarge = Font.system(size: 48, weight: .black, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)

    // Headlines
    static let headlineLarge = Font.system(size: 24, weight: .bold, design: .default)
    static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)

    // Body text
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // Labels
    static let labelLarge = Font.system(size: 14, weight: .semibold, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // Monospace for numbers
    static let numberLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let numberMedium = Font.system(size: 24, weight: .semibold, design: .monospaced)
    static let numberSmall = Font.system(size: 16, weight: .medium, design: .monospaced)
}

// MARK: - Brand Spacing

struct BuildPeekSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Brand Corner Radius

struct BuildPeekRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - BUILD PEEK Logo View

struct BuildPeekLogo: View {
    enum Size {
        case small, medium, large, hero

        var iconSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 48
            case .hero: return 80
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .system(size: 16, weight: .black, design: .rounded)
            case .medium: return .system(size: 20, weight: .black, design: .rounded)
            case .large: return .system(size: 28, weight: .black, design: .rounded)
            case .hero: return .system(size: 42, weight: .black, design: .rounded)
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            case .hero: return 14
            }
        }
    }

    let size: Size
    let showIcon: Bool
    let colorScheme: ColorScheme?

    @Environment(\.colorScheme) private var envColorScheme

    init(size: Size = .medium, showIcon: Bool = true, colorScheme: ColorScheme? = nil) {
        self.size = size
        self.showIcon = showIcon
        self.colorScheme = colorScheme
    }

    private var effectiveColorScheme: ColorScheme {
        colorScheme ?? envColorScheme
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            if showIcon {
                // Construction/Eye icon representing "peek"
                ZStack {
                    RoundedRectangle(cornerRadius: size.iconSize * 0.2)
                        .fill(BuildPeekColors.accentGradient)
                        .frame(width: size.iconSize, height: size.iconSize)

                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: size.iconSize * 0.55, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: -2) {
                Text("BUILD")
                    .font(size.fontSize)
                    .foregroundStyle(
                        effectiveColorScheme == .dark
                        ? Color.white
                        : BuildPeekColors.darkNavy
                    )

                Text("PEEK")
                    .font(size.fontSize)
                    .foregroundStyle(BuildPeekColors.secondaryOrange)
            }
        }
    }
}

// MARK: - BUILD PEEK Primary Button

struct BuildPeekButton: View {
    enum Style {
        case primary
        case secondary
        case accent
        case ghost
    }

    let title: String
    let icon: String?
    let style: Style
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(BuildPeekTypography.labelLarge)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: style == .ghost ? nil : .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: BuildPeekRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: BuildPeekRadius.medium)
                    .strokeBorder(borderColor, lineWidth: style == .ghost ? 2 : 0)
            )
            .shadow(color: shadowColor, radius: isPressed ? 2 : 8, y: isPressed ? 1 : 4)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .accent: return .white
        case .secondary: return BuildPeekColors.primaryBlue
        case .ghost: return BuildPeekColors.secondaryOrange
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            BuildPeekColors.primaryGradient
        case .secondary:
            Color(.secondarySystemGroupedBackground)
        case .accent:
            BuildPeekColors.accentGradient
        case .ghost:
            Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost: return BuildPeekColors.secondaryOrange
        default: return .clear
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary: return BuildPeekColors.primaryBlue.opacity(0.3)
        case .accent: return BuildPeekColors.secondaryOrange.opacity(0.3)
        default: return .clear
        }
    }
}

// MARK: - BUILD PEEK Card

struct BuildPeekCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: BuildPeekRadius.large)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                        radius: 12,
                        y: 4
                    )
            )
    }
}

// MARK: - BUILD PEEK Stat Card

struct BuildPeekStatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Double?
    let color: Color

    init(
        title: String,
        value: String,
        icon: String,
        trend: Double? = nil,
        color: Color = BuildPeekColors.primaryBlue
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.trend = trend
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.bold())
                        Text("\(abs(Int(trend)))%")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(trend >= 0 ? BuildPeekColors.success : BuildPeekColors.error)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(BuildPeekTypography.numberMedium)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(BuildPeekTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(BuildPeekSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: BuildPeekRadius.large))
    }
}

// MARK: - BUILD PEEK Section Header

struct BuildPeekSectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionLabel: String?

    init(
        _ title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BuildPeekTypography.headlineMedium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(BuildPeekTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(BuildPeekTypography.labelMedium)
                        .foregroundStyle(BuildPeekColors.secondaryOrange)
                }
            }
        }
    }
}

// MARK: - BUILD PEEK Input Field

struct BuildPeekTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let keyboardType: UIKeyboardType

    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BuildPeekColors.slate)
                    .frame(width: 24)
            }

            TextField(placeholder, text: $text)
                .font(BuildPeekTypography.bodyMedium)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: BuildPeekRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: BuildPeekRadius.medium)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

// MARK: - BUILD PEEK Tab Bar Appearance

struct BuildPeekTabBarAppearance {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Tab bar colors
        let normalColor = UIColor(BuildPeekColors.slate)
        let selectedColor = UIColor(BuildPeekColors.secondaryOrange)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - BUILD PEEK Navigation Bar Appearance

struct BuildPeekNavBarAppearance {
    static func configure() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // Title attributes
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(BuildPeekColors.secondaryOrange)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("BUILD PEEK Design System") {
    ScrollView {
        VStack(spacing: 32) {
            // Logo variations
            VStack(spacing: 24) {
                BuildPeekLogo(size: .hero)
                BuildPeekLogo(size: .large)
                BuildPeekLogo(size: .medium)
                BuildPeekLogo(size: .small)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Buttons
            VStack(spacing: 12) {
                BuildPeekButton("Get Started", icon: "arrow.right", style: .primary) {}
                BuildPeekButton("View Projects", icon: "folder", style: .secondary) {}
                BuildPeekButton("Generate Estimate", icon: "sparkles", style: .accent) {}
                BuildPeekButton("Learn More", style: .ghost) {}
            }
            .padding()

            // Stat Cards
            HStack(spacing: 12) {
                BuildPeekStatCard(
                    title: "Total Projects",
                    value: "24",
                    icon: "folder.fill",
                    trend: 12,
                    color: BuildPeekColors.primaryBlue
                )
                BuildPeekStatCard(
                    title: "This Month",
                    value: "$45.2K",
                    icon: "dollarsign.circle.fill",
                    trend: -5,
                    color: BuildPeekColors.secondaryOrange
                )
            }
            .padding()

            // Text field
            BuildPeekTextField(
                "Project name",
                text: .constant(""),
                icon: "pencil"
            )
            .padding()
        }
    }
}
