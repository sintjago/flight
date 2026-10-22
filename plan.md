# Paper Dungeon: dungeon-crawler implementation plan

## Scope
Replace the one-tap flying loop with a small, turn-based top-down dungeon crawler. Keep the project, paper/notebook palette, five learning areas, Math 1/2/3 track choice, five challenge levels, question generators and content, local coins, cheers, per-subject best scores, answer review and offline PDF export. The explicit user choice is turn-based. The approved gameplay blueprint could not be reopened in this session; this plan records the new scope from the user’s request and will be saved with the implementation.

## Core loop
1. Keep the learning setup: select Math, Reading, Russian, Spanish or Science; choose a Math track where applicable; choose challenge 1–5. Remove the flight-speed step because a turn-based dungeon has no movement timer.
2. Explore one hand-drawn room at a time on a small tile grid with arrow/WASD movement. Stepping next to a foe starts its encounter; entering an unlocked exit advances to the next room. No movement timer or touch-control expansion is added.
3. Each encounter opens the selected learning pack’s existing two-choice question. Answer buttons are directly visible and also keyboard-selectable. Correct answers defeat/damage the foe, add score and one coin, and show the equipped cheer. Incorrect answers record the choice, show the correct answer and hint, and cost one of three hearts; no timer or instant failure.
4. Clear three connected chambers and a final guardian. Rooms have clear routes, a visible exit, and readable state; completing the guardian is a win. Losing all hearts is defeat. Both outcomes offer answer review, restart, lower challenge, and Home.
5. Keep the existing learning review and PDF export, replacing flight-specific report context with score, subject/track/challenge, rooms cleared, and date.

## Progression and compatibility
- Re-theme the existing owned plane IDs as cosmetic paper-adventurer styles in the Hangar/wardrobe; do not migrate, delete, or reset save records, prices, balances, equipment, cheers, or best scores.
- Preserve all five question engines, Math topic rotation and selected track, learner-facing hints, per-run prompt history, accuracy, and two distinct choices with one correct answer. Do not add a timer or alter correct-answer rewards.
- Keep visual style separate from authoritative combat state, question correctness, score, and rewards.

## Visual direction
A quiet notebook-paper playfield with inked room borders, hand-drawn doors, floor marks, and visible movement silhouettes. Use original transparent pen-drawn art for the hero and distinct foes (including a readable final guardian), retaining high-contrast outlines at in-game size. Reuse fitting notebook assets and the existing interface palette; do not reuse flight pipes/clouds as dungeon obstacles.

## Implementation approach
Add an isolated `DungeonWorld` owning room grid, turn state, hearts, enemy state, question generation, scoring, and answer history. Adapt the current main controller for dungeon controls, HUD, wardrobe, pause and results without rewriting the learning engines or PDF builder. Keep legacy flight code/tests only where they remain useful as regression coverage.
