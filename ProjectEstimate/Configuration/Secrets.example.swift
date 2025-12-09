//
//  Secrets.example.swift
//  BuildPeek
//
//  EXAMPLE configuration file - Copy this to Secrets.swift and fill in your values
//
//  INSTRUCTIONS:
//  1. Copy this file and rename to Secrets.swift
//  2. Replace all "YOUR_*" values with your actual credentials
//  3. Secrets.swift is gitignored and won't be committed
//
//  NOTE: This file is NOT compiled - it's just a template.
//  The actual Secrets.swift file is used by the build.
//

/*
import Foundation

enum Secrets {

    // MARK: - Supabase Configuration

    /// Your Supabase project URL
    /// Find at: Supabase Dashboard > Settings > API > Project URL
    static let supabaseURL = "https://qtjzmuwooildluukcppn.supabase.co"

    /// Supabase anonymous/public key
    /// Find at: Supabase Dashboard > Settings > API > anon/public key
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0anptdXdvb2lsZGx1dWtjcHBuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzMTgxMDcsImV4cCI6MjA4MDg5NDEwN30._wzLa0pUc4jn2t6dZeKV5g3BOapC6jwbbbhFhI_CiYk"

    // MARK: - Gemini AI Configuration

    /// Google Gemini API key
    /// Get at: https://aistudio.google.com/app/apikey
    static let geminiAPIKey = "AIzaSyATYtUJBbfczKIWDS4WO1z6Y217orwj0pA"

    // MARK: - OAuth Configuration

    /// Google OAuth Client ID (optional, for Google Sign-In)
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID"

    /// OAuth callback scheme
    static let oauthCallbackScheme = "buildpeek"

    // MARK: - Validation

    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR_") &&
        !supabaseAnonKey.contains("YOUR_") &&
        !geminiAPIKey.contains("YOUR_")
    }

    static var missingConfiguration: [String] {
        var missing: [String] = []
        if supabaseURL.contains("YOUR_") { missing.append("Supabase URL") }
        if supabaseAnonKey.contains("YOUR_") { missing.append("Supabase Anon Key") }
        if geminiAPIKey.contains("YOUR_") { missing.append("Gemini API Key") }
        return missing
    }
}
*/
