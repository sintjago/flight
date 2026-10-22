# Paper Glide — age-targeted learning packs

## Existing notebook flight and answer-gate loop — complete
- [x] Keep the folded paper plane in the hand-drawn notebook world; show a learning prompt in the bottom bar, label two answer gaps, award one point for the correct gap, and give the correct answer plus a hint after a wrong choice.

## Difficulty and curriculum progression — complete
- [x] “I am building this app for a kid that's 7 so focus on adding to 100, multiplication to 100, etc. for easy.” In Math level 1, use gentle addition/subtraction to 20, multiplication/division facts through 5, and simple halves. At level 2, extend addition/subtraction to 100, facts through 10×10, familiar fractions, place value, and number patterns. Challenge level changes question complexity and lane clearance; time between gates is controlled separately by flight pace.
- [x] “Then to more difficult for medium and high school math for hard.” Medium extends arithmetic and introduces fraction operations, decimals, percentages, ratios, and order of operations. Hard samples high-school integers, fraction operations, algebra, quadratics, powers, roots, right-triangle geometry, and trigonometry.

## Math topic teaching and feedback — complete
- [x] “I want it to teach addition, substraction, multiplication, division, fractions and more.” Identify the active math topic, show a concise solving hint with each prompt, and include the answer plus hint when a wrong choice ends the run.

## Three-track Math selection — complete
- [x] Replace the long topic-checkbox list with a single-select Math 1/2/3 choice: Math 1 Foundations (addition, subtraction, multiplication/division facts, halves, place value, and patterns); Math 2 Middle School (fractions, decimals, percentages, ratios, measurement, geometry, probability/data, integers, order of operations, and introductory algebra); Math 3 High School (algebra, quadratics, powers/roots, advanced geometry/trigonometry, statistics, and probability). Keep the 1–5 challenge as a separate step, preserve the selected track through navigation and Home, and generate only topics available to that track at the chosen challenge level.

