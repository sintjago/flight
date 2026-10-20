# Paper Glide — age-targeted learning packs

## Existing notebook flight and answer-gate loop — complete
- [x] Keep the folded paper plane in the hand-drawn notebook world; show a learning prompt in the bottom bar, label two answer gaps, award one point for the correct gap, and give the correct answer plus a hint after a wrong choice.

## Difficulty and curriculum progression — complete
- [x] “I am building this app for a kid that's 7 so focus on adding to 100, multiplication to 100, etc. for easy.” In Math level 1, use gentle addition/subtraction to 20, multiplication/division facts through 5, and simple halves. At level 2, extend addition/subtraction to 100, facts through 10×10, familiar fractions, place value, and number patterns. Challenge level changes question complexity and lane clearance; time between gates is controlled separately by flight pace.
- [x] “Then to more difficult for medium and high school math for hard.” Medium extends arithmetic and introduces fraction operations, decimals, percentages, ratios, and order of operations. Hard samples high-school integers, fraction operations, algebra, quadratics, powers, roots, right-triangle geometry, and trigonometry.

## Math topic teaching and feedback — complete
- [x] “I want it to teach addition, substraction, multiplication, division, fractions and more.” Identify the active math topic, show a concise solving hint with each prompt, and include the answer plus hint when a wrong choice ends the run.

## Multi-topic Math content selection — complete
- [x] Show readable checkboxes for individually selectable math subjects, including addition, subtraction, multiplication, division, fractions, and more. Allow multiple checked subjects; label higher-level subjects with their unlock level, explain when checked subjects are not yet available, and only generate prompts from the learner's selected, currently available subjects.

## Crash recovery choices — complete
- [x] After a crash, show Try Again at the same settings, Lower Difficulty & Retry (decrease the selected pack's challenge by one step and immediately start a fresh run), and Home. Disable Lower Difficulty at level 1 and, for Math, when lowering would leave none of the learner's selected subjects available. Returning Home preserves the current learning area, Math subjects, challenge, and separate flight pace.

## Staged practice-area choice — complete
- [x] First ask what the learner wants to practice: Math, Reading, Russian, Spanish, or Science. All five areas now open playable question packs. Math has its own subject-selection step; Reading, Russian, Spanish, and Science proceed directly to challenge level.

## Separate Math subject-selection page — complete
- [x] After Math is selected, open a separate page asking which math subject to practice, including addition, multiplication, subtraction, division, and other available math topics. Use checkboxes so multiple subjects can be selected; allow navigating back without losing choices.

## Five-point age-targeted challenge — complete
- [x] After selecting Math subjects, or selecting any other learning pack, show a separate 1–5 Likert-style challenge choice. Preserve the chosen learning area and subject selection while navigating between setup steps and into a run.

## Separate flight-speed setup and default pacing — complete
- [x] After challenge level, show a separate flight-speed choice, independent of learning difficulty. The default must be slower and place the answer gates farther apart than the existing default; keep the user's speed choice through back-navigation, retry, and Home.

## Expanded Math knowledge content — complete
- [x] “add the missing math content.” Expand the existing Math pack without changing its staged flow. Add age-stepped measurement, basic probability, and data/statistics; broaden geometry from a single right-triangle formula to age-appropriate shape, perimeter/area, angle, and high-school content; include multiplication and division of fractions in advanced levels; and give higher-level algebra/trigonometry more than one prompt form. At higher levels, progress decimals into multiplication/division, percentages into increases/discounts/reverse-percent questions, ratios into unit rates and word proportions, and order of operations into exact division and powers. Every category respects its unlock level and checkbox, includes a learner-facing hint, has a mathematically correct answer and a distinct wrong choice, and is covered by the existing gameplay checks.

## Procedural question engines for all learning packs — complete
- [x] Generate varied questions at run time for Math, Reading, Russian, Spanish, and Science instead of depending on the small authored bank for continued play. Math questions vary their numbers and forms within the selected, unlocked topic. Reading, Russian, Spanish, and Science combine age-appropriate templates with varied words, sentence contexts, grammar forms, or scientific measurements to create large combinatorial question spaces. Track prompts per run and use adaptive randomized search to avoid previously seen prompts; if a fresh prompt cannot be found, begin another randomized cycle without immediately repeating the last prompt. Preserve the curated starter content, five challenge levels, selected Math topics, two distinct choices with exactly one correct answer, learner-facing topic and hint, and answer-plus-hint feedback. Keep Science levels 1–2 grounded in concrete everyday observations and basic vocabulary; reserve specialized terminology for higher levels.

## Fair question and Math-topic rotation — complete
- [x] During a run, use per-pack/topic-and-level prompt history and adaptive search to avoid repeats while fresh variants can be found; if none is found, begin a new randomized cycle without an immediate repeat. In Math, rotate through the selected topics unlocked at the chosen challenge level before repeating a topic. Reset all prompt and topic histories for each new run.

## Subject-specific best scores — complete
- [x] Keep local best scores separate by learning area and Easy/Medium/Hard challenge band. Migrate earlier Math scores into the Math pack and preserve the overall-best record and games-played count.
