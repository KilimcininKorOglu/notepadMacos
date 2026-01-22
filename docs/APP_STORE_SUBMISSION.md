# App Store Submission Guide

This document contains all necessary information for publishing Tamga to the Mac App Store.

## App Information

| Field                  | Value                                      |
|------------------------|--------------------------------------------|
| App Name               | Tamga                                      |
| Bundle ID              | com.tamga.app                              |
| SKU                    | TAMGA001                                   |
| Primary Language       | English (U.S.)                             |
| Category               | Developer Tools / Productivity             |
| Secondary Category     | Utilities                                  |
| Content Rights         | Does not contain third-party content       |
| Age Rating             | 4+                                         |
| Price                  | Free                                       |

## Requirements Checklist

### Before Submission

- [ ] App Icon (1024x1024 PNG, no alpha)
- [ ] Screenshots for all required sizes
- [ ] Privacy Policy URL
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] App Store description in all languages
- [ ] Keywords for all languages
- [ ] Build uploaded via Xcode or Transporter
- [ ] Sandbox entitlements configured
- [ ] Hardened Runtime enabled
- [ ] Code signed with distribution certificate

### Xcode Settings

```
PRODUCT_BUNDLE_IDENTIFIER = com.tamga.app
CODE_SIGN_STYLE = Manual (for distribution)
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = Tamga Mac App Store
ENABLE_HARDENED_RUNTIME = YES
```

### Required Capabilities

- App Sandbox: YES
- File Access: User Selected File (Read/Write)

## Screenshot Requirements

### Mac App Store Sizes

| Display              | Size (pixels)      | Required |
|----------------------|-------------------|----------|
| Mac (16-inch)        | 3456 x 2234       | Yes      |
| Mac (13-inch)        | 2880 x 1800       | Optional |

### Screenshot Content Suggestions

1. Main editor with syntax highlighted code
2. Multiple tabs open
3. Find & Replace in action
4. Dark mode view
5. Language selection menu
6. File comparison view

## Privacy Policy

Tamga does not collect, store, or transmit any user data. All files are stored locally on the user's device.

Required sections for Privacy Policy:
- Data Collection: None
- Data Storage: Local only (~/Library/Application Support/Tamga/)
- Third-party Services: None
- Analytics: None
- Contact Information

## App Review Notes

```
Tamga is a text editor for macOS. To test the app:

1. Launch the app
2. Create a new tab (Cmd+N) or open a file (Cmd+O)
3. Try syntax highlighting with .swift, .py, .js files
4. Test Find & Replace (Cmd+F)
5. Change language from menu bar (Tamga > Language)
6. Toggle dark/light theme (Tamga > Theme)

No login or special configuration required.
```

## Build & Upload

### Archive for Distribution

```bash
# Clean build folder
xcodebuild clean -scheme Tamga

# Archive
xcodebuild archive \
  -scheme Tamga \
  -archivePath build/Tamga.xcarchive \
  -destination 'generic/platform=macOS'

# Export for App Store
xcodebuild -exportArchive \
  -archivePath build/Tamga.xcarchive \
  -exportPath build/AppStore \
  -exportOptionsPlist ExportOptions.plist
```

### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
```

## Version History Template

### Version 1.0

Initial release with:
- Tab-based editing
- Syntax highlighting for 14 languages
- Session restore
- 20 language UI support
- Find & Replace
- File comparison
- CLI support