## Crash recovery choices — complete
- [x] After a crash, show Try Again at the same settings, Lower Difficulty & Retry (decrease the selected pack's challenge by one step and immediately start a fresh run), and Home. Disable Lower Difficulty at level 1 and, for Math, when lowering would leave no topics in the selected track available. Returning Home preserves the current learning area, Math track, challenge, and separate flight pace.

## Staged practice-area choice — complete
- [x] First ask what the learner wants to practice: Math, Reading, Russian, Spanish, or Science. All five areas now open playable question packs. Math has its own single-select track step; Reading, Russian, Spanish, and Science proceed directly to challenge level.

## Separate Math track-selection page — complete
- [x] After Math is selected, show three clear course cards—Math 1 Foundations, Math 2 Middle School, and Math 3 High School—instead of a long checklist. Select exactly one track and allow navigating back without losing the choice.

## Five-point age-targeted challenge — complete
- [x] After selecting a Math track, or selecting any other learning pack, show a separate 1–5 Likert-style challenge choice. Preserve the chosen learning area and track while navigating between setup steps and into a run.

## Separate flight-speed setup and default pacing — complete
- [x] After challenge level, show a separate flight-speed choice, independent of learning difficulty. The default must be slower and place the answer gates farther apart than the existing default; keep the user's speed choice through back-navigation, retry, and Home.

## Expanded Math knowledge content — complete
- [x] “add the missing math content.” Expand the existing Math pack without changing its staged flow. Add age-stepped measurement, basic probability, and data/statistics; broaden geometry from a single right-triangle formula to age-appropriate shape, perimeter/area, angle, and high-school content; include multiplication and division of fractions in advanced levels; and give higher-level algebra/trigonometry more than one prompt form. At higher levels, progress decimals into multiplication/division, percentages into increases/discounts/reverse-percent questions, ratios into unit rates and word proportions, and order of operations into exact division and powers. Every category respects its unlock level and selected track, includes a learner-facing hint, has a mathematically correct answer and a distinct wrong choice, and is covered by the existing gameplay checks.

## Procedural question engines for all learning packs — complete
- [x] Generate varied questions at run time for Math, Reading, Russian, Spanish, and Science instead of depending on the small authored bank for continued play. Math questions vary their numbers and forms within the selected track's currently available topics. Reading, Russian, Spanish, and Science combine age-appropriate templates with varied words, sentence contexts, grammar forms, or scientific measurements to create large combinatorial question spaces. Track prompts per run and use adaptive randomized search to avoid previously seen prompts; if a fresh prompt cannot be found, begin another randomized cycle without immediately repeating the last prompt. Preserve the curated starter content, five challenge levels, selected Math track, two distinct choices with exactly one correct answer, learner-facing topic and hint, and answer-plus-hint feedback. Keep Science levels 1–2 grounded in concrete everyday observations and basic vocabulary; reserve specialized terminology for higher levels.

## Fair question and topic rotation — complete
- [x] During a run, use per-pack/topic-and-level prompt history and adaptive search to avoid repeats while fresh variants can be found; if none is found, begin a new randomized cycle without an immediate repeat. In Math, rotate through the selected track's topics unlocked at the chosen challenge level before repeating a topic. In Reading, Russian, Spanish, and Science, sample up to 64 unique candidates to prefer a different generator category, falling back to curated topic labels where needed; levels with no alternative found are cached to avoid repeated search work. Reset all prompt, category, and topic histories for each new run.

## Engine accuracy and advertised progression — complete
- [x] Keep every generated question accurate, natural, and appropriate to its selected pack and challenge level. Level 3 Math statistics must not introduce negative values before the integers topic unlocks. Level 5 Science must use its promised high-school biology, chemistry, and physics content rather than falling back to basic classification. Level 5 Russian must practice conditional meaning and verb aspect, and Level 5 Spanish must practice subjunctive and conditional forms as described on the setup screen. Keep generated Reading wording grammatical.

## Math topic progression audit — complete
- [x] Keep Level 1 fraction practice within simple halves. Make number sense progress beyond two-digit place value and small patterns after Level 2, with age-stepped content at the higher challenge levels: later levels extend place value and patterns, Level 4 adds rounding, and Level 5 expands scientific notation. Regression checks validate the fractions, place values, rounding, and expanded numbers.

## Reading content audit — complete
- [x] Ensure generated synonym and antonym relations are accurate. Make Reading Levels 3–5 practice the advertised inference, main-idea, evidence, theme, and author-purpose skills rather than relying mainly on literal recall and figure-of-speech identification. Reviewed the word pairs and added relation/answer regression checks; Level 3 generates inference and main-idea items, Level 4 uses text evidence, and Level 5 practices author purpose and theme.

## Russian and Spanish topic/level alignment audit — complete
- [x] Match vocabulary-versus-phrase labels and hints to the selected target-language content, not to English prompt wording. Correct the mismatched curated starter labels, keep Russian Level 2 within its advertised beginner scope, clarify the vehicle meaning of ехать, and provide Spanish conditional and formal-address practice at Level 4. Regression checks validate target-word/phrase labels and hints, Russian Level 2 vocabulary, ехать, and Level 4 Spanish grammar.

## Science beginner coverage and prompt clarity audit — complete
- [x] Use grammatical plant-part question stems and include everyday states of matter in the generated Level 1 Science mix alongside animals, plants, and senses. Beginner prompts stay concrete, use age-appropriate plant functions, and avoid specialist plant terminology; coverage and wording have regression checks.

## Subject-specific best scores — complete
- [x] Keep local best scores separate by learning area and Easy/Medium/Hard challenge band. Migrate earlier Math scores into the Math pack and preserve the overall-best record and games-played count.

## Local coin economy and plane hangar — complete
- [x] Award one gameplay coin for each correctly passed answer gate in any learning pack, persist the balance locally with backward-compatible saves, and show the wallet on Home, in flight, and on results. Provide a Hangar from the title screen where the free starter plane remains usable; Blue Sketch, Coral Kite, and Golden Fold cost 10, 20, and 35 coins. Buying equips the colorway, later selection works, and the 10-coin purchase, saved ownership/equipment, and version-five-save migration are regression-tested. No real-money purchases; plane tint is cosmetic and does not alter flight physics, collision, or scoring.

## Correct-answer praise unlocks — complete
- [x] After each correctly passed answer gate, show a brief readable celebration phrase. Include selectable, coin-unlocked “Banzai!” and “¡Excelente!” cheers, preserve the “Nice flying!” English default, and save cheer ownership/selection locally. The cue does not alter answer correctness, scoring, or coin rewards; save, Hangar, and real-gate tests cover the full flow.

## Distinct unlockable aircraft — complete
- [x] Expand the Hangar with three additional, visibly distinct paper-craft ship designs beyond color tints; show a preview, name, unlock price, and equipped/owned/locked state. Earned coins buy and equip ships, owned ships can be reselected, and selections persist through existing saves. Every aircraft remains cosmetic: preserve the flight simulation, collision size, and scoring; save, Hangar, renderer, and packaged-art checks cover the additions.

## Folded-paper silhouette refinement — complete
- [x] Replace the paid options' near-duplicate/sci-fi-looking art with a broad delta-wing Kite Glider, swept Sailwing, and compact Comet Dart, each with transparent pencil-fold artwork and a short style caption. The Hangar now describes all seven designs/colorways and clarifies that handling is identical. Preserve every existing plane ID, price, ownership, equipped state, and save; keep the fixed flight/collision behavior. A real-renderer Hangar capture confirms the three silhouettes and labels fit the 1280×720 screen.

## Post-flight answer review — complete
- [x] When a flight ends, allow the player to open a page showing all questions from that flight in order, the answer they chose (or that they did not answer), the correct answer, and whether the response was right, wrong, or unanswered. Keep the review available until the player returns to the results screen or leaves for Home. Render the original question and answers legibly for every learning pack, including Russian/Cyrillic text. Always allow the page to open; when no gate was reached, show a clear empty state instead of disabling the review action. Source and packaged-game assertions exercise both zero-answer and scored flights.

## Save/download answer review as PDF — complete
- [x] Provide a Save/Download PDF action on the answer-review page that creates a readable printable report for that flight, retaining all questions and answers (including Spanish accents and Russian characters) and useful run context such as date, score, and selected subject/difficulty. Embed the bundled font in a self-contained UTF-8 report, wait for font loading before opening the browser's print dialog, and allow saving without a network service. Source and packaged checks verify Cyrillic content, safe HTML escaping, and the embedded font.

## Three additional Hangar aircraft — complete
- [x] Add three unlockable paper-plane types—Albatross Glider, Double Fold, and Boomerang Kite—with distinct transparent folded-paper artwork, Hangar previews and style captions. Preserve existing aircraft IDs, ownership, prices and save compatibility. New prices are 65, 80, and 100 coins; each design is cosmetic only and must not change flight physics, collision, scoring, or rewards. Verify purchases, saved selection, renderer mapping, and packaged assets.

## Math engine refinement — complete
- [x] Make generated hints match the exact math form, including signed multiplication, measurement addition/conversion/rate questions, and Pythagorean problems. Keep Math 1/2/3 track boundaries intact, align the lowest challenge level with its gentle age target, and provide bounded, clearly scaffolded geometry examples.

## Reading engine refinement — complete
- [x] Ensure procedural questions actually teach the advertised skills at each level: add Level 2 plurals/punctuation/adjectives, Level 4 complex sentences, and Level 5 text-evidence analysis; keep Level 5 vocabulary appropriately challenging with intentional review. Make inference/evidence prompts contain enough explicit information for the intended answer.

## Russian engine refinement — complete
- [x] Correct aspect and translation glosses, clarify grammatical form for adjective translations, distinguish noun/verb meanings where English is ambiguous, and give targeted aspect/conditional hints that match each question.

## Spanish engine refinement — complete
- [x] Clarify gender/number when presenting gendered adjective forms, keep invariant forms distinct, and make subjunctive guidance cover all generated triggers, including possibility expressions.

## Science engine refinement — complete
- [x] Align generated Level 3 questions with promised ecosystems, cycles, energy, and fair-test learning; bound travel scenarios to credible age-appropriate values; provide hints suited to classification, senses, and density; and ensure stems fit the two displayed answer choices.

Across these engine updates, preserve procedural variety, age appropriateness, accurate prompts, distinct answer choices with exactly one correct lane, useful localized topic/hint metadata, the staged setup, and the existing flight, score, coin, and save behavior.
