# PDF Pages - Session Handoff

## Current State
**Build 16** deployed to TestFlight (Jan 30, 2026)
- All code committed and pushed to `origin/master`
- Debug logging added to voice parser

## Problem Being Debugged

Voice parser bugs reported by user - commands not working on device despite passing unit tests:

1. **"extract pages 2, 4, and 6"** → Only selected page 6 (should select all three)
2. **"save as purple PDF"** → Saved as "Page 6" instead of "purple"

### What We Know
- All 34 unit tests pass, including specific tests for these exact phrases
- Parser logic in `speech_service.dart` is correct
- The issue is happening on the physical device, not in tests

### Likely Causes (in order of probability)
1. **Speech recognition returning different text** - iOS may transcribe differently than expected (e.g., "page 6" instead of "pages 2, 4, and 6")
2. **Timing issue** - Transcription comes incrementally; command may execute on partial text
3. **Previous build still running** - TestFlight might not have updated properly

### Debug Logging Added
Build 16 includes extensive logging in `lib/core/services/speech_service.dart:156-180`:
```
[VoiceParser] Raw input: "..."
[VoiceParser] Normalized: "..."
[VoiceParser] saveAsMatch: matched/no match
[VoiceParser] extractPagesMatch: matched/no match
[VoiceParser] Returning selectPages with: {...}
```

## Next Steps

1. **Install Build 16 from TestFlight**
2. **Test the failing commands** while watching logs:
   - Connect phone to Mac
   - Open Console.app, filter by "VoiceParser"
   - Try "extract pages 2, 4, and 6"
   - Try "save as purple PDF"
3. **Analyze logs** to see what speech recognition actually returns
4. **Fix based on findings** - likely need to handle speech-to-text quirks

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/services/speech_service.dart` | Voice command parsing (debug logs here) |
| `lib/core/services/voice_command_handler.dart` | Executes parsed commands |
| `lib/features/extractor/presentation/widgets/voice_input_sheet.dart` | UI for voice input |
| `lib/features/extractor/presentation/screens/page_grid_screen.dart` | Main page grid screen |
| `test/speech_service_test.dart` | Unit tests for parser |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Add debug logging vs blind fixes | Tests pass, so we need to see actual device behavior |
| Keep debug logs in release build | They go to system log, not visible to users, needed for diagnosis |
| Return `selectPages` for "extract pages X" | Handler then selects pages; user can tap Extract button |

## Assumptions

- iOS speech recognition is the variable - it may transcribe numbers/phrases differently
- The 2-second silence timeout is working correctly (tested in unit tests)
- TestFlight distribution is working (user can install Build 16)

## After Debugging

Once we identify the root cause from logs:
1. Add handling for whatever speech patterns iOS actually produces
2. Add unit tests for those patterns
3. Remove debug logging (or reduce verbosity)
4. Create Build 17 for final testing
5. Continue with App Store screenshots and submission

## Other Pending Work

- [ ] App Store screenshots (iPhone 6.7", iPad 13")
- [ ] App Store Connect metadata (description, keywords)
- [ ] Final submission for review
