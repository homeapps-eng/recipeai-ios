# RecipeAI iOS

Native iOS application for RecipeAI - AI-powered recipe generation from food photos.

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- CocoaPods or Swift Package Manager

## Setup Instructions

### 1. Create Xcode Project

Since the project.pbxproj was generated as a skeleton, you need to create a proper Xcode project:

1. Open Xcode
2. Create a new iOS App project:
   - Product Name: `RecipeAI`
   - Team: Your development team
   - Organization Identifier: `com.homeapps`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
3. Save it to `~/code/RecipeAI-iOS/`
4. Delete the auto-generated files and replace with the source files in `RecipeAI/`

### 2. Add Swift Package Dependencies

In Xcode, go to File > Add Package Dependencies and add:

1. **Firebase iOS SDK**
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version: 11.0.0+
   - Products: FirebaseAuth, FirebaseFirestore, FirebaseAnalytics

2. **Google Sign-In**
   - URL: `https://github.com/google/GoogleSignIn-iOS`
   - Version: 8.0.0+

3. **Kingfisher** (Image Loading)
   - URL: `https://github.com/onevcat/Kingfisher`
   - Version: 7.0.0+

4. **Google Mobile Ads SDK**
   - URL: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
   - Version: 11.0.0+

### 3. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (recipeai-dd0bc)
3. Add iOS app with bundle ID: `com.homeapps.recipeai`
4. Download `GoogleService-Info.plist`
5. Add it to `RecipeAI/Resources/`

### 4. Copy Assets from Android

The app uses Apple's native San Francisco font (no custom fonts needed).

Copy and convert image assets as needed:
- App icon: Create 1024x1024 icon for App Store
- Category images: Convert PNG assets for iOS

### 5. Configure Signing & Capabilities

In Xcode, go to Signing & Capabilities:

1. **Signing**
   - Select your development team
   - Set bundle identifier: `com.homeapps.recipeai`

2. **Add Capabilities**
   - Sign in with Apple
   - Push Notifications
   - Associated Domains (for deep links)
     - Add: `applinks:api.recipe-ai.io`

### 6. Update Info.plist

The Info.plist in `RecipeAI/Resources/` includes:
- Camera permission description
- Photo library permissions
- AdMob App ID (replace with production ID)
- URL schemes for deep linking
- Custom fonts

### 7. Build and Run

1. Select an iOS 17+ simulator or device
2. Build (⌘B)
3. Run (⌘R)

## Project Structure

```
RecipeAI-iOS/
├── RecipeAI/
│   ├── App/                    # App entry point, delegates
│   ├── Core/
│   │   ├── Config/             # App configuration
│   │   ├── Extensions/         # Swift extensions
│   │   └── Utilities/          # Helper classes
│   ├── Services/
│   │   ├── Networking/         # API client
│   │   ├── Authentication/     # Auth management
│   │   ├── Storage/            # Local storage
│   │   └── Managers/           # Business logic managers
│   ├── Models/                 # Data models
│   ├── Features/               # Feature modules
│   │   ├── Authentication/
│   │   ├── Home/
│   │   ├── Camera/
│   │   ├── Recipes/
│   │   ├── Calories/
│   │   ├── Favorites/
│   │   ├── Onboarding/
│   │   ├── Profile/
│   │   └── Subscription/
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Fonts/
│       └── Info.plist
└── README.md
```

## Features

- **Photo-based Recipe Generation**: Take a photo of ingredients to get AI-generated recipes
- **Calorie Calculation**: Analyze food photos for calorie estimation
- **Favorites**: Save and organize favorite recipes
- **User Preferences**: Customize food categories, cuisines, dietary restrictions
- **Subscription**: Premium features via Stripe
- **AdMob Integration**: Rewarded ads for free users

## API Endpoints

The app connects to:
- Production: `https://api.recipe-ai.io`
- Test: `https://recipeai-nexus-test-pqr45hbz6a-uc.a.run.app`

## Configuration

Environment-specific settings are in `Core/Config/AppConfig.swift`:
- API base URLs
- AdMob configuration
- App limits (daily recipes, etc.)
- Cache durations

## Testing on Device

1. Connect your iPhone
2. In Xcode, select your device as the run destination
3. Ensure your device is registered in your Apple Developer account
4. Build and run

## App Store Submission

Before submitting:

1. Replace test AdMob IDs with production IDs in `AppConfig.swift`
2. Update app version and build number
3. Create App Store screenshots
4. Prepare app description and keywords
5. Archive and upload via Xcode Organizer

## Troubleshooting

### Build Errors

1. **Missing Firebase**: Ensure GoogleService-Info.plist is in the project
2. **Signing Issues**: Check your team and provisioning profiles
3. **SPM Issues**: Reset package caches (File > Packages > Reset Package Caches)

### Runtime Issues

1. **Camera Not Working**: Check Info.plist permissions
2. **API Errors**: Verify network connectivity and token validity
3. **Sign-In Issues**: Ensure Firebase and Google Sign-In are configured correctly

## License

Proprietary - HomeApps
