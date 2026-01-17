# PDF Pages - Ralph Grandma Build Prompts

Autonomous build prompts for the PDF Pages app using the Ralph Grandma supervised agent framework.

**Estimated iterations:** 18-25 (one per user story, plus potential rework)
**Revenue model:** Free (3 extractions/month), $9.99/year unlimited
**Revenue ceiling:** $15-30K ARR

---

## Quick Start

### 1. Copy Ralph Grandma Scripts
Copy the Ralph Grandma scripts from WTHooperAI:
```bash
cp -r ~/Desktop/github\ clones/WTHooperAI/scripts/ralph/*.sh .
```

### 2. Run the Supervised Loop
```bash
./ralph-supervised.sh 25
```

This will:
- Run Ralph to implement one user story
- Have Grandma review the work
- Continue until all stories pass or Grandma PAUSEs

---

## File Structure

```
PDFExtractor-Build-Prompts/
├── README.md                    # This file
├── prd.json                     # Product requirements (18 user stories)
├── prompt-supervised.md         # Ralph's implementation instructions
├── grandma-review.md            # Grandma's review checklist
├── progress.txt                 # Ralph's implementation log (grows over time)
├── guidance.txt                 # Grandma's guidance for Ralph (updated each review)
├── ios-simulator-notes.md       # iOS Simulator optimization guide
├── mockups/                     # HTML UI mockups (review before coding!)
│   ├── 01-home-screen.html
│   ├── 02-page-grid.html
│   ├── 03-range-dialog.html
│   ├── 04-export-sheet.html
│   ├── 05-paywall.html
│   └── 06-settings.html
└── PROMPT-*.md                  # Original monolithic prompts (archived)
```

---

## User Stories Overview

| ID | Title | Complexity | Status |
|----|-------|------------|--------|
| PDF-001 | Project scaffolding | low | pending |
| PDF-002 | iOS permissions | low | pending |
| PDF-003 | PDF file picker | medium | pending |
| PDF-004 | PDF loading service | medium | pending |
| PDF-005 | Thumbnail generation | medium | pending |
| PDF-006 | Home screen UI | low | pending |
| PDF-007 | Page grid | medium | pending |
| PDF-008 | Tap-to-select | low | pending |
| PDF-009 | Range selection dialog | medium | pending |
| PDF-010 | Selection controls | low | pending |
| PDF-011 | Page extraction | high | pending |
| PDF-012 | Export/share | medium | pending |
| PDF-013 | Usage tracking | medium | pending |
| PDF-014 | Paywall UI | medium | pending |
| PDF-015 | RevenueCat | high | pending |
| PDF-016 | Encrypted PDF handling | medium | pending |
| PDF-017 | Settings screen | low | pending |
| PDF-018 | App Store prep | low | pending |

---

## Key Differentiator

**Privacy-first.** Unlike web tools (iLovePDF, Smallpdf), documents never leave the device. All processing is local.

---

## Technical Stack

- **Framework:** Flutter 3.x
- **State:** Riverpod
- **PDF Rendering:** pdfx
- **PDF Creation:** pdf
- **Payments:** RevenueCat
- **Target:** iOS Simulator (primary), Android (secondary)

---

## HTML Mockups

Open these in a browser before implementing UI stories:

1. **01-home-screen.html** - Main landing page with PDF icon
2. **02-page-grid.html** - 3-column thumbnail grid with selection
3. **03-range-dialog.html** - "1-5, 8, 11-15" range input
4. **04-export-sheet.html** - Success bottom sheet with share
5. **05-paywall.html** - Premium upgrade prompt
6. **06-settings.html** - Settings list with premium status

---

## iOS Simulator Testing

```bash
# Launch Simulator
open -a Simulator

# Run app
flutter run

# Add test PDFs
# Drag files into Simulator's Files app

# Test different sizes
# Simulator > File > Open Simulator > [device]
```

See `ios-simulator-notes.md` for detailed guidance.

---

## RevenueCat Setup

Before PDF-015:
1. Create project at app.revenuecat.com
2. Add iOS app (bundle: `com.quickhitter.pdfpages`)
3. Create subscription: `premium_annual` ($9.99/year)
4. Create entitlement: `premium`
5. Copy API keys to code

---

## Original Prompts (Archived)

The `PROMPT-*.md` files contain the original monolithic prompts. They're kept for reference but the Ralph Grandma framework uses `prd.json` instead.

---

*Created: January 2026*
*Framework: Ralph Grandma Supervised Agent*
