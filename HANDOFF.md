# PDF Pages Handoff - 2026-02-04

## Current State

App has been **submitted for App Store review**. All code, screenshots, and metadata are complete.

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
| Privacy Policy | ✅ Complete | `https://tcityjohn.github.io/pdf-pages/privacy` |
| App Store Screenshots | ✅ Complete | 6 iPhone (6.7") + 3 iPad (12.9") |
| App Store submission | ✅ Submitted | In review as of 2026-02-04 |

### Screenshots

6 iPhone screenshots in `screenshots/`:
1. `01_final.png` — "Extract Any Pages"
2. `02_final.png` — "Visual Page Grid"
3. `03_final.png` — "Tap or Say It"
4. `04_final.png` — "100% Private"
5. `05_final.png` — "Your Way, Your Rules" (Settings)
6. `06_final.png` — "Go Unlimited" (Paywall)

3 iPad screenshots: `ipad_01_final.png` through `ipad_03_final.png`

All generated via `export-screenshots.sh` / `export-ipad.sh` (Chrome headless + HTML mockups).

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
| `lib/features/settings/presentation/screens/settings_screen.dart` | Settings screen, privacy URL on line 41 |
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

1. **Check App Store review status** — app was submitted 2026-02-04
2. If rejected: read rejection notes, fix, resubmit
3. If approved: verify app is live, test purchase flow with sandbox account, confirm PostHog events flowing

---

## Confidence Level

**Done.** App is submitted. Only remaining action is responding to App Review if they flag anything.
