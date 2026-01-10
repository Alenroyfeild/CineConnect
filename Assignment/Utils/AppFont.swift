//
//  AppFont.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import SwiftUI

struct AppFont {
    // MARK: - Font Families
    private static let primaryFamily = "System"
    
    // MARK: - Display Fonts (Large titles)
    static let displayLarge = Font.system(size: 57, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 45, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 36, weight: .semibold, design: .rounded)
    
    // MARK: - Headline Fonts
    static let headlineLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    
    // MARK: - Title Fonts
    static let titleLarge = Font.system(size: 22, weight: .medium, design: .rounded)
    static let titleMedium = Font.system(size: 20, weight: .medium, design: .rounded)
    static let titleSmall = Font.system(size: 18, weight: .medium, design: .rounded)
    
    // MARK: - Body Fonts
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .rounded)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .rounded)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .rounded)
    
    // MARK: - Label Fonts
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .rounded)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .rounded)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .rounded)
    
    // MARK: - Caption Fonts
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .rounded)
    
    // MARK: - Special Fonts
    static let monospacedDigit = Font.system(size: 16, weight: .regular, design: .monospaced)
    static let tagLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
}
