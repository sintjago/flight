extends RefCounted
## Curated, age-stepped non-math learning packs for Paper Glide.

const MathQuestion = preload("res://scripts/flight/math_question.gd")
const QuestionGenerator = preload("res://scripts/flight/learning_question_generator.gd")
const PRACTICE_AREAS: Array[String] = ["reading", "russian", "spanish", "science"]

const BANK := {
	"reading": {
		1: [
			{"expression": "Which word rhymes with cat?", "answer": "hat", "distractor": "sun", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "In The dog runs, who runs?", "answer": "dog", "distractor": "cat", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which names a thing: bird or quickly?", "answer": "bird", "distractor": "quickly", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Which word starts like sun?", "answer": "sock", "distractor": "moon", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "What is the opposite of hot?", "answer": "cold", "distractor": "bright", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which word rhymes with sun?", "answer": "fun", "distractor": "sit", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "Which is a naming word: jump or apple?", "answer": "apple", "distractor": "jump", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Mia has a red kite. What color?", "answer": "red", "distractor": "blue", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which word starts with b: ball or fish?", "answer": "ball", "distractor": "fish", "topic": "reading_phonics", "hint_key": "hint.reading.phonics"},
			{"expression": "Which word means happy?", "answer": "glad", "distractor": "slow", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
		],
		2: [
			{"expression": "What is the plural of fox?", "answer": "foxes", "distractor": "fox", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Finish the question: Where are you going", "answer": "?", "distractor": ".", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "In soft pillow, which word describes pillow?", "answer": "soft", "distractor": "pillow", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "A seed becomes a sprout. What came first?", "answer": "seed", "distractor": "sprout", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Mia opened an umbrella. What did she open?", "answer": "umbrella", "distractor": "window", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which word shows past action?", "answer": "walked", "distractor": "walking", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "The cup is empty. What is inside?", "answer": "nothing", "distractor": "water", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which word describes a shell?", "answer": "shiny", "distractor": "shine", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "What is the opposite of early?", "answer": "late", "distractor": "quick", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which is a complete sentence?", "answer": "Birds can fly.", "distractor": "In the tall tree.", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
		],
		3: [
			{"expression": "The path was slick after rain. Slick means...", "answer": "slippery", "distractor": "sunny", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Birds built nests. Which word is the action?", "answer": "built", "distractor": "nests", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Bees visit flowers and carry pollen. Main idea?", "answer": "Bees help plants", "distractor": "Bees make rain", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Snow fell. Ria put on a coat. Why?", "answer": "It was cold", "distractor": "It was sunny", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which prefix means again?", "answer": "re-", "distractor": "un-", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "The puppy was tiny. Tiny means...", "answer": "small", "distractor": "loud", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Sam packed a coat because...", "answer": "it might be cold", "distractor": "he was thirsty", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which prefix means not?", "answer": "un-", "distractor": "re-", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Birds fly south. Which word is the action?", "answer": "fly", "distractor": "birds", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Dark clouds gather and thunder rumbles. What may happen?", "answer": "rain", "distractor": "sunshine", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
		],
		4: [
			{"expression": "The classroom was a zoo. This is a...", "answer": "metaphor", "distractor": "simile", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Which detail supports: The room was cold?", "answer": "Frosted glass", "distractor": "Open book", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Arduous means...", "answer": "difficult", "distractor": "colorful", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Although it rained, we played. Sentence type?", "answer": "complex", "distractor": "simple", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "A character hides a gift and smiles. Feeling?", "answer": "excited", "distractor": "angry", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Which phrase is a simile?", "answer": "as busy as a bee", "distractor": "the bee buzzed", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Hands trembled. This detail suggests...", "answer": "nervous", "distractor": "sleepy", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "Reluctant means...", "answer": "unwilling", "distractor": "excited", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which words interrupt: The boy, who was tired, sat?", "answer": "who was tired", "distractor": "the boy", "topic": "reading_grammar", "hint_key": "hint.reading.grammar"},
			{"expression": "Which phrase gives an object a human action?", "answer": "alarm shouted", "distractor": "alarm rang", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
		],
		5: [
			{"expression": "A story teaches honesty. Its theme?", "answer": "Tell the truth", "distractor": "Brush your teeth", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "The wind whispered. Figure of speech?", "answer": "personification", "distractor": "hyperbole", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "An author argues for bike lanes. Purpose?", "answer": "persuade", "distractor": "entertain", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Which word signals contrast?", "answer": "however", "distractor": "therefore", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which detail supports: The soup was hot?", "answer": "Steam rose", "distractor": "A spoon fell", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "A character gives away a prize. Trait?", "answer": "generous", "distractor": "selfish", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Which detail suggests a character is kind?", "answer": "She shared lunch", "distractor": "She hid the ball", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
			{"expression": "The narrator says, I ran. Point of view?", "answer": "first person", "distractor": "third person", "topic": "reading_literature", "hint_key": "hint.reading.literature"},
			{"expression": "Although the trail was steep, we continued. Contrast word?", "answer": "although", "distractor": "because", "topic": "reading_vocabulary", "hint_key": "hint.reading.vocabulary"},
			{"expression": "Which detail best supports: The wind was strong?", "answer": "Branches bent", "distractor": "A lamp glowed", "topic": "reading_comprehension", "hint_key": "hint.reading.comprehension"},
		],
	},
	"russian": {
		1: [
			{"expression": "Russian for hello?", "answer": "привет", "distractor": "пока", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "What does да mean?", "answer": "yes", "distractor": "no", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Russian for a male cat?", "answer": "кот", "distractor": "пёс", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "What does вода mean?", "answer": "water", "distractor": "bread", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for mother?", "answer": "мама", "distractor": "папа", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for dog?", "answer": "собака", "distractor": "кошка", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "What does дом mean?", "answer": "house", "distractor": "water", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for bread?", "answer": "хлеб", "distractor": "вода", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for goodbye?", "answer": "пока", "distractor": "привет", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "What does сад mean?", "answer": "garden", "distractor": "road", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
		],
			2: [
				{"expression": "What does спасибо mean?", "answer": "thanks", "distractor": "hello", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for one?", "answer": "один", "distractor": "два", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "What does синий mean?", "answer": "blue", "distractor": "red", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for book?", "answer": "книга", "distractor": "ручка", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Доброе утро means what time of day?", "answer": "morning", "distractor": "night", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
				{"expression": "What does два mean?", "answer": "two", "distractor": "three", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "What does молоко mean?", "answer": "milk", "distractor": "bread", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for apple?", "answer": "яблоко", "distractor": "окно", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "What does пожалуйста mean?", "answer": "please", "distractor": "thanks", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
				{"expression": "Russian for red?", "answer": "красный", "distractor": "синий", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
		],
		3: [
			{"expression": "Russian for I read?", "answer": "я читаю", "distractor": "ты читаешь", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Я вижу кота means...", "answer": "I see a cat", "distractor": "I have a cat", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Plural of собака (dog)?", "answer": "собаки", "distractor": "собака", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian for we speak?", "answer": "мы говорим", "distractor": "они говорят", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "In красивый дом, красивый means...", "answer": "beautiful", "distractor": "quiet", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Russian for I write?", "answer": "я пишу", "distractor": "ты пишешь", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Мы читаем means...", "answer": "we read", "distractor": "they read", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Plural of стол (table)?", "answer": "столы", "distractor": "стул", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Я люблю чай means...", "answer": "I like tea", "distractor": "I see tea", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "In красная книга, красная means...", "answer": "red", "distractor": "blue", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
		],
		4: [
			{"expression": "Masculine: I read in past tense?", "answer": "читал", "distractor": "читаю", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "After без (without), книга becomes...", "answer": "книги", "distractor": "книга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian future: I will write?", "answer": "я буду писать", "distractor": "я писал", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Russian for to a friend?", "answer": "другу", "distractor": "друга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Из-за дождя means...", "answer": "because of rain", "distractor": "toward rain", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Feminine speaker: I read yesterday?", "answer": "читала", "distractor": "читали", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "For she will write, choose: она...", "answer": "будет писать", "distractor": "писала", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "к (to or toward) is followed by which case?", "answer": "dative", "distractor": "genitive", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Он бы говорил means...", "answer": "he would speak", "distractor": "he spoke", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Он говорит о книге. Which case follows о?", "answer": "prepositional", "distractor": "dative", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
		],
		5: [
			{"expression": "Accusative: I read a book (книга)?", "answer": "книгу", "distractor": "книга", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Which verb means finish writing?", "answer": "дописать", "distractor": "писать", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
				{"expression": "Хотя means...", "answer": "although", "distractor": "because", "topic": "russian_vocabulary", "hint_key": "hint.russian.vocabulary"},
			{"expression": "Masculine: Russian for I would read?", "answer": "я бы читал", "distractor": "я читаю", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "In он бы пришёл, бы marks a...", "answer": "condition", "distractor": "command", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Perfective прочитать means...", "answer": "read to finish", "distractor": "keep reading", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Книга is the subject. Which case?", "answer": "nominative", "distractor": "accusative", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "Если бы он знал means...", "answer": "if he knew", "distractor": "when he knows", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
			{"expression": "Я горжусь другом. Which case follows горжусь?", "answer": "instrumental", "distractor": "accusative", "topic": "russian_grammar", "hint_key": "hint.russian.grammar"},
			{"expression": "В то время как means...", "answer": "while", "distractor": "because", "topic": "russian_phrases", "hint_key": "hint.russian.phrases"},
		],
	},
	"spanish": {
		1: [
			{"expression": "Spanish for hello?", "answer": "hola", "distractor": "adiós", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does gato mean?", "answer": "cat", "distractor": "dog", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish for water?", "answer": "agua", "distractor": "leche", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does azul mean?", "answer": "blue", "distractor": "green", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
				{"expression": "Gracias means...", "answer": "thanks", "distractor": "goodbye", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish for dog?", "answer": "perro", "distractor": "gato", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does casa mean?", "answer": "house", "distractor": "food", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish for red?", "answer": "rojo", "distractor": "azul", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does dos mean?", "answer": "two", "distractor": "three", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish for please?", "answer": "por favor", "distractor": "gracias", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
		],
		2: [
			{"expression": "Buenos días points to what time of day?", "answer": "morning", "distractor": "night", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Spanish plural of libro?", "answer": "libros", "distractor": "libro", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "In la mesa, la marks...", "answer": "feminine", "distractor": "plural", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for we eat?", "answer": "comemos", "distractor": "comen", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Dónde está means...", "answer": "Where is it?", "distractor": "Who is it?", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Spanish for book?", "answer": "libro", "distractor": "mesa", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "What does familia mean?", "answer": "family", "distractor": "friend", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Spanish plural of flor?", "answer": "flores", "distractor": "flor", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "What does por favor mean?", "answer": "please", "distractor": "thanks", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Spanish for we speak?", "answer": "hablamos", "distractor": "hablan", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
		],
		3: [
			{"expression": "Spanish for I speak?", "answer": "hablo", "distractor": "hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Tengo hambre means...", "answer": "I'm hungry", "distractor": "I'm thirsty", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Past tense: I went (ir)?", "answer": "fui", "distractor": "voy", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Las casas son...", "answer": "grandes", "distractor": "grande", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
				{"expression": "In el perro corre, corre means...", "answer": "runs", "distractor": "sleeps", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "Tengo un perro means...", "answer": "I have a dog", "distractor": "You have a dog", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "No tengo pan means...", "answer": "I have no bread", "distractor": "I have bread", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Las niñas son altas. The girls are...", "answer": "tall", "distractor": "short", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "What does porque mean?", "answer": "because", "distractor": "although", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
			{"expression": "In el gato pequeño, pequeño means...", "answer": "small", "distractor": "old", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
		],
		4: [
			{"expression": "Completed past: they ate (comer)?", "answer": "comieron", "distractor": "comían", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for I would study?", "answer": "estudiaría", "distractor": "estudié", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Formal usted: you speak?", "answer": "usted habla", "distractor": "usted hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Preterite: we wrote (escribir)?", "answer": "escribimos", "distractor": "escribíamos", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Me gusta usually means...", "answer": "I like it", "distractor": "I am sad", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "Imperfect: I used to eat (comer)?", "answer": "comía", "distractor": "comí", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Tú vivirías means...", "answer": "you would live", "distractor": "you lived", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Ustedes ___ listos.", "answer": "son", "distractor": "es", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Preterite: she wrote (escribir)?", "answer": "escribió", "distractor": "escribía", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "What does mientras mean?", "answer": "while", "distractor": "therefore", "topic": "spanish_vocabulary", "hint_key": "hint.spanish.vocabulary"},
		],
		5: [
			{"expression": "Espero que tú ___ (hablar).", "answer": "hables", "distractor": "hablas", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Si tuviera tiempo, viajaría. I ___ travel.", "answer": "would", "distractor": "will", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Spanish for I already arrived?", "answer": "ya llegué", "distractor": "voy a salir", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
				{"expression": "Which connector means however?", "answer": "sin embargo", "distractor": "por eso", "topic": "spanish_phrases", "hint_key": "hint.spanish.phrases"},
			{"expression": "The subjunctive in aunque llueva expresses...", "answer": "possibility", "distractor": "certainty", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Quiero que ellos ___ (venir).", "answer": "vengan", "distractor": "vienen", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Si hubiera estudiado, ___ aprobado.", "answer": "habría", "distractor": "había", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "No creo que ella ___ (tener) razón.", "answer": "tenga", "distractor": "tiene", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "Dudo que ellos ___ temprano.", "answer": "lleguen", "distractor": "llegan", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
			{"expression": "La decisión fue tomada. It was...", "answer": "made", "distractor": "lost", "topic": "spanish_grammar", "hint_key": "hint.spanish.grammar"},
		],
	},
	"science": {
		1: [
			{"expression": "A tadpole grows into a...", "answer": "frog", "distractor": "fish", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which body part helps you smell?", "answer": "nose", "distractor": "elbow", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which do plants need to grow?", "answer": "water", "distractor": "plastic", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which is a solid: ice or steam?", "answer": "ice", "distractor": "steam", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Which is a mammal: whale or trout?", "answer": "whale", "distractor": "trout", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which is a plant: oak or stone?", "answer": "oak", "distractor": "stone", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "What do bees collect from flowers?", "answer": "nectar", "distractor": "sand", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which animal lays eggs: hen or dog?", "answer": "hen", "distractor": "dog", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which body part helps you hear?", "answer": "ears", "distractor": "knees", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "What does the Sun give Earth?", "answer": "light", "distractor": "rocks", "topic": "science_earth", "hint_key": "hint.science.earth"},
		],
		2: [
			{"expression": "Frozen water is...", "answer": "ice", "distractor": "steam", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Earth is a...", "answer": "planet", "distractor": "moon", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Which force pulls objects to Earth?", "answer": "gravity", "distractor": "friction", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "A seed sprouts into a...", "answer": "plant", "distractor": "rock", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Which metal is attracted to magnets?", "answer": "iron", "distractor": "wood", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "A sunny puddle dries. Water becomes...", "answer": "vapor", "distractor": "ice", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "The Moon travels around...", "answer": "Earth", "distractor": "Jupiter", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Which lets light through: clear glass or wood?", "answer": "clear glass", "distractor": "wood", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Roots take in what from soil?", "answer": "water", "distractor": "light", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Clouds form as water vapor...", "answer": "cools", "distractor": "burns", "topic": "science_earth", "hint_key": "hint.science.earth"},
		],
		3: [
			{"expression": "Which plant part carries water upward?", "answer": "stem", "distractor": "petal", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Plants in a food chain are...", "answer": "producers", "distractor": "consumers", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "Day and night happen as Earth...", "answer": "rotates", "distractor": "stops", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "A fair test changes one...", "answer": "variable", "distractor": "conclusion", "topic": "science_methods", "hint_key": "hint.science.methods"},
			{"expression": "Sound cannot travel through...", "answer": "vacuum", "distractor": "water", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "Liquid water freezes into...", "answer": "ice", "distractor": "steam", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "A plant-eating rabbit is a...", "answer": "consumer", "distractor": "producer", "topic": "science_life", "hint_key": "hint.science.life"},
			{"expression": "A shadow forms when light is...", "answer": "blocked", "distractor": "created", "topic": "science_physical", "hint_key": "hint.science.physical"},
			{"expression": "In a fair test, what should stay the same?", "answer": "control variables", "distractor": "the result", "topic": "science_methods", "hint_key": "hint.science.methods"},
			{"expression": "Earth orbits the Sun in about...", "answer": "one year", "distractor": "one day", "topic": "science_earth", "hint_key": "hint.science.earth"},
		],
		4: [
			{"expression": "Which organelle releases cell energy?", "answer": "mitochondria", "distractor": "nucleus", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "An acid's pH is usually...", "answer": "below 7", "distractor": "above 7", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "Electric current is measured in...", "answer": "amperes", "distractor": "volts", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "Tectonic plates move over Earth's...", "answer": "mantle", "distractor": "core", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Covalent bonds ___ electrons.", "answer": "share", "distractor": "transfer", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "Photosynthesis takes in which gas?", "answer": "carbon dioxide", "distractor": "oxygen", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "Water leaving leaves as vapor is...", "answer": "transpiration", "distractor": "condensation", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "A cell's DNA is mainly stored in its...", "answer": "nucleus", "distractor": "membrane", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "A broken circuit is an...", "answer": "open circuit", "distractor": "closed circuit", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "A sedimentary rock forms from...", "answer": "compacted layers", "distractor": "cooled metal", "topic": "science_earth", "hint_key": "hint.science.earth"},
		],
		5: [
			{"expression": "DNA pairs adenine with...", "answer": "thymine", "distractor": "uracil", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "Oxidation is the ___ of electrons.", "answer": "loss", "distractor": "gain", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "Same mass, speed doubles. Kinetic energy becomes...", "answer": "fourfold", "distractor": "twofold", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "Meiosis crossing-over occurs in...", "answer": "prophase I", "distractor": "metaphase II", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "At equilibrium, forward and reverse rates are...", "answer": "equal", "distractor": "zero", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "A gene is a segment of...", "answer": "DNA", "distractor": "glucose", "topic": "science_biology", "hint_key": "hint.science.biology"},
			{"expression": "Newton's second law: F = ?", "answer": "m × a", "distractor": "m + a", "topic": "science_physics", "hint_key": "hint.science.physics"},
			{"expression": "A catalyst speeds a reaction by lowering...", "answer": "activation energy", "distractor": "particle mass", "topic": "science_chemistry", "hint_key": "hint.science.chemistry"},
			{"expression": "Most earthquakes occur near...", "answer": "plate boundaries", "distractor": "plate centers", "topic": "science_earth", "hint_key": "hint.science.earth"},
			{"expression": "Natural selection can make helpful traits...", "answer": "more common", "distractor": "less common", "topic": "science_biology", "hint_key": "hint.science.biology"},
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
	return generate_with_history(rng, area, level, [])


static func generate_with_history(rng: RandomNumberGenerator, area: String, level: int, used_prompts: Array) -> Dictionary:
	var safe_level := clampi(level, 1, 5)
	var pool := questions_for(area, safe_level)
	if pool.is_empty():
		return {}
	var question: Dictionary = {}
	var found_new_prompt := false
	var seen_prompts: Dictionary = {}
	for prompt: Variant in used_prompts:
		seen_prompts[str(prompt)] = true
	var attempt_limit := maxi(2048, (seen_prompts.size() + 1) * 16)
	for _attempt in attempt_limit:
		if rng.randi_range(0, 5) == 0:
			question = pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)
		else:
			question = QuestionGenerator.generate(rng, area, safe_level)
		var prompt := str(question.get("expression", ""))
		if not prompt.is_empty() and not seen_prompts.has(prompt):
			used_prompts.append(prompt)
			found_new_prompt = true
			break
	if not found_new_prompt:
		var previous_prompt := str(used_prompts.back()) if not used_prompts.is_empty() else ""
		used_prompts.clear()
		if not previous_prompt.is_empty():
			used_prompts.append(previous_prompt)
		for _attempt in 2048:
			if rng.randi_range(0, 5) == 0:
				question = pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)
			else:
				question = QuestionGenerator.generate(rng, area, safe_level)
			var prompt := str(question.get("expression", ""))
			if not prompt.is_empty() and prompt != previous_prompt:
				used_prompts.append(prompt)
				found_new_prompt = true
				break
		if not found_new_prompt:
			question = QuestionGenerator.generate(rng, area, safe_level)
			used_prompts.append(str(question.get("expression", "")))
	question["practice_area"] = area
	question["difficulty"] = MathQuestion.band_for_level(safe_level)
	question["difficulty_level"] = safe_level
	question["topic_group"] = str(question.topic)
	question["generator_kind"] = str(question.get("kind", "knowledge_choice"))
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
