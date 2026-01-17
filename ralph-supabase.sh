#!/bin/bash
# Ralph Supabase - Run Ralph on the Supabase Client Integration PRD
# Usage: ./ralph-supabase.sh [max_iterations]

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd-supabase-client.json"
PROGRESS_FILE="$SCRIPT_DIR/progress-supabase.txt"
GUIDANCE_FILE="$SCRIPT_DIR/guidance-supabase.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize progress file
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Supabase Client Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "PRD: prd-supabase-client.json" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Initialize guidance file with Supabase context
if [ ! -f "$GUIDANCE_FILE" ]; then
  cat > "$GUIDANCE_FILE" << 'EOF'
# Grandma's Guidance - Supabase Client Integration

## Context
The Supabase database has been fully set up with 14 tables. Ralph needs to create the TypeScript client integration in the Expo app.

## Database Info
- URL: https://zlwxryknejehdbmhexvw.supabase.co
- 14 tables ready: exercises, exercise_details, programs, program_schedule, iq_categories, iq_subcategories, iq_videos, iq_challenges, skill_taxonomy, content_sources, game_stat_config, benchmark_standards, earworm_config, trainer_roles
- RLS enabled with public read access
- Helper functions: get_next_exercise_id(), find_exercises_by_attributes()
- Database is currently EMPTY (no data yet) - test queries returning [] is expected

## Key Implementation Notes
- AsyncStorage is ALREADY installed (v2.2.0) - don't reinstall it
- Project uses path aliases: @services/*, @types/* (see tsconfig.json)
- Supabase credentials go in .env file (see SUP-002 for exact values)
- Schema reference for types: /Users/johncarter/Desktop/WTHooperAI#1 folder/prompt_5_supabase_schema.md
- IMPORTANT: Import 'react-native-url-polyfill/auto' BEFORE importing Supabase

## Guidance for First Iteration
Start with SUP-001 (install dependencies). Run:
  npx expo install @supabase/supabase-js react-native-url-polyfill

Then proceed through SUP-002 to SUP-008 in order.
EOF
fi

echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║  Ralph Supabase Client Integration                        ║${NC}"
echo -e "${PURPLE}║  PRD: prd-supabase-client.json                            ║${NC}"
echo -e "${PURPLE}║  Max iterations: $MAX_ITERATIONS                                       ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create a modified prompt for Supabase PRD
RALPH_PROMPT="# Ralph Agent Instructions (Supabase Client Integration)

You are Ralph, working on the Supabase Client Integration for the WTHooperAI Expo app.

## IMPORTANT: Read Guidance First!
Read \`guidance-supabase.txt\` in this directory for database context and implementation notes.

## Your Task
1. **Read guidance-supabase.txt** - Contains database info and implementation tips
2. Read the PRD at \`prd-supabase-client.json\` (NOT prd.json!)
3. Read \`progress-supabase.txt\` for previous progress
4. Check you're on branch \`feat/supabase-client\`. Create from main if needed.
5. Pick the **highest priority** user story where \`passes: false\`
6. Implement that single user story
7. Run typecheck: \`npx tsc --noEmit\`
8. If checks pass, commit with: \`feat: [Story ID] - [Story Title]\`
9. Update prd-supabase-client.json to set \`passes: true\`
10. Append progress to \`progress-supabase.txt\`

## Progress Report Format
APPEND to progress-supabase.txt:
\`\`\`
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- Any issues encountered
---
\`\`\`

## Stop Condition
After completing a story, check if ALL stories have \`passes: true\`.
If ALL complete: reply with <promise>COMPLETE</promise>
If more stories remain: end normally for next iteration.

## Important Reminders
- Use prd-supabase-client.json, NOT prd.json
- AsyncStorage is already installed - don't reinstall
- Use path aliases: @services/*, @types/*
- Test queries will return [] (empty) - database has no data yet, that's OK
"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Ralph Supabase Iteration $i of $MAX_ITERATIONS${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

  # Ralph does his work
  echo -e "${GREEN}Ralph is working on Supabase integration...${NC}"
  RALPH_OUTPUT=$(cd /Users/johncarter/Documents/GitHub/WTHooperAI && claude --model sonnet --dangerously-skip-permissions --print "$RALPH_PROMPT" 2>&1 | tee /dev/stderr) || true

  # Check if Ralph says all done
  if echo "$RALPH_OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Supabase Client Integration Complete!${NC}"
    echo -e "${GREEN}  Finished at iteration $i of $MAX_ITERATIONS${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    exit 0
  fi

  echo ""
  echo -e "${YELLOW}───────────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}  Grandma is reviewing Supabase iteration $i...${NC}"
  echo -e "${YELLOW}───────────────────────────────────────────────────────────${NC}"

  # Grandma reviews (using the standard grandma-review.md but pointing to Supabase files)
  GRANDMA_PROMPT="# Grandma's Review - Supabase Client Integration

Review Ralph's Supabase integration work.

## Files to Check
1. \`prd-supabase-client.json\` - Which SUP story was Ralph working on?
2. \`progress-supabase.txt\` - What did Ralph say he did?
3. \`guidance-supabase.txt\` - Did Ralph follow the guidance?
4. Run \`git log -1 --stat\` - What files changed?
5. Run \`git diff HEAD~1\` - What are the actual changes?

## Assess the Work
- Did Ralph use the correct PRD (prd-supabase-client.json)?
- Are the TypeScript types correct?
- Did he use path aliases (@services/*, @types/*)?
- Did he import react-native-url-polyfill/auto first?
- Any obvious bugs?

## Update guidance-supabase.txt
Add your assessment and any corrections needed.

## Response
End with exactly ONE of:
- \`<grandma>CONTINUE</grandma>\` - Work looks good
- \`<grandma>PAUSE</grandma>\` - Needs human attention
"

  GRANDMA_OUTPUT=$(cd /Users/johncarter/Documents/GitHub/WTHooperAI && claude --model sonnet --dangerously-skip-permissions --print "$GRANDMA_PROMPT" 2>&1 | tee /dev/stderr) || true

  if echo "$GRANDMA_OUTPUT" | grep -q "<grandma>PAUSE</grandma>"; then
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Grandma says: HOLD UP!${NC}"
    echo -e "${RED}  Check guidance-supabase.txt for details.${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    exit 1
  fi

  if echo "$GRANDMA_OUTPUT" | grep -q "<grandma>CONTINUE</grandma>"; then
    echo -e "${GREEN}Grandma approves. Continuing...${NC}"
  fi

  sleep 2
done

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Reached max iterations ($MAX_ITERATIONS)${NC}"
echo -e "${YELLOW}  Check progress-supabase.txt${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
exit 1
