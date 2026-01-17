# iOS Simulator Optimization Guide for PDF Pages

This document covers iOS Simulator-specific considerations for the PDF Pages Flutter app.

---

## Quick Reference Commands

```bash
# Launch Simulator app
open -a Simulator

# Run Flutter app on Simulator
flutter run

# Build for Simulator specifically
flutter build ios --simulator

# List available simulators
xcrun simctl list devices

# Boot specific device
xcrun simctl boot "iPhone 15"

# Screenshot for verification
xcrun simctl io booted screenshot ~/Desktop/screenshot.png

# Clear app data
xcrun simctl uninstall booted com.quickhitter.pdfpages
flutter run

# Check app logs
flutter logs
```

---

## Testing Device Sizes

Test on these three devices to ensure responsive design:

| Device | Screen Size | Use Case |
|--------|-------------|----------|
| iPhone SE (3rd gen) | 375 x 667 | Smallest supported |
| iPhone 15 | 393 x 852 | Standard/default |
| iPhone 15 Pro Max | 430 x 932 | Largest iPhone |

**How to switch:**
1. In Simulator: File > Open Simulator > iOS 17.x > [Device]
2. Or from terminal: `xcrun simctl boot "iPhone 15 Pro Max"`

---

## Adding Test PDFs to Simulator

The app needs PDFs to test with. Here's how to add them:

### Method 1: Drag and Drop
1. Open Finder and locate sample PDFs
2. Open Simulator with Files app visible
3. Drag PDF from Finder into Simulator's Files app

### Method 2: Via Terminal
```bash
# Copy file to Simulator's Documents
xcrun simctl get_app_container booted com.quickhitter.pdfpages data
# Then use the returned path to copy files
```

### Sample Test PDFs
Create or obtain these for testing:
- `simple.pdf` - 3 pages, simple text
- `large.pdf` - 50+ pages, mixed content
- `encrypted.pdf` - Password-protected (for error handling)
- `scanned.pdf` - Image-heavy document

---

## Features That Behave Differently in Simulator

### Works in Simulator
| Feature | Notes |
|---------|-------|
| Document Picker | Opens Files app, can select PDFs |
| PDF Rendering | pdfx renders correctly |
| Share Sheet | Opens but some targets unavailable |
| RevenueCat Sandbox | Purchases work in test mode |
| Animations | Work but may be slower |
| Dark Mode | Toggle via Settings app |

### Limited/Different in Simulator
| Feature | Simulator Behavior | Real Device |
|---------|-------------------|-------------|
| Haptic Feedback | No feedback | Vibration works |
| "Open In" from Files | Not available | Works |
| Camera/Photos | Simulated library | Real access |
| Performance | Slower, especially rendering | Native speed |
| Memory Limits | Host machine limits | Device limits |

### Not Available in Simulator
| Feature | Alternative |
|---------|-------------|
| App Store Purchases | Use Sandbox testing |
| Push Notifications | N/A for this app |
| Biometrics | N/A for this app |

---

## Performance Monitoring

### Memory Usage
Monitor during PDF operations:
```bash
# In Xcode: Debug > Simulate Memory Warning
# Or watch Activity Monitor for "Simulator" process
```

**Red Flags:**
- Memory spike >500MB during thumbnail generation
- Memory not released after closing document
- Gradual memory increase over multiple operations

### CPU Usage
High CPU is expected during:
- PDF loading (initial parse)
- Thumbnail generation (brief spikes)
- Page extraction (sustained during render)

**Red Flags:**
- CPU stays high after operation completes
- UI becomes unresponsive during operations

---

## Common Simulator Issues & Solutions

### Issue: "No connected devices"
```bash
# Fix: Restart simulator
killall Simulator
open -a Simulator
```

### Issue: App won't install
```bash
# Fix: Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Issue: Slow performance
```bash
# Fix: Close other apps, restart Simulator
# Or try different device (SE is lighter than Pro Max)
```

### Issue: File picker shows no files
```bash
# Fix: Add files to Simulator first (see above)
# Make sure Files app is set up (run it once)
```

### Issue: Dark mode not applying
```bash
# Fix: Toggle in Simulator settings
# Settings > Developer > Dark Appearance
```

---

## Build Configurations

### Debug (default)
```bash
flutter run
```
- Hot reload enabled
- Debug banner shown
- Slower performance
- Good for development

### Profile
```bash
flutter run --profile
```
- Near-release performance
- Debug features available
- Good for performance testing

### Release (for final verification)
```bash
flutter build ios --simulator
# Note: Can't actually run release on Simulator
# Use Profile mode for closest approximation
```

---

## Debugging Tips

### Flutter DevTools
```bash
flutter run --debug
# Then open DevTools URL shown in console
```

Useful tabs:
- **Widget Inspector** - UI hierarchy
- **Performance** - Frame timing
- **Memory** - Allocation tracking
- **Network** - N/A (all local processing)

### Logging
```dart
// Use debugPrint for development logs
debugPrint('PDF loaded: ${document.pageCount} pages');

// These won't appear in release builds
```

### Breakpoints
Use VS Code or Android Studio debugger. Set breakpoints in:
- `PdfService.loadPdf()` - PDF loading issues
- `PdfService.extractPages()` - Extraction issues
- Provider notifiers - State management issues

---

## Pre-Submission Checklist

Before submitting to App Store, verify on Simulator:

- [ ] App launches without crashes
- [ ] Home screen matches mockup
- [ ] Can pick PDF from Files
- [ ] Thumbnails generate progressively
- [ ] Page selection works (tap, range, all/clear)
- [ ] Extraction creates valid PDF
- [ ] Share sheet opens with generated PDF
- [ ] Usage counter increments
- [ ] Paywall appears when limit reached
- [ ] Settings screen accessible
- [ ] All screens work in both orientations (if supported)
- [ ] Works on SE, 15, and Pro Max sizes

---

## Useful Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Xcode Simulator Guide](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator)
- [RevenueCat Testing](https://www.revenuecat.com/docs/test-and-launch/sandbox)
- [pdfx Package](https://pub.dev/packages/pdfx)

---

*Last updated: January 2026*
