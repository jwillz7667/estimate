//
//  Secrets.swift
//  BuildPeek
//
//  Environment configuration for API keys and secrets
//
//  HOW TO USE:
//  1. Copy Secrets.example.swift to Secrets.swift (this file)
//  2. Replace placeholder values with your actual keys
//  3. Secrets.swift is gitignored - never commit real keys
//

import Foundation

// MARK: - App Secrets

/// All API keys and secrets for the app
/// These should be set before building for production
enum Secrets {

    // MARK: - Supabase Configuration

    /// Your Supabase project URL (e.g., "https://abc123.supabase.co")
    static let supabaseURL = "YOUR_SUPABASE_PROJECT_URL"

    /// Supabase anonymous/public key (safe to include in app)
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // MARK: - Gemini AI Configuration

    /// Google Gemini API key for AI estimates and image generation
    /// Get yours at: https://aistudio.google.com/app/apikey
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"

    // MARK: - OAuth Configuration (for Supabase Auth)

    /// Google OAuth Client ID (for Google Sign-In via Supabase)
    /// Configure in Supabase Dashboard > Authentication > Providers > Google
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID"

    /// URL scheme for OAuth callbacks (must match Info.plist)
    static let oauthCallbackScheme = "buildpeek"

    // MARK: - Validation

    /// Check if secrets are configured (not placeholder values)
    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR_") &&
        !supabaseAnonKey.contains("YOUR_") &&
        !geminiAPIKey.contains("YOUR_")
    }

    /// Returns missing configuration items
    static var missingConfiguration: [String] {
        var missing: [String] = []

        if supabaseURL.contains("YOUR_") {
            missing.append("Supabase URL")
        }
        if supabaseAnonKey.contains("YOUR_") {
            missing.append("Supabase Anon Key")
        }
        if geminiAPIKey.contains("YOUR_") {
            missing.append("Gemini API Key")
        }

        return missing
    }
}

// MARK: - Usage Instructions
/*

 📋 SETUP INSTRUCTIONS:

 1. SUPABASE SETUP:
    - Go to https://supabase.com and create a project
    - Copy your Project URL and anon/public key from Settings > API
    - Paste them above as supabaseURL and supabaseAnonKey

 2. GEMINI API SETUP:
    - Go to https://aistudio.google.com/app/apikey
    - Create an API key
    - Paste it above as geminiAPIKey

 3. GOOGLE SIGN-IN SETUP (Optional):
    - In Supabase Dashboard, go to Authentication > Providers > Google
    - Enable Google provider
    - Add your Google OAuth credentials
    - Copy the Client ID and paste above as googleClientID

 4. APPLE SIGN-IN SETUP (Optional):
    - In Supabase Dashboard, go to Authentication > Providers > Apple
    - Follow the setup instructions
    - Apple Sign-In uses the app's bundle ID automatically

 5. IMPORTANT:
    - This file (Secrets.swift) should be in .gitignore
    - Never commit real API keys to version control
    - For CI/CD, use environment variables or secure secret management

 */
