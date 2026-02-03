# PDF Pages

## What This Is

Privacy-first PDF page extractor. Users select pages from a PDF and extract them into a new document - all processing happens on-device, never in the cloud. Freemium model: 3 extractions/month free, $9.99/year unlimited. Revenue ceiling: $15-30K ARR.

Bundle ID: `com.quickhitter.pdfpages` | Stage: Early-to-mid development (Ralph-driven build)

## Architecture

### Core Abstractions

1. **PDF Service** - Load PDFs, generate thumbnails, extract page ranges using `pdfx` (rendering) and `pdf` (creation).
2. **Page Selection UI** - 3-column thumbnail grid with tap-to-select and range input dialog ("1-5, 8, 11-15").
3. **Usage Tracking** - Local counter for freemium enforcement (3/month free tier).
4. **RevenueCat Paywall** - Premium subscription for unlimited extractions.

### Data Flow

```
User picks PDF (file picker) → PDF loaded + thumbnails generated
→ User selects pages (tap or range input) → Extract selected pages
→ New PDF created locally → Export/share sheet → Usage counter incremented
```

### Load-Bearing Walls

- **On-device processing** - The privacy claim IS the differentiator. No cloud processing, ever.
- **PDF rendering accuracy** - Thumbnails and extraction must handle all PDF variants (encrypted, large, image-heavy).

### Grain of the Codebase

- **Easy to change:** UI styling, extraction limits, pricing.
- **Structural:** PDF rendering pipeline, on-device extraction logic.

## Decisions

### Local-Only Processing
- **Chose:** All PDF processing on-device
- **Over:** Cloud processing (faster, handles large files better)
- **Because:** Privacy is the entire value proposition vs. iLovePDF/Smallpdf.
- **Revisit if:** Never. This is the product identity.

## Current State

### In Flux
- 18 user stories planned (PDF-001 through PDF-018), being built via Ralph
- Check `prd.json` for current story completion status
- HTML mockups in `mockups/` directory for UI reference

### Known Debt
- RevenueCat setup needed before PDF-015 (create project, add iOS app, create subscription)
- App Store prep (PDF-018) is the final story

## Project-Specific Conventions

- Flutter 3.x + Dart + Riverpod
- pdfx for rendering, pdf for creation
- RevenueCat for payments, PostHog for analytics
- Ralph Grandma framework for automated build
- See `README.md` for full story breakdown and build instructions
