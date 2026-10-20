extends RefCounted
## Curated, age-stepped non-math learning packs for Paper Glide.

const MathQuestion = preload("res://scripts/flight/math_question.gd")
const PRACTICE_AREAS: Array[String] = ["reading", "russian", "spanish", "science"]

const BANK := {
	"reading": {
		1: [
			{"expression": "Which word rhymes with cat?", "answer": "hat", "distractor": "sun", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "In The dog runs, who runs?", "answer": "dog", "distractor": "cat", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which names a thing: bird or quickly?", "answer": "bird", "distractor": "quickly", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Which word starts like sun?", "answer": "sock", "distractor": "moon", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "What is the opposite of hot?", "answer": "cold", "distractor": "bright", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
		],
		2: [
			{"expression": "What is the plural of fox?", "answer": "foxes", "distractor": "fox", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Finish the question: Where are you going", "answer": "?", "distractor": ".", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "In soft pillow, which word describes pillow?", "answer": "soft", "distractor": "pillow", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "A seed becomes a sprout. What came first?", "answer": "seed", "distractor": "sprout", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Mia opened an umbrella. What did she open?", "answer": "umbrella", "distractor": "window", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
		],
		3: [
			{"expression": "The path was slick after rain. Slick means...", "answer": "slippery", "distractor": "sunny", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Birds built nests. Which word is the action?", "answer": "built", "distractor": "nests", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Bees visit flowers and carry pollen. Main idea?", "answer": "Bees help plants", "distractor": "Bees make rain", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Snow fell. Ria put on a coat. Why?", "answer": "It was cold", "distractor": "It was sunny", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which prefix means again?", "answer": "re-", "distractor": "un-", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
		],
		4: [
			{"expression": "The classroom was a zoo. This is a...", "answer": "metaphor", "distractor": "simile", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Which detail supports: The room was cold?", "answer": "Frosted glass", "distractor": "Open book", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Arduous means...", "answer": "difficult", "distractor": "colorful", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Although it rained, we played. Sentence type?", "answer": "complex", "distractor": "simple", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "A character hides a gift and smiles. Feeling?", "answer": "excited", "distractor": "angry", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
		],
		5: [
			{"expression": "A story teaches honesty. Its theme?", "answer": "Tell the truth", "distractor": "Brush your teeth", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "The wind whispered. Figure of speech?", "answer": "personification", "distractor": "hyperbole", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "An author argues for bike lanes. Purpose?", "answer": "persuade", "distractor": "entertain", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Which word signals contrast?", "answer": "however", "distractor": "therefore", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which detail supports: The soup was hot?", "answer": "Steam rose", "distractor": "A spoon fell", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
		],
	},
	"russian": {
		1: [
			{"expression": "Russian for hello?", "answer": "привет", "distractor": "пока", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "What does да mean?", "answer": "yes", "distractor": "no", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Russian for cat?", "answer": "кот", "distractor": "пёс", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "What does вода mean?", "answer": "water", "distractor": "bread", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Russian for mother?", "answer": "мама", "distractor": "папа", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
		],
		2: [
			{"expression": "What does спасибо mean?", "answer": "thanks", "distractor": "hello", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Russian for one?", "answer": "один", "distractor": "два", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "What does синий mean?", "answer": "blue", "distractor": "red", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Russian for book?", "answer": "книга", "distractor": "ручка", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Доброе утро means what time of day?", "answer": "morning", "distractor": "night", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
		],
		3: [
			{"expression": "Russian for I read?", "answer": "я читаю", "distractor": "ты читаешь", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Я вижу кота means...", "answer": "I see a cat", "distractor": "I have a cat", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Plural of собака (dog)?", "answer": "собаки", "distractor": "собака", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian for we speak?", "answer": "мы говорим", "distractor": "они говорят", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "In красивый дом, красивый means...", "answer": "beautiful", "distractor": "quiet", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
		],
		4: [
			{"expression": "Masculine: I read in past tense?", "answer": "читал", "distractor": "читаю", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "After без (without), книга becomes...", "answer": "книги", "distractor": "книга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian future: I will write?", "answer": "я буду писать", "distractor": "я писал", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian for to a friend?", "answer": "другу", "distractor": "друга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Из-за дождя means...", "answer": "because of rain", "distractor": "toward rain", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
		],
		5: [
			{"expression": "Accusative: I read a book (книга)?", "answer": "книгу", "distractor": "книга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Which verb means finish writing?", "answer": "дописать", "distractor": "писать", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Although it was cold: хотя было холодно. Choose...", "answer": "although", "distractor": "because", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Masculine: Russian for I would read?", "answer": "я бы читал", "distractor": "я читаю", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "In он бы пришёл, бы marks a...", "answer": "condition", "distractor": "command", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
		],
	},
	"spanish": {
		1: [
			{"expression": "Spanish for hello?", "answer": "hola", "distractor": "adiós", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does gato mean?", "answer": "cat", "distractor": "dog", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish for water?", "answer": "agua", "distractor": "leche", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does azul mean?", "answer": "blue", "distractor": "green", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Gracias means...", "answer": "thanks", "distractor": "goodbye", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
		],
		2: [
			{"expression": "Buenos días points to what time of day?", "answer": "morning", "distractor": "night", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Spanish plural of libro?", "answer": "libros", "distractor": "libro", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "In la mesa, la marks...", "answer": "feminine", "distractor": "plural", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for we eat?", "answer": "comemos", "distractor": "comen", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Dónde está means...", "answer": "Where is it?", "distractor": "Who is it?", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
		],
		3: [
			{"expression": "Spanish for I speak?", "answer": "hablo", "distractor": "hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Tengo hambre means...", "answer": "I'm hungry", "distractor": "I'm thirsty", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Past tense: I went (ir)?", "answer": "fui", "distractor": "voy", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Las casas son...", "answer": "grandes", "distractor": "grande", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "In el perro corre, corre means...", "answer": "runs", "distractor": "sleeps", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
		],
		4: [
			{"expression": "Completed past: they ate (comer)?", "answer": "comieron", "distractor": "comían", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for I would study?", "answer": "estudiaría", "distractor": "estudié", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Formal usted: you speak?", "answer": "usted habla", "distractor": "usted hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Completed past: we wrote?", "answer": "escribimos", "distractor": "escribíamos", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Me gusta usually means...", "answer": "I like it", "distractor": "I am sad", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
		],
		5: [
			{"expression": "Espero que tú ___ (hablar).", "answer": "hables", "distractor": "hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Si tuviera tiempo, viajaría. I ___ travel.", "answer": "would", "distractor": "will", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for I already arrived?", "answer": "ya llegué", "distractor": "voy a salir", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Which connector means however?", "answer": "sin embargo", "distractor": "por eso", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "The subjunctive in aunque llueva expresses...", "answer": "possibility", "distractor": "certainty", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
		],
	},
	"science": {
		1: [
			{"expression": "A tadpole grows into a...", "answer": "frog", "distractor": "fish", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which body part helps you smell?", "answer": "nose", "distractor": "elbow", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Photosynthesis uses which gas?", "answer": "carbon dioxide", "distractor": "oxygen", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which is a solid: ice or steam?", "answer": "ice", "distractor": "steam", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Which is a mammal: whale or trout?", "answer": "whale", "distractor": "trout", "topic": "science_life", "hint_key": "hint.science.life"},
		],
		2: [
			{"expression": "Frozen water is...", "answer": "ice", "distractor": "steam", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Earth is a...", "answer": "planet", "distractor": "moon", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Which force pulls objects to Earth?", "answer": "gravity", "distractor": "friction", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "A seed sprouts into a...", "answer": "plant", "distractor": "rock", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which metal is attracted to magnets?", "answer": "iron", "distractor": "wood", "topic": "science_physical", "hint_key": "hint.science.physical"},
		],
		3: [
			{"expression": "Water leaving plant leaves is...", "answer": "transpiration", "distractor": "condensation", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Plants in a food chain are...", "answer": "producers", "distractor": "consumers", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Day and night happen as Earth...", "answer": "rotates", "distractor": "stops", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "A fair test changes one...", "answer": "variable", "distractor": "conclusion", "topic": "science_methods", "hint_key": "hint.science.methods"},
			{"expression": "Sound cannot travel through...", "answer": "vacuum", "distractor": "water", "topic": "science_physical", "hint_key": "hint.science.physical"},
		],
		4: [
			{"expression": "Which organelle releases cell energy?", "answer": "mitochondria", "distractor": "nucleus", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "An acid's pH is usually...", "answer": "below 7", "distractor": "above 7", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "Electric current is measured in...", "answer": "amperes", "distractor": "volts", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "Tectonic plates move over Earth's...", "answer": "mantle", "distractor": "core", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Covalent bonds ___ electrons.", "answer": "share", "distractor": "transfer", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
		],
		5: [
			{"expression": "DNA pairs adenine with...", "answer": "thymine", "distractor": "uracil", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "Oxidation is the ___ of electrons.", "answer": "loss", "distractor": "gain", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "If speed doubles, kinetic energy becomes...", "answer": "fourfold", "distractor": "twofold", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "Meiosis crossing-over occurs in...", "answer": "prophase I", "distractor": "metaphase II", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "At equilibrium, forward and reverse rates are...", "answer": "equal", "distractor": "zero", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
		],
	},
}


static func questions_for(area: String, level: int) -> Array:
	if area not in PRACTICE_AREAS:
		return []
	var levels: Dictionary = BANK.get(area, {})
	var questions: Array = levels.get(clampi(level, 1, 5), [])
	return questions.duplicate(true)


static func generate(rng: RandomNumberGenerator, area: String, level: int) -> Dictionary:
	var safe_level := clampi(level, 1, 5)
	var pool := questions_for(area, safe_level)
	if pool.is_empty():
		return {}
	var question: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	question["practice_area"] = area
	question["difficulty"] = MathQuestion.band_for_level(safe_level)
	question["difficulty_level"] = safe_level
	question["topic_group"] = str(question.topic)
	question["kind"] = "knowledge_choice"
	question["value_num"] = 0
	question["value_den"] = 1
	var correct := str(question.answer)
	var distractor := str(question.distractor)
	var correct_lane := "upper" if rng.randi_range(0, 1) == 0 else "lower"
	question["upper_answer"] = correct if correct_lane == "upper" else distractor
	question["lower_answer"] = distractor if correct_lane == "upper" else correct
	question["correct_lane"] = correct_lane
	return question
