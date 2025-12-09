# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## App Overview

**BUILD PEEK** - AI-Powered Renovation Cost Estimation & Visualization
"See your renovation before you build it"

## Build Commands

```bash
# Build for simulator (iOS 26.1)
xcodebuild -scheme ProjectEstimate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run all tests
xcodebuild test -scheme ProjectEstimate -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single test class
xcodebuild test -scheme ProjectEstimate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ProjectEstimateTests/ProjectEstimateTests

# Archive for distribution
xcodebuild archive -scheme ProjectEstimate -archivePath ./build/ProjectEstimate.xcarchive
```

## Architecture Overview

**Pattern**: MVVM with Dependency Injection using Swift 6 concurrency (`@MainActor`, `@Observable`)

### Data Flow
1. **Views** observe `@Observable` ViewModels via SwiftUI's `@Environment`
2. **ViewModels** call Services and update state
3. **Services** handle API calls, persistence, and business logic
4. **Models** are SwiftData `@Model` classes for local persistence

### Key Architectural Components

**AppState** (`ViewModels/AppState.swift:20`) - Global singleton managing:
- Navigation state (`selectedTab`, `showOnboarding`)
- Authentication state
- Feature flags
- Error handling

**DIContainer** (`ViewModels/AppState.swift:178`) - Dependency injection container holding:
- `networkService`, `geminiService`, `pdfService`, `keyManager`
- Factory methods for creating ViewModels with dependencies

**Environment Injection** - Views access state via:
```swift
@Environment(AppState.self) private var appState
@Environment(DIContainer.self) private var container
```

### Service Layer

| Service | Purpose |
|---------|---------|
| `Auth0Service` | Authentication with Google, Apple, and Email via Auth0 |
| `GeminiAPIService` | Gemini 3.0 Pro (estimates) + Nano Banana Pro (images) |
| `LocalSellersService` | Local material sellers and regional pricing integration |
| `PricingSearchService` | Real-time material and labor cost lookup |
| `NetworkService` | Generic HTTP client with retry logic |
| `KeychainService` | Secure credential storage |
| `SubscriptionService` | StoreKit 2 purchases, uses `@MainActor` |
| `StripePaymentService` | Stripe + Apple Pay integration |
| `SupabaseService` | Cloud sync with RLS-protected Postgres |
| `PDFExportService` | Branded PDF report generation |

### SwiftData Models

All models use `@Model` macro and conform to `@unchecked Sendable` for Swift 6:
- `RenovationProject` - Core entity with relationships to estimates/images, includes `uploadedImageData` for photos
- `EstimateResult` - AI-generated cost breakdown
- `GeneratedImage` - AI visualization outputs
- `User` - Profile with subscription tier

### Enums with Business Logic

Located in model files, these enums contain computed properties for costs/multipliers:
- `RoomType` - `averageCostPerSqFt: ClosedRange<Double>` (realistic 2024-2025 pricing)
- `QualityTier` - `multiplier: Double`
- `SubscriptionTier` - `estimateLimit`, `imageLimit`, `features`

## BUILD PEEK Design System

The app uses a custom design system defined in `Views/Components/BuildPeekDesignSystem.swift`:

### Brand Colors (White Background + Cobalt Blue Accents)
```swift
BuildPeekColors.primaryBlue      // #0047AB - Cobalt Blue (main accent)
BuildPeekColors.accentBlue       // #1E90FF - Dodger blue for highlights
BuildPeekColors.accentYellow     // #FFD700 - Gold accent
BuildPeekColors.background       // White - Primary background
BuildPeekColors.backgroundSecondary // #F8FAFC - Light gray
BuildPeekColors.textPrimary      // #1E293B - Dark text
BuildPeekColors.textSecondary    // #64748B - Gray text
```

### Components
- `BuildPeekLogo` - Animated logo with size variants
- `BuildPeekButton` - Primary/secondary/accent/ghost button styles
- `BuildPeekCard` - Standard card container
- `BuildPeekStatCard` - Dashboard statistics card
- `BuildPeekTextField` - Styled input field
- `BuildPeekSectionHeader` - Section headers with optional actions

## Swift 6 Concurrency Notes

- All ViewModels and Services are `@MainActor`
- Use `StoreKit.Transaction` (not `Transaction`) to avoid SwiftData ambiguity
- Codable DTOs don't need `Sendable` when used within `@MainActor` context
- `@Observable` classes cannot use `lazy var` - initialize in `init()`

## Database (Supabase)

**Schema**: `supabase/migrations/20241206_initial_schema.sql`

**RLS Pattern**: All user data filtered by `auth.uid() = user_id`

**Key Tables**: profiles, renovation_projects, estimate_results, generated_images, materials_catalog

## Authentication (Auth0)

Authentication service: `Services/Auth/Auth0Service.swift`

### Supported Providers
- **Google** - OAuth via `google-oauth2` connection
- **Apple** - Sign in with Apple via `apple` connection
- **Email** - Username/password via `Username-Password-Authentication`

### Configuration
Set your Auth0 credentials in `Auth0Configuration`:
```swift
static let domain = "YOUR_AUTH0_DOMAIN.auth0.com"
static let clientId = "YOUR_AUTH0_CLIENT_ID"
```

### URL Scheme
Add to Info.plist:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>buildpeek</string>
    </array>
  </dict>
</array>
```

## API Configuration

Gemini endpoint: `https://generativelanguage.googleapis.com/v1beta`
- Text/Estimate model: `gemini-3.0-pro` (primary) / `gemini-2.0-flash` (fallback)
- Image model: `gemini-3-pro-image-preview` (Nano Banana Pro)
- Vision: Uses `gemini-3.0-pro` for photo analysis

API keys stored in Keychain via `KeychainService.Keys.geminiAPIKey`

### API Key Validation
The API validation flow tries multiple models in sequence:
1. `gemini-3.0-pro` (primary)
2. `gemini-2.0-flash` (fallback)
3. `gemini-1.5-flash` (last resort)

This ensures compatibility with different API key tiers and model availability.

## Key Features

1. **Photo-Based Estimation**: Users upload photos, AI analyzes space for accurate estimates
2. **AI Visualization**: Generates "after" images showing completed renovation
3. **Regional Pricing**: Material and labor costs adjusted by ZIP code
4. **Subscription Tiers**: Free/Pro/Enterprise with StoreKit 2 + Stripe

## Subscription Product IDs

- `com.buildpeek.pro.monthly` / `.annual`
- `com.buildpeek.enterprise.monthly` / `.annual`
