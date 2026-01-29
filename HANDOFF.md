# PDF Pages Handoff - 2026-01-29

## Current State

App is **code-complete** for all PRD stories. Now finishing **App Store Connect metadata** before submitting build.

### What's Done

| Component | Status | Notes |
|-----------|--------|-------|
| Core app functionality | ✅ Complete | PDF loading, page selection, extraction, export |
| PostHog analytics | ✅ Complete | Key: `phc_CN2G4I039vFq7xwvumAc0TEzQhg8MdaqG5sWeqjIPBi` |
| RevenueCat SDK | ✅ Complete | Key: `appl_MtWeucoFhDIikFoUCfHMLPuaFId` |
| Paywall UI | ✅ Complete | Shows when 3 free extractions exhausted |
| Settings screen | ✅ Complete | Premium status, restore, legal links |
| Encrypted PDF handling | ✅ Complete | Error dialog with "Try Another" option |
| App Store Connect - Subscription | ✅ Complete | `premium_annual`, $9.99/year |
| App Store Connect - Age Rating | ✅ Complete | 4+ rating |
| AppFactory dashboard | ✅ Complete | PostHog + RevenueCat keys added |

### What's Left (App Store Connect)

User is currently IN App Store Connect. Complete these sections:

1. **App Privacy**
   - Privacy Policy URL (required - user needs to provide or create)
   - Data Collection questionnaire

2. **Version Information**
   - Screenshots (need to capture from Simulator)
   - App Description
   - Keywords
   - Support URL
   - What's New text

3. **Review Information**
   - Contact info for App Review
   - Notes for reviewer

4. **Build Upload** (after metadata complete)

---

## Decisions Made

| Decision | Why | Alternative Rejected |
|----------|-----|---------------------|
| PostHog for analytics | Required per CLAUDE.md for all apps | N/A - mandatory |
| RevenueCat for IAP | User's standard stack, handles receipt validation | Native StoreKit - more complex |
| $9.99/year pricing | Defined in PRD | N/A |
| Account-level shared secret | User already has this set up across apps | App-specific secret |
| Bundle ID `com.pdfpages1.app` | User confirmed this is the final ID | N/A |

---

## Assumptions

| Assumption | What Breaks If Wrong |
|------------|----------------------|
| RevenueCat project connected to App Store Connect | Purchases won't validate - check In-App Purchase key in RevenueCat settings |
| Entitlement ID is exactly `premium` | Code won't recognize premium users - check `purchase_service.dart:7` |
| Product ID is exactly `premium_annual` | RevenueCat won't find the product - verify in RevenueCat Products section |
| User has Apple Developer account with signing | Build upload will fail - not a code issue |

---

## Trouble Spots

### If RevenueCat purchases don't work:
1. Check RevenueCat dashboard → Project Settings → App Store Connect API (is the P8 key uploaded?)
2. Check Products → verify `premium_annual` exists and is attached to `premium` entitlement
3. Check the shared secret is configured
4. In sandbox, use a sandbox tester account (Settings → Sandbox in App Store Connect)

### If PostHog events don't appear:
1. Events may take a few minutes to show in dashboard
2. Verify API key in `analytics_service.dart:5`
3. Check PostHog project is set to US region (host is `us.i.posthog.com`)

### If app crashes on PDF load:
1. Encrypted PDFs should show dialog - if crash, check `pdf_service.dart:42-48` exception handling
2. Memory issues with large PDFs - thumbnails are 150px, should be fine

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/services/purchase_service.dart` | RevenueCat integration, API key on line 5 |
| `lib/core/services/analytics_service.dart` | PostHog integration, API key on line 5 |
| `lib/features/extractor/presentation/widgets/paywall_sheet.dart` | Paywall UI |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Settings screen |
| `lib/main.dart` | App entry, PDF error dialog, settings navigation |

---

## AppFactory Dashboard

Added to `~/AppFactory/dashboard/.env.local`:
```
POSTHOG_PDF_PAGES_KEY=phx_gTS38on1YWbc5MZ4EiZza5Sak1EMwS42NownCq9hlN3tVIH
REVENUECAT_PDF_PAGES_KEY=sk_CmzMgUVWcczQYWEDESjFoMnTBltsA
APP_PDF_PAGES_BUNDLE_ID=com.pdfpages1.app
APP_PDF_PAGES_REVENUECAT_KEY=sk_CmzMgUVWcczQYWEDESjFoMnTBltsA
```

Note: `REVENUECAT_PDF_PAGES_PROJECT_ID` still needs to be added (find in RevenueCat URL).

---

## Next Session: Start Here

1. **Continue App Store Connect metadata** - user was in the middle of this
2. Ask: "Where did you leave off in App Store Connect? Privacy, Screenshots, or Description?"
3. Once metadata complete → bump version to build 7, archive, upload
4. Follow user's commit-before-upload protocol: commit, tag `build-7`, push, then upload

---

## Confidence Level

**Mechanical from here** - no design decisions remain. All code is complete and tested. Remaining work is:
- App Store Connect form-filling (user input needed for URLs, descriptions)
- Screenshot capture (run app in Simulator)
- Build upload (standard `flutter build ipa` + `xcrun altool`)
