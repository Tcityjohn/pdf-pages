#!/bin/bash
# Ralph Supervised - AI agent loop with Grandma watching
# Usage: ./ralph-supervised.sh [max_iterations]
#
# Ralph does the work. Grandma reviews each iteration and can:
# - Leave guidance for the next iteration
# - PAUSE the loop if something needs human attention
# - Course-correct before mistakes compound

set -e

# Authentication: Claude CLI can use either API credits or Max subscription
# - If you have a Max plan: set RALPH_USE_SUBSCRIPTION=true to use it instead of API credits
# - If you only have API credits: leave ANTHROPIC_API_KEY set (default behavior)
if [[ "${RALPH_USE_SUBSCRIPTION:-true}" == "true" ]]; then
  unset ANTHROPIC_API_KEY
  echo "Using Max subscription (RALPH_USE_SUBSCRIPTION=true)"
fi

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
GUIDANCE_FILE="$SCRIPT_DIR/guidance.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo -e "${YELLOW}Archiving previous run: $LAST_BRANCH${NC}"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$GUIDANCE_FILE" ] && cp "$GUIDANCE_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset files for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"

    echo "# Grandma's Guidance" > "$GUIDANCE_FILE"
    echo "Started: $(date)" >> "$GUIDANCE_FILE"
    echo "---" >> "$GUIDANCE_FILE"
    echo "" >> "$GUIDANCE_FILE"
    echo "No guidance yet. First iteration starting fresh." >> "$GUIDANCE_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Initialize guidance file if it doesn't exist
if [ ! -f "$GUIDANCE_FILE" ]; then
  echo "# Grandma's Guidance" > "$GUIDANCE_FILE"
  echo "Started: $(date)" >> "$GUIDANCE_FILE"
  echo "---" >> "$GUIDANCE_FILE"
  echo "" >> "$GUIDANCE_FILE"
  echo "No guidance yet. First iteration starting fresh." >> "$GUIDANCE_FILE"
fi

echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║  Ralph Supervised - Grandma's Watching                    ║${NC}"
echo -e "${PURPLE}║  Max iterations: $MAX_ITERATIONS                                       ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Ralph Iteration $i of $MAX_ITERATIONS${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

  # Read the prompt file
  RALPH_PROMPT=$(cat "$SCRIPT_DIR/prompt-supervised.md")

  # Ralph does his work
  echo -e "${GREEN}Ralph is working...${NC}"
  RALPH_OUTPUT=$(claude --model sonnet --dangerously-skip-permissions --print "$RALPH_PROMPT" 2>&1 | tee /dev/stderr) || true

  # Check if Ralph says all done
  if echo "$RALPH_OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Ralph completed all tasks!${NC}"
    echo -e "${GREEN}  Finished at iteration $i of $MAX_ITERATIONS${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    exit 0
  fi

  echo ""
  echo -e "${YELLOW}───────────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}  Grandma is reviewing iteration $i...${NC}"
  echo -e "${YELLOW}───────────────────────────────────────────────────────────${NC}"

  # Grandma reviews
  GRANDMA_PROMPT=$(cat "$SCRIPT_DIR/grandma-review.md")
  GRANDMA_OUTPUT=$(claude --model sonnet --dangerously-skip-permissions --print "$GRANDMA_PROMPT" 2>&1 | tee /dev/stderr) || true

  # Check if Grandma says to pause
  if echo "$GRANDMA_OUTPUT" | grep -q "<grandma>PAUSE</grandma>"; then
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Grandma says: HOLD UP!${NC}"
    echo -e "${RED}  Something needs human attention.${NC}"
    echo -e "${RED}  Check guidance.txt for details.${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    exit 1
  fi

  # Check if Grandma says things look good
  if echo "$GRANDMA_OUTPUT" | grep -q "<grandma>CONTINUE</grandma>"; then
    echo -e "${GREEN}Grandma approves. Continuing...${NC}"
  fi

  echo ""
  echo -e "${BLUE}Iteration $i complete. Moving to next...${NC}"
  sleep 2
done

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Ralph reached max iterations ($MAX_ITERATIONS)${NC}"
echo -e "${YELLOW}  Not all tasks completed. Check progress.txt${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
exit 1
