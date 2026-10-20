# Paper Glide — age-targeted math curriculum revision

## Existing notebook flight and answer-gate loop — complete
- [x] Keep the folded paper plane in the hand-drawn notebook world; show an equation in the bottom bar, label two answer gaps, award one point for the correct gap, and give the correct answer after a wrong choice.

## Difficulty and curriculum progression — complete
- [x] “I am building this app for a kid that's 7 so focus on adding to 100, multiplication to 100, etc. for easy.” At level 1, use gentle addition/subtraction to 20, multiplication/division facts through 5, and simple halves. At level 2, extend addition/subtraction to 100, facts through 10×10, familiar fractions, place value, and number patterns. Challenge level changes math complexity and lane clearance; time between gates is controlled separately by flight pace.
- [x] “Then to more difficult for medium and high school math for hard.” Medium extends arithmetic and introduces fraction operations, decimals, percentages, ratios, and order of operations. Hard samples high-school integers, fraction operations, algebra, quadratics, powers, roots, right-triangle geometry, and trigonometry.

## Topic teaching and feedback — complete
- [x] “I want it to teach addition, substraction, multiplication, division, fractions and more.” Identify the active math topic, show a concise solving hint with each prompt, and include the answer plus hint when a wrong choice ends the run.

## Earlier difficulty selector — complete (superseded by the staged setup below)
- [x] Replace the three-button selector with a visible, labeled 0–10 slider. The selected value and Easy/Medium/Hard band are shown. Difficulty changes question band plus flight speed, lane clearance, and gate spacing.

## Multi-topic content selection — complete
- [x] Show readable checkboxes for individually selectable math subjects, including addition, subtraction, multiplication, division, fractions, and more. Allow multiple checked subjects; label higher-level subjects with their unlock level, explain when checked subjects are not yet available, and only generate prompts from the learner's selected, currently available subjects.

## Crash recovery choices — complete
- [x] After a crash, show Try Again at the same settings, Lower Difficulty & Retry (decrease the math challenge by one step and immediately start a fresh run), and Home. Disable Lower Difficulty at level 1 and when lowering would leave none of the learner's selected subjects available. Returning Home preserves the math subjects, challenge, and separate pace.

## Staged practice-area choice — complete
- [x] First ask what the learner wants to practice: Math, Reading, Russian, Spanish, or Science. Math is the available knowledge pack now; clearly mark the other practice areas as coming soon rather than imply their packs are already playable.

## Separate Math subject-selection page — complete
- [x] After Math is selected, open a separate page asking which math subject to practice, including addition, multiplication, subtraction, division, and other available math topics. Use checkboxes so multiple subjects can be selected; allow navigating back without losing choices.

## Five-point math difficulty — complete
- [x] After selecting math subjects, show a separate 1–5 Likert-style difficulty choice. Preserve the chosen subject selection while navigating between setup steps and into a run.

## Separate flight-speed setup and default pacing — complete
- [x] After difficulty, show a separate flight-speed choice, independent of math difficulty. The default must be slower and place the answer gates farther apart than the existing default; keep the user's speed choice through back-navigation, retry, and Home.

## Expanded math knowledge content — complete
- [x] “add the missing math content.” Expand the existing Math pack without changing the staged practice flow. Add age-stepped measurement, basic probability, and data/statistics; broaden geometry from a single right-triangle formula to age-appropriate shape, perimeter/area, angle, and high-school content; include multiplication and division of fractions in advanced levels; and give higher-level algebra/trigonometry more than one prompt form. At higher levels, progress decimals into multiplication/division, percentages into increases/discounts/reverse-percent questions, ratios into unit rates and word proportions, and order of operations into exact division and powers. Every new category must respect its unlock level and checkbox, include a learner-facing hint, have a mathematically correct answer and a distinct wrong choice, and be covered by the existing gameplay checks.