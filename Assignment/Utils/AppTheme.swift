//
//  AppTheme.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import SwiftUI

struct AppTheme {
    /// Color Palette
    private static let slate900 = Color(red: 0.07, green: 0.09, blue: 0.13)
    private static let slate800 = Color(red: 0.12, green: 0.15, blue: 0.20)
    private static let slate700 = Color(red: 0.20, green: 0.24, blue: 0.31)
    private static let indigo600 = Color(red: 0.31, green: 0.40, blue: 0.67)
    private static let indigo500 = Color(red: 0.39, green: 0.51, blue: 0.78)
    private static let teal600 = Color(red: 0.08, green: 0.51, blue: 0.56)
    private static let teal500 = Color(red: 0.09, green: 0.60, blue: 0.66)

    /// Primary gradient (darker, desaturated)
    static let primaryGradient = LinearGradient(
        colors: [slate900, slate800],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent gradient (cool, muted tones)
    static let accentGradient = LinearGradient(
        colors: [indigo600, teal600],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Card gradient (subtle, low contrast)
    static let cardGradient = LinearGradient(
        colors: [
            slate700.opacity(0.4),
            slate700.opacity(0.2)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Loading gradient (muted shimmer)
    static let shimmerGradient = LinearGradient(
        colors: [
            indigo500.opacity(0.2),
            teal500.opacity(0.2),
            indigo500.opacity(0.2)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Surface colors
    static let surface = slate800.opacity(0.6)
    static let surfaceElevated = slate700.opacity(0.8)
    static let surfaceBorder = slate700.opacity(0.5)

    /// Text colors
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.65)
    static let textTertiary = Color.white.opacity(0.45)

    /// Accent colors
    static let accentPrimary = indigo500
    static let accentSecondary = indigo600

    /// Glow effects
    static let errorGlow = indigo500.opacity(0.2)
    static let iconGlow = LinearGradient(
        colors: [
            indigo600.opacity(0.25),
            teal600.opacity(0.25)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
