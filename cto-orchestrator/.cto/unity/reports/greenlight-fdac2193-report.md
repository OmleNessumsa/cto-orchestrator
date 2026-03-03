# Greenlight iOS Compliance Report

**Scan ID:** greenlight-fdac2193
**App Path:** /Users/elmo.asmussen/Projects/HelmLog/ios/HelmLog.xcodeproj
**Scanned:** 2026-02-12T14:15:02.687248+00:00

## Overall Status: 🟡 REVIEW NEEDED

**Compliance Score:** 70/100

## Summary

| Type | Count |
|------|-------|
| 🔴 Blockers | 0 |
| 🟡 Warnings | 4 |
| 💡 Suggestions | 3 |

## Category Results

- ⏭️ **Payment & IAP Compliance** — Not Scanned
- ⏭️ **Privacy Manifests & Data Usage** — Not Scanned
- ⏭️ **Sign-In & Account Management** — Not Scanned
- ⏭️ **App Completeness & Metadata** — Not Scanned
- ⏭️ **Binary & Entitlement Validation** — Not Scanned

## Findings

### 1. 🟡 PrivacyInfo.xcprivacy file exists but content not verified

**Severity:** warning
**Category:** privacy
**Guideline:** [5.1.1](https://developer.apple.com/app-store/review/guidelines/#511)
**File:** HelmLog/PrivacyInfo.xcprivacy

The project references PrivacyInfo.xcprivacy (HelmLog/PrivacyInfo.xcprivacy) and includes it in the build Resources phase, which is good. However, I could not verify the content declarations (NSPrivacyTracking, NSPrivacyTrackingUsageDescription, NSPrivacyAccessedAPITypes, NSPrivacyCollectedDataTypes).

**Recommendation:** Verify the privacy manifest includes all required API declarations for location tracking, photo library access, and any third-party SDKs used. As of iOS 17, apps must declare reasons for using required reason APIs.

📚 [Apple Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
---

### 2. 🟡 Third-party SDK privacy manifests not verified

**Severity:** warning
**Category:** privacy
**Guideline:** [5.1.1](https://developer.apple.com/app-store/review/guidelines/#511)
**File:** Podfile

The project uses CocoaPods (libPods-HelmLog.a). Starting May 1, 2024, Apple requires privacy manifests from third-party SDKs. I could not verify if Pods include proper privacy manifests.

**Recommendation:** Run 'pod outdated' and update dependencies. Check that each pod includes a PrivacyInfo.xcprivacy file. Popular SDKs like React Native have added privacy manifests - ensure you're on recent versions.

📚 [Apple Documentation](https://developer.apple.com/support/third-party-SDK-requirements/)
---

### 3. 🟡 Info.plist content not verified

**Severity:** warning
**Category:** completeness
**Guideline:** [2.3.1](https://developer.apple.com/app-store/review/guidelines/#231)
**File:** HelmLog/Info.plist

The project references HelmLog/Info.plist but I could not verify its contents. Key metadata requirements include: CFBundleDisplayName, CFBundleShortVersionString, privacy usage descriptions (NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription, etc.).

**Recommendation:** Verify Info.plist contains all required keys including privacy usage descriptions for location, photos, and any other sensitive data access. All usage descriptions must clearly explain why the app needs access.

📚 [Apple Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list)
---

### 4. 💡 LaunchScreen.storyboard exists

**Severity:** suggestion
**Category:** completeness
**Guideline:** [2.1](https://developer.apple.com/app-store/review/guidelines/#21)
**File:** HelmLog/LaunchScreen.storyboard

The project includes LaunchScreen.storyboard in Resources, which is required for proper launch experience. Content could not be verified for placeholder elements.

**Recommendation:** Ensure launch screen does not contain placeholder text or temporary branding. It should match your app's visual design.

📚 [Apple Documentation](https://developer.apple.com/design/human-interface-guidelines/launching)
---

### 5. 💡 App Icon configuration present

**Severity:** suggestion
**Category:** completeness
**Guideline:** [2.3.3](https://developer.apple.com/app-store/review/guidelines/#233)
**File:** HelmLog/Images.xcassets

Build settings reference ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon, indicating an app icon asset catalog is configured. Could not verify all required icon sizes are present.

**Recommendation:** Verify Images.xcassets/AppIcon.appiconset contains all required sizes: 1024x1024 (App Store), plus all device-specific sizes. Use Xcode's asset catalog editor to check for missing sizes.

📚 [Apple Documentation](https://developer.apple.com/design/human-interface-guidelines/app-icons)
---

### 6. 🟡 Bundle identifier uses placeholder pattern

**Severity:** warning
**Category:** completeness
**Guideline:** [2.3.4](https://developer.apple.com/app-store/review/guidelines/#234)
**File:** project.pbxproj

PRODUCT_BUNDLE_IDENTIFIER is set to 'org.reactjs.native.example.$(PRODUCT_NAME:rfc1034identifier)' which is a React Native template placeholder. This should be updated to your organization's bundle ID.

**Recommendation:** Change PRODUCT_BUNDLE_IDENTIFIER to a unique identifier for your organization (e.g., 'com.yourcompany.helmlog'). This is required for App Store submission.

📚 [Apple Documentation](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
---

### 7. 💡 Minimum iOS version is 12.4

**Severity:** suggestion
**Category:** completeness
**Guideline:** [2.1](https://developer.apple.com/app-store/review/guidelines/#21)
**File:** project.pbxproj

IPHONEOS_DEPLOYMENT_TARGET is set to 12.4. While this is acceptable, iOS 12 has low market share. Consider whether supporting older iOS versions is necessary.

**Recommendation:** Consider raising minimum to iOS 14.0 or iOS 15.0 to reduce testing burden and access newer APIs. As of 2025, iOS 12-13 have <5% combined market share.

📚 [Apple Documentation](https://developer.apple.com/support/app-store/)
---


## Quick Fix Checklist

Based on the findings above, here's your to-do list:

### 🟡 Recommended Fixes
- [ ] PrivacyInfo.xcprivacy file exists but content not verified
- [ ] Third-party SDK privacy manifests not verified
- [ ] Info.plist content not verified
- [ ] Bundle identifier uses placeholder pattern


---
*Generated by Unity Greenlight — Rick's iOS App Store compliance checker*
*"Listen Morty, I didn't invent interdimensional travel just to get rejected by the App Store."*
