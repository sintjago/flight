extends RefCounted
## Parameterized question builders for the non-math learning packs.
## Curated questions remain in LearningQuestion.BANK; this module creates fresh variants on demand.

const NAMES: Array[String] = ["Mia", "Leo", "Ava", "Noah", "Ivy", "Max", "Zoe", "Ben"]
const READING_RHYMES: Array = [
	["cat", "hat", "mat", "bat"], ["sun", "fun", "run", "bun"], ["bug", "hug", "mug", "rug"],
	["cake", "lake", "make", "rake"], ["light", "night", "bright", "sight"], ["tree", "bee", "free", "knee"],
	["book", "look", "cook", "hook"], ["day", "play", "stay", "gray"], ["hop", "mop", "top", "shop"],
	["fish", "dish", "wish", "swish"], ["blue", "shoe", "glue", "true"], ["star", "car", "far", "jar"],
]
const READING_WORD_PAIRS: Array = [
	{"level":1,"word":"happy", "synonym":"glad", "opposite":"sad"}, {"level":1,"word":"tiny", "synonym":"small", "opposite":"huge"},
	{"level":1,"word":"quick", "synonym":"fast", "opposite":"slow"}, {"level":1,"word":"begin", "synonym":"start", "opposite":"finish"},
	{"level":2,"word":"quiet", "synonym":"silent", "opposite":"noisy"}, {"level":2,"word":"brave", "synonym":"bold", "opposite":"afraid"},
	{"level":2,"word":"bright", "synonym":"shiny", "opposite":"dim"}, {"level":2,"word":"ancient", "synonym":"old", "opposite":"new"},
	{"level":3,"word":"generous", "synonym":"giving", "opposite":"selfish"}, {"level":4,"word":"reluctant", "synonym":"unwilling", "opposite":"eager"},
	{"level":4,"word":"arduous", "synonym":"difficult", "opposite":"easy"}, {"level":4,"word":"scarce", "synonym":"rare", "opposite":"plentiful"},
	{"level":3,"word":"assist", "synonym":"help", "opposite":"hinder"}, {"level":3,"word":"predict", "synonym":"forecast", "opposite":"remember"},
	{"level":3,"word":"protect", "synonym":"guard", "opposite":"harm"}, {"level":3,"word":"observe", "synonym":"notice", "opposite":"ignore"},
	{"level":3,"word":"expand", "synonym":"grow", "opposite":"shrink"}, {"level":4,"word":"precise", "synonym":"exact", "opposite":"vague"},
]
const READING_NOUNS: Array[String] = ["rabbit", "robot", "teacher", "sailor", "puppy", "baker", "dragon", "squirrel", "neighbor", "artist", "captain", "kitten"]
const READING_ADJECTIVES: Array[String] = ["curious", "gentle", "sleepy", "cheerful", "muddy", "brave", "tiny", "clever", "quiet", "silver", "ancient", "nervous"]
const READING_VERBS: Array[String] = ["danced", "waited", "laughed", "whispered", "explored", "helped", "watched", "painted", "wondered", "hurried", "rested", "climbed"]
const READING_OBJECTS: Array[String] = ["book", "kite", "apple", "shell", "letter", "lantern", "map", "basket", "pencil", "flower", "button", "ticket", "drum", "camera", "ribbon", "key"]
const READING_TRANSITIVE_VERBS: Array = [
	{"past":"found", "base":"find", "objects":["key", "shell", "map", "button", "ticket", "flower", "letter", "ribbon"]},
	{"past":"read", "base":"read", "objects":["book", "letter", "map", "note", "story"]},
	{"past":"drew", "base":"draw", "objects":["picture", "map", "star", "flower"]},
	{"past":"carried", "base":"carry", "objects":["basket", "book", "kite", "lantern", "drum"]},
	{"past":"opened", "base":"open", "objects":["book", "box", "door", "letter", "basket"]},
	{"past":"packed", "base":"pack", "objects":["bag", "basket", "box", "suitcase"]},
	{"past":"planted", "base":"plant", "objects":["seed", "flower", "tree"]},
	{"past":"borrowed", "base":"borrow", "objects":["book", "pencil", "camera", "ribbon"]},
	{"past":"painted", "base":"paint", "objects":["picture", "door", "flower", "box"]},
	{"past":"chose", "base":"choose", "objects":["book", "kite", "flower", "ticket"]},
	{"past":"fixed", "base":"fix", "objects":["bike", "robot", "clock", "kite"]},
]
const READING_ADJECTIVE_OBJECTS: Array[String] = ["moon", "river", "mountain", "cloud", "garden", "story", "forest", "bridge", "window", "island", "pocket", "clock"]
const READING_HUMAN_ACTIONS: Array[String] = ["whispered", "danced", "complained", "smiled", "called", "waved", "waited", "sang", "argued", "celebrated"]
const READING_COMPARISONS: Array[String] = ["a bee", "a deer", "a rocket", "the wind", "a feather", "a drum", "a mouse", "a storm", "a statue", "a flame"]
const READING_PREFIXES: Array = [
	{"prefix":"re-", "meaning":"again", "word":"write"}, {"prefix":"un-", "meaning":"not", "word":"kind"},
	{"prefix":"pre-", "meaning":"before", "word":"view"}, {"prefix":"mis-", "meaning":"wrongly", "word":"place"},
	{"prefix":"dis-", "meaning":"opposite of", "word":"agree"}, {"prefix":"over-", "meaning":"too much", "word":"cook"},
	{"prefix":"sub-", "meaning":"under", "word":"marine"}, {"prefix":"inter-", "meaning":"between", "word":"act"},
]

const SPANISH_WORDS: Array = [
	{"level":1,"en":"hello","word":"hola"},{"level":1,"en":"goodbye","word":"adiós"},{"level":1,"en":"please","word":"por favor"},
	{"level":1,"en":"thank you","word":"gracias"},{"level":1,"en":"yes","word":"sí"},{"level":1,"en":"no","word":"no"},
	{"level":1,"en":"mother","word":"madre"},{"level":1,"en":"father","word":"padre"},{"level":1,"en":"cat","word":"gato"},
	{"level":1,"en":"dog","word":"perro"},{"level":1,"en":"water","word":"agua"},{"level":1,"en":"bread","word":"pan"},
	{"level":1,"en":"red","word":"rojo"},{"level":1,"en":"blue","word":"azul"},{"level":1,"en":"one","word":"uno"},
	{"level":1,"en":"two","word":"dos"},{"level":1,"en":"sun","word":"sol"},{"level":1,"en":"moon","word":"luna"},
	{"level":2,"en":"book","word":"libro"},{"level":2,"en":"school","word":"escuela"},{"level":2,"en":"house","word":"casa"},
	{"level":2,"en":"friend","word":"amigo"},{"level":2,"en":"family","word":"familia"},{"level":2,"en":"apple","word":"manzana"},
	{"level":2,"en":"milk","word":"leche"},{"level":2,"en":"green","word":"verde"},{"level":2,"en":"small","word":"pequeño"},
	{"level":2,"en":"big","word":"grande"},{"level":2,"en":"today","word":"hoy"},{"level":2,"en":"tomorrow","word":"mañana"},
	{"level":3,"en":"to eat","word":"comer"},{"level":3,"en":"to read","word":"leer"},{"level":3,"en":"to speak","word":"hablar"},
	{"level":3,"en":"to live","word":"vivir"},{"level":3,"en":"because","word":"porque"},{"level":3,"en":"but","word":"pero"},
	{"level":3,"en":"always","word":"siempre"},{"level":3,"en":"sometimes","word":"a veces"},{"level":3,"en":"yesterday","word":"ayer"},
	{"level":3,"en":"beautiful","word":"hermoso"},{"level":4,"en":"to choose","word":"elegir"},{"level":4,"en":"although","word":"aunque"},
	{"level":4,"en":"while","word":"mientras"},{"level":4,"en":"perhaps","word":"quizás"},{"level":4,"en":"careful","word":"cuidadoso"},
	{"level":4,"en":"environment","word":"medio ambiente"},{"level":4,"en":"to discover","word":"descubrir"},{"level":4,"en":"however","word":"sin embargo"},
	{"level":5,"en":"evidence","word":"prueba"},{"level":5,"en":"although","word":"aunque"},{"level":5,"en":"to achieve","word":"lograr"},
	{"level":5,"en":"unless","word":"a menos que"},{"level":5,"en":"nevertheless","word":"sin embargo"},{"level":5,"en":"to suggest","word":"sugerir"},
	{"level":5,"en":"awareness","word":"conciencia"},{"level":5,"en":"to improve","word":"mejorar"},
]
const RUSSIAN_WORDS: Array = [
	{"level":1,"en":"hello","word":"привет"},{"level":1,"en":"goodbye","word":"пока"},{"level":1,"en":"yes","word":"да"},
	{"level":1,"en":"no","word":"нет"},{"level":1,"en":"mother","word":"мама"},{"level":1,"en":"father","word":"папа"},
	{"level":1,"en":"cat","word":"кот"},{"level":1,"en":"dog","word":"собака"},{"level":1,"en":"water","word":"вода"},
	{"level":1,"en":"bread","word":"хлеб"},{"level":1,"en":"house","word":"дом"},{"level":1,"en":"book","word":"книга"},
	{"level":2,"en":"please","word":"пожалуйста"},{"level":2,"en":"thank you","word":"спасибо"},{"level":2,"en":"one","word":"один"},
	{"level":2,"en":"two","word":"два"},{"level":2,"en":"red","word":"красный"},{"level":2,"en":"blue","word":"синий"},
	{"level":2,"en":"apple","word":"яблоко"},{"level":2,"en":"milk","word":"молоко"},{"level":2,"en":"school","word":"школа"},
	{"level":2,"en":"friend","word":"друг"},{"level":2,"en":"small","word":"маленький"},{"level":2,"en":"big","word":"большой"},
	{"level":3,"en":"to read","word":"читать"},{"level":3,"en":"to write","word":"писать"},{"level":3,"en":"to speak","word":"говорить"},
	{"level":3,"en":"to see","word":"видеть"},{"level":3,"en":"beautiful","word":"красивый"},{"level":3,"en":"we","word":"мы"},
	{"level":3,"en":"they","word":"они"},{"level":3,"en":"today","word":"сегодня"},{"level":3,"en":"tomorrow","word":"завтра"},
	{"level":3,"en":"where?","word":"где?"},{"level":4,"en":"because","word":"потому что"},{"level":4,"en":"although","word":"хотя"},
	{"level":4,"en":"to understand","word":"понимать"},{"level":4,"en":"to go","word":"ехать"},{"level":4,"en":"city","word":"город"},
	{"level":4,"en":"language","word":"язык"},{"level":4,"en":"interesting","word":"интересный"},{"level":4,"en":"careful","word":"осторожный"},
	{"level":5,"en":"chance","word":"шанс"},{"level":5,"en":"to explain","word":"объяснять"},{"level":5,"en":"nevertheless","word":"тем не менее"},
	{"level":5,"en":"nature","word":"природа"},{"level":5,"en":"to improve","word":"улучшать"},{"level":5,"en":"study","word":"изучение"},
	{"level":5,"en":"duty","word":"долг"},{"level":5,"en":"to compare","word":"сравнивать"},
]
const SPANISH_PRESENT: Array = [
	{"verb":"hablar","forms":["hablo","hablas","habla","hablamos","hablan"]},
	{"verb":"comer","forms":["como","comes","come","comemos","comen"]},
	{"verb":"vivir","forms":["vivo","vives","vive","vivimos","viven"]},
	{"verb":"estudiar","forms":["estudio","estudias","estudia","estudiamos","estudian"]},
	{"verb":"aprender","forms":["aprendo","aprendes","aprende","aprendemos","aprenden"]},
	{"verb":"abrir","forms":["abro","abres","abre","abrimos","abren"]},
	{"verb":"ser","forms":["soy","eres","es","somos","son"]},
	{"verb":"tener","forms":["tengo","tienes","tiene","tenemos","tienen"]},
	{"verb":"venir","forms":["vengo","vienes","viene","venimos","vienen"]},
]
const SPANISH_PRETERITE: Array = [
	{"verb":"hablar","forms":["hablé","hablaste","habló","hablamos","hablaron"]},
	{"verb":"comer","forms":["comí","comiste","comió","comimos","comieron"]},
	{"verb":"vivir","forms":["viví","viviste","vivió","vivimos","vivieron"]},
]
const SPANISH_SUBJUNCTIVE: Array = [
	{"verb":"hablar","forms":["hable","hables","hable","hablemos","hablen"]},
	{"verb":"comer","forms":["coma","comas","coma","comamos","coman"]},
	{"verb":"vivir","forms":["viva","vivas","viva","vivamos","vivan"]},
	{"verb":"tener","forms":["tenga","tengas","tenga","tengamos","tengan"]},
	{"verb":"venir","forms":["venga","vengas","venga","vengamos","vengan"]},
]
const SPANISH_CONDITIONAL: Array = [
	{"verb":"hablar","forms":["hablaría","hablarías","hablaría","hablaríamos","hablarían"]},
	{"verb":"comer","forms":["comería","comerías","comería","comeríamos","comerían"]},
	{"verb":"vivir","forms":["viviría","vivirías","viviría","viviríamos","vivirían"]},
	{"verb":"tener","forms":["tendría","tendrías","tendría","tendríamos","tendrían"]},
	{"verb":"venir","forms":["vendría","vendrías","vendría","vendríamos","vendrían"]},
]
const SPANISH_SUBJECTS: Array[String] = ["yo", "tú", "él/ella", "nosotros", "ellos/ellas"]
const SPANISH_NOUNS: Array = [
	{"word":"casa","plural":"casas","gender":"f"},{"word":"mesa","plural":"mesas","gender":"f"},
	{"word":"puerta","plural":"puertas","gender":"f"},{"word":"libro","plural":"libros","gender":"m"},
	{"word":"gato","plural":"gatos","gender":"m"},{"word":"perro","plural":"perros","gender":"m"},
	{"word":"amigo","plural":"amigos","gender":"m"},{"word":"flor","plural":"flores","gender":"f"},
]
const SPANISH_ADJECTIVES: Array[String] = ["rojo", "blanco", "pequeño", "bonito", "alto", "nuevo", "limpio", "tranquilo"]
const SPANISH_SUBJECT_FORMS: Array[String] = ["singular", "plural"]
const RUSSIAN_PRESENT: Array = [
	{"verb":"читать","forms":["читаю","читаешь","читает","читаем","читаете","читают"]},
	{"verb":"писать","forms":["пишу","пишешь","пишет","пишем","пишете","пишут"]},
	{"verb":"говорить","forms":["говорю","говоришь","говорит","говорим","говорите","говорят"]},
	{"verb":"смотреть","forms":["смотрю","смотришь","смотрит","смотрим","смотрите","смотрят"]},
	{"verb":"жить","forms":["живу","живешь","живет","живем","живете","живут"]},
	{"verb":"работать","forms":["работаю","работаешь","работает","работаем","работаете","работают"]},
]
const RUSSIAN_FUTURE: Array[String] = ["буду", "будешь", "будет", "будем", "будете", "будут"]
const RUSSIAN_FUTURE_VERBS: Array[String] = ["читать", "писать", "жить"]
const RUSSIAN_SUBJECTS: Array[String] = ["я", "ты", "он/она", "мы", "вы", "они"]
const RUSSIAN_CASES: Array[String] = ["nominative", "genitive", "dative", "accusative", "instrumental", "prepositional"]
const RUSSIAN_NOUNS: Array = [
	{"word":"книга","forms":["книга","книги","книге","книгу","книгой","книге"]},
	{"word":"кот","forms":["кот","кота","коту","кота","котом","коте"]},
	{"word":"дом","forms":["дом","дома","дому","дом","домом","доме"]},
	{"word":"собака","forms":["собака","собаки","собаке","собаку","собакой","собаке"]},
	{"word":"школа","forms":["школа","школы","школе","школу","школой","школе"]},
	{"word":"город","forms":["город","города","городу","город","городом","городе"]},
	{"word":"стол","forms":["стол","стола","столу","стол","столом","столе"]},
	{"word":"окно","forms":["окно","окна","окну","окно","окном","окне"]},
]
const RUSSIAN_PAST: Array = [
	{"verb":"читать","forms":["читал","читала","читало","читали"]},
	{"verb":"писать","forms":["писал","писала","писало","писали"]},
	{"verb":"говорить","forms":["говорил","говорила","говорило","говорили"]},
	{"verb":"смотреть","forms":["смотрел","смотрела","смотрело","смотрели"]},
	{"verb":"работать","forms":["работал","работала","работало","работали"]},
]
const RUSSIAN_PAST_SUBJECTS: Array[String] = ["он", "она", "оно", "они"]
const RUSSIAN_ASPECT_PAIRS: Array = [
	{"imperfective":"читать","perfective":"прочитать","meaning":"read to completion"},
	{"imperfective":"писать","perfective":"написать","meaning":"write to completion"},
	{"imperfective":"делать","perfective":"сделать","meaning":"finish doing"},
	{"imperfective":"покупать","perfective":"купить","meaning":"complete a purchase"},
	{"imperfective":"смотреть","perfective":"посмотреть","meaning":"watch to the end"},
]

const SCIENCE_ANIMALS: Array = [
	{"animal":"whale","class":"mammal"},{"animal":"dolphin","class":"mammal"},{"animal":"bat","class":"mammal"},
	{"animal":"eagle","class":"bird"},{"animal":"penguin","class":"bird"},{"animal":"hen","class":"bird"},
	{"animal":"salmon","class":"fish"},{"animal":"shark","class":"fish"},{"animal":"trout","class":"fish"},
	{"animal":"frog","class":"amphibian"},{"animal":"toad","class":"amphibian"},{"animal":"lizard","class":"reptile"},
	{"animal":"turtle","class":"reptile"},{"animal":"snake","class":"reptile"},{"animal":"butterfly","class":"insect"},
	{"animal":"ant","class":"insect"},{"animal":"bee","class":"insect"},
]
const SCIENCE_CLASSES: Array[String] = ["mammal", "bird", "fish", "amphibian", "reptile", "insect"]
const SCIENCE_PLANT_PARTS: Array = [
	{"part":"roots","job":"take in water from soil"},{"part":"stem","job":"carry water through the plant"},
	{"part":"leaves","job":"collect light for the plant"},{"part":"flowers","job":"help the plant make seeds"},
]
const SCIENCE_SENSES: Array = [
	{"sense":"hear sounds","organ":"ears"},{"sense":"see colors","organ":"eyes"},
	{"sense":"smell a flower","organ":"nose"},{"sense":"taste food","organ":"tongue"},
	{"sense":"feel a rough surface","organ":"skin"},
]
const SCIENCE_STATES: Array = [
	{"thing":"ice","state":"solid"},{"thing":"water in a cup","state":"liquid"},{"thing":"steam","state":"gas"},
	{"thing":"a stone","state":"solid"},{"thing":"milk","state":"liquid"},{"thing":"air","state":"gas"},
	{"thing":"juice","state":"liquid"},{"thing":"a wooden block","state":"solid"},
]
const SCIENCE_METHODS: Array = [
	{"test":"whether sunlight changes plant growth","change":"light level","wrong":"plant height"},
	{"test":"which paper plane shape flies farthest","change":"wing shape","wrong":"flight range"},
	{"test":"whether water temperature changes how fast sugar dissolves","change":"temperature","wrong":"dissolving time"},
	{"test":"which soil helps a seedling grow best","change":"soil type","wrong":"seedling height"},
	{"test":"whether a ramp changes a toy car's travel distance","change":"ramp height","wrong":"travel range"},
	{"test":"which material keeps an ice cube cold longest","change":"wrap type","wrong":"melt time"},
]
const SCIENCE_ADVANCED_FACTS: Array = [
	{"level":3,"topic":"science_life","hint":"hint.science.life","expression":"In a food chain, a plant is a...","answer":"producer","distractor":"consumer"},
	{"level":3,"topic":"science_earth","hint":"hint.science.earth","expression":"Day and night happen as Earth...","answer":"rotates","distractor":"stops"},
	{"level":3,"topic":"science_physical","hint":"hint.science.physical","expression":"Sound cannot travel through...","answer":"a vacuum","distractor":"water"},
	{"level":4,"topic":"science_biology","hint":"hint.science.biology","expression":"A cell's DNA is mainly stored in its...","answer":"nucleus","distractor":"membrane"},
	{"level":4,"topic":"science_chemistry","hint":"hint.science.chemistry","expression":"Covalent bonds ___ electrons.","answer":"share","distractor":"transfer"},
	{"level":4,"topic":"science_physics","hint":"hint.science.physics","expression":"Electric current is measured in...","answer":"amperes","distractor":"volts"},
	{"level":5,"topic":"science_biology","hint":"hint.science.biology","expression":"DNA pairs adenine with...","answer":"thymine","distractor":"uracil"},
	{"level":5,"topic":"science_chemistry","hint":"hint.science.chemistry","expression":"Oxidation is the ___ of electrons.","answer":"loss","distractor":"gain"},
	{"level":5,"topic":"science_physics","hint":"hint.science.physics","expression":"Newton's second law: F = ?","answer":"m × a","distractor":"m + a"},
	{"level":5,"topic":"science_earth","hint":"hint.science.earth","expression":"Most earthquakes occur near...","answer":"plate boundaries","distractor":"plate centers"},
]
const SCIENCE_SCENARIOS: Array[String] = ["a cyclist", "a train", "a runner", "a small robot", "a river boat", "a delivery van", "a toy car", "a hiking group"]
const SCIENCE_UNITS: Array[String] = ["km", "m"]


static func generate(rng: RandomNumberGenerator, area: String, level: int) -> Dictionary:
	match area:
		"reading":
			return _reading_question(rng, clampi(level, 1, 5))
		"russian", "spanish":
			return _language_question(rng, area, clampi(level, 1, 5))
		"science":
			return _science_question(rng, clampi(level, 1, 5))
	return {}


static func _question(expression: String, answer: String, distractor: String, topic: String, hint: String, kind: String = "generated_knowledge", extra: Dictionary = {}) -> Dictionary:
	var result := {
		"expression": expression,
		"answer": answer,
		"distractor": distractor if distractor != answer else answer + "?",
		"topic": topic,
		"hint_key": hint,
		"kind": kind,
	}
	for key: String in extra:
		result[key] = extra[key]
	return result


static func _pick(rng: RandomNumberGenerator, items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]


static func _reading_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var family := rng.randi_range(0, 4)
	if level <= 2:
		if family == 0:
			return _reading_rhyme(rng)
		if family <= 2:
			return _reading_story(rng)
		return _reading_vocabulary(rng, level)
	if family == 0:
		return _reading_grammar(rng)
	if family == 1:
		return _reading_vocabulary(rng, level)
	if family == 2 and level >= 4:
		return _reading_literature(rng)
	if family == 3 and level >= 3:
		return _reading_prefix(rng)
	return _reading_story(rng)


static func _reading_rhyme(rng: RandomNumberGenerator) -> Dictionary:
	var family: Array = _pick(rng, READING_RHYMES)
	var other: Array = _pick(rng, READING_RHYMES)
	while other == family:
		other = _pick(rng, READING_RHYMES)
	var target := str(_pick(rng, family))
	var answer_pool: Array = family.duplicate()
	answer_pool.erase(target)
	var answer := str(_pick(rng, answer_pool))
	var distractor := str(_pick(rng, other))
	var form := rng.randi_range(0, 2)
	var expression := "Which word rhymes with %s?" % target
	if form == 1:
		expression = "Choose a rhyme for %s." % target
	elif form == 2:
		expression = "Find the word with the same ending sound as %s." % target
	return _question(expression, answer, distractor, "reading_phonics", "hint.reading.phonics", "generated_reading_rhyme")


static func _reading_story(rng: RandomNumberGenerator, _level: int = 1) -> Dictionary:
	var name := str(_pick(rng, NAMES))
	var verb_data: Dictionary = _pick(rng, READING_TRANSITIVE_VERBS)
	var past_verb := str(verb_data.past)
	var base_verb := str(verb_data.base)
	var object := str(_pick(rng, verb_data.objects))
	var scene := "%s %s the %s." % [name, past_verb, object]
	var form := rng.randi_range(0, 3)
	var expression := "In '%s', what did %s %s?" % [scene, name, base_verb]
	if form == 1:
		expression = "Read '%s' — what did %s %s?" % [scene, name, base_verb]
	elif form == 2:
		expression = "What did %s %s in the sentence '%s'?" % [name, base_verb, scene]
	elif form == 3:
		expression = "Which thing did %s %s? '%s'" % [name, base_verb, scene]
	var distractor := str(_pick(rng, READING_OBJECTS))
	while distractor == object:
		distractor = str(_pick(rng, READING_OBJECTS))
	return _question(expression, object, distractor, "reading_comprehension", "hint.reading.comprehension", "generated_reading_detail")


static func _reading_vocabulary(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for item: Dictionary in READING_WORD_PAIRS:
		if int(item.level) <= level:
			eligible.append(item)
	var entry: Dictionary = _pick(rng, eligible)
	var use_synonym := rng.randi_range(0, 1) == 0
	var answer := str(entry.synonym) if use_synonym else str(entry.opposite)
	var distractor := str(entry.opposite) if use_synonym else str(entry.synonym)
	var word := str(entry.word)
	var form := rng.randi_range(0, 3)
	var expression := "A word like %s is..." % word if use_synonym else "The opposite of %s is..." % word
	if form == 1:
		expression = "Which word means nearly the same as %s?" % word if use_synonym else "Which word means the reverse of %s?" % word
	elif form == 2:
		expression = "Choose a synonym for %s." % word if use_synonym else "Choose an antonym for %s." % word
	elif form == 3:
		expression = "In vocabulary, %s means something close to..." % word if use_synonym else "Which choice contrasts with %s?" % word
	var topic := "reading_vocabulary"
	var hint := "hint.reading.vocabulary"
	if level == 1 and use_synonym:
		topic = "reading_vocabulary"
	return _question(expression, answer, distractor, topic, hint, "generated_reading_vocabulary")


static func _reading_grammar(rng: RandomNumberGenerator) -> Dictionary:
	var noun := str(_pick(rng, READING_NOUNS))
	var adjective := str(_pick(rng, READING_ADJECTIVES))
	var verb := str(_pick(rng, READING_VERBS))
	var sentence := "The %s %s %s." % [adjective, noun, verb]
	var form := rng.randi_range(0, 1)
	if form == 0:
		var other_adjective := str(_pick(rng, READING_ADJECTIVES))
		while other_adjective == adjective:
			other_adjective = str(_pick(rng, READING_ADJECTIVES))
		return _question("In '%s' which word describes the %s?" % [sentence, noun], adjective, other_adjective, "reading_grammar", "hint.reading.grammar", "generated_reading_adjective")
	var other_verb := str(_pick(rng, READING_VERBS))
	while other_verb == verb:
		other_verb = str(_pick(rng, READING_VERBS))
	return _question("In '%s' which word shows the action?" % sentence, verb, other_verb, "reading_grammar", "hint.reading.grammar", "generated_reading_verb")


static func _reading_prefix(rng: RandomNumberGenerator) -> Dictionary:
	var entry: Dictionary = _pick(rng, READING_PREFIXES)
	var form := rng.randi_range(0, 2)
	var expression := "What does the prefix %s mean?" % str(entry.prefix)
	if form == 1:
		expression = "In '%s', %s means..." % [str(entry.prefix) + str(entry.word), str(entry.prefix)]
	elif form == 2:
		expression = "Which meaning matches the prefix %s?" % str(entry.prefix)
	var meanings: Array[String] = ["again", "not", "before", "wrongly", "opposite of", "too much", "under", "between"]
	var distractor := str(_pick(rng, meanings))
	while distractor == str(entry.meaning):
		distractor = str(_pick(rng, meanings))
	return _question(expression, str(entry.meaning), distractor, "reading_vocabulary", "hint.reading.vocabulary", "generated_reading_prefix")


static func _reading_literature(rng: RandomNumberGenerator) -> Dictionary:
	var form := rng.randi_range(0, 2)
	if form == 0:
		var name := str(_pick(rng, NAMES))
		var adjective := str(_pick(rng, READING_ADJECTIVES))
		var comparison := str(_pick(rng, READING_COMPARISONS))
		var expression := "%s was as %s as %s. This is a..." % [name, adjective, comparison]
		return _question(expression, "simile", "metaphor", "reading_literature", "hint.reading.literature", "generated_reading_figure")
	if form == 1:
		var object := str(_pick(rng, READING_ADJECTIVE_OBJECTS))
		var action := str(_pick(rng, READING_HUMAN_ACTIONS))
		return _question("The %s %s. This gives it a human action: which device?" % [object, action], "personification", "alliteration", "reading_literature", "hint.reading.literature", "generated_reading_figure")
	var object := str(_pick(rng, READING_ADJECTIVE_OBJECTS))
	var role := str(_pick(rng, ["a beehive", "a maze", "a furnace", "a library", "a playground", "a stage"]))
	return _question("The %s was %s. This direct comparison is a..." % [object, role], "metaphor", "simile", "reading_literature", "hint.reading.literature", "generated_reading_figure")


static func _language_question(rng: RandomNumberGenerator, area: String, level: int) -> Dictionary:
	var use_grammar := false
	if level >= 5:
		use_grammar = rng.randi_range(0, 1) == 0
	elif level >= 2:
		use_grammar = rng.randi_range(0, 4) == 0
	if use_grammar:
		if area == "spanish":
			return _spanish_grammar(rng, level)
		return _russian_grammar(rng, level)
	return _language_vocabulary(rng, area, level)


static func _language_vocabulary(rng: RandomNumberGenerator, area: String, level: int) -> Dictionary:
	var words: Array = SPANISH_WORDS if area == "spanish" else RUSSIAN_WORDS
	var eligible: Array[Dictionary] = []
	for item: Dictionary in words:
		if int(item.level) <= level:
			eligible.append(item)
	var target: Dictionary = _pick(rng, eligible)
	var other: Dictionary = _pick(rng, eligible)
	while str(other.word) == str(target.word):
		other = _pick(rng, eligible)
	var to_target := rng.randi_range(0, 1) == 0
	var answer := str(target.word) if to_target else str(target.en)
	var distractor := str(other.word) if to_target else str(other.en)
	var language := "Spanish" if area == "spanish" else "Russian"
	var name := str(_pick(rng, NAMES))
	var style := rng.randi_range(0, 5)
	var expression := "How do you say '%s' in %s?" % [str(target.en), language]
	if to_target:
		match style:
			1:
				expression = "Translate into %s: '%s'." % [language, str(target.en)]
			2:
				expression = "Choose the %s word for '%s'." % [language, str(target.en)]
			3:
				expression = "%s asks: what's %s for '%s'?" % [name, language, str(target.en)]
			4:
				expression = "Complete the translation — %s for '%s': ?" % [language, str(target.en)]
			5:
				expression = "Pick the word that means '%s' in %s." % [str(target.en), language]
	else:
		expression = "What does '%s' mean in English?" % str(target.word)
		match style:
			1:
				expression = "Translate '%s' into English." % str(target.word)
			2:
				expression = "Choose the meaning of the %s word '%s'." % [language, str(target.word)]
			3:
				expression = "%s asks: what does '%s' mean?" % [name, str(target.word)]
			4:
				expression = "In English, '%s' means..." % str(target.word)
			5:
				expression = "Pick the English translation of '%s'." % str(target.word)
	var topic := area + "_vocabulary"
	var hint := "hint." + area + ".vocabulary"
	if style == 3 or style == 4:
		topic = area + "_phrases"
		hint = "hint." + area + ".phrases"
	return _question(expression, answer, distractor, topic, hint, "generated_%s_translation" % area)


static func _spanish_grammar(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level >= 5:
		var advanced_form := rng.randi_range(0, 2)
		if advanced_form == 0:
			return _spanish_subjunctive(rng)
		if advanced_form == 1:
			return _spanish_conditional(rng)
	if level >= 2 and rng.randi_range(0, 2) == 0:
		return _spanish_agreement(rng)
	var tense := "present"
	var table: Array = SPANISH_PRESENT
	if level >= 3 and rng.randi_range(0, 1) == 1:
		tense = "preterite"
		table = SPANISH_PRETERITE
	var verb_data: Dictionary = _pick(rng, table)
	var subject_index := rng.randi_range(0, SPANISH_SUBJECTS.size() - 1)
	var forms: Array = verb_data.forms
	var answer := str(forms[subject_index])
	var distractor := str(forms[(subject_index + rng.randi_range(1, forms.size() - 1)) % forms.size()])
	var expression := "%s · %s (%s): ?" % [str(verb_data.verb), str(SPANISH_SUBJECTS[subject_index]), tense]
	if rng.randi_range(0, 1) == 1:
		expression = "For '%s' in the %s, choose the form for %s." % [str(verb_data.verb), tense, str(SPANISH_SUBJECTS[subject_index])]
	return _question(expression, answer, distractor, "spanish_grammar", "hint.spanish.grammar", "generated_spanish_conjugation", {
		"verb": str(verb_data.verb), "subject_index": subject_index, "tense": tense, "conjugation_forms": forms,
	})


static func _spanish_subjunctive(rng: RandomNumberGenerator) -> Dictionary:
	var verb_data: Dictionary = _pick(rng, SPANISH_SUBJUNCTIVE)
	var subject_index := rng.randi_range(0, 4)
	var subjects: Array[String] = ["yo", "tú", "él", "nosotros", "ellos"]
	var forms: Array = verb_data.forms
	var indicative_forms: Array = _spanish_present_forms(str(verb_data.verb))
	var answer := str(forms[subject_index])
	var distractor := str(indicative_forms[subject_index])
	var expression := "Subjunctive: es posible que %s ___ (%s)." % [subjects[subject_index], str(verb_data.verb)]
	if subject_index > 0 and rng.randi_range(0, 1) == 1:
		var triggers: Array[String] = ["quiero que", "es importante que", "espero que"]
		expression = "Subjunctive: %s %s ___ (%s)." % [str(_pick(rng, triggers)), subjects[subject_index], str(verb_data.verb)]
	return _question(expression, answer, distractor, "spanish_grammar", "hint.spanish.subjunctive", "generated_spanish_subjunctive", {
		"verb": str(verb_data.verb), "subject_index": subject_index, "tense": "subjunctive",
		"conjugation_forms": forms, "indicative_forms": indicative_forms,
	})


static func _spanish_conditional(rng: RandomNumberGenerator) -> Dictionary:
	var verb_data: Dictionary = _pick(rng, SPANISH_CONDITIONAL)
	var subject_index := rng.randi_range(0, 4)
	var subjects: Array[String] = ["yo", "tú", "él", "nosotros", "ellos"]
	var forms: Array = verb_data.forms
	var indicative_forms: Array = _spanish_present_forms(str(verb_data.verb))
	var answer := str(forms[subject_index])
	var distractor := str(indicative_forms[subject_index])
	var expression := "Conditional ('would'): %s ___ (%s)." % [subjects[subject_index], str(verb_data.verb)]
	return _question(expression, answer, distractor, "spanish_grammar", "hint.spanish.conditional", "generated_spanish_conditional", {
		"verb": str(verb_data.verb), "subject_index": subject_index, "tense": "conditional",
		"conjugation_forms": forms, "indicative_forms": indicative_forms,
	})


static func _spanish_present_forms(verb: String) -> Array:
	for verb_data: Dictionary in SPANISH_PRESENT:
		if str(verb_data.verb) == verb:
			return verb_data.forms
	return []


static func _spanish_agreement(rng: RandomNumberGenerator) -> Dictionary:
	var noun_data: Dictionary = _pick(rng, SPANISH_NOUNS)
	var plural := rng.randi_range(0, 1) == 1
	var adjective: String = str(_pick(rng, SPANISH_ADJECTIVES))
	var stem := adjective.trim_suffix("o")
	var correct := stem + ("a" if noun_data.gender == "f" else "o")
	if plural:
		correct += "s"
	var wrong := stem + ("o" if noun_data.gender == "f" else "a")
	if plural:
		wrong += "s"
	var article := "las" if plural and noun_data.gender == "f" else ("los" if plural else ("la" if noun_data.gender == "f" else "el"))
	var noun := str(noun_data.plural) if plural else str(noun_data.word)
	var expression := "%s %s · agree the adjective '%s': ?" % [article, noun, adjective]
	if rng.randi_range(0, 1) == 1:
		expression = "With '%s %s', choose the matching form of '%s'." % [article, noun, adjective]
	return _question(expression, correct, wrong, "spanish_grammar", "hint.spanish.grammar", "generated_spanish_agreement")


static func _russian_grammar(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level >= 5:
		var advanced_form := rng.randi_range(0, 3)
		if advanced_form == 0:
			return _russian_aspect(rng)
		if advanced_form == 1:
			return _russian_conditional(rng)
	var form := rng.randi_range(0, 3)
	if form == 0:
		var verb_data: Dictionary = _pick(rng, RUSSIAN_PRESENT)
		var subject_index := rng.randi_range(0, 5)
		var forms: Array = verb_data.forms
		var answer := str(forms[subject_index])
		var distractor := str(forms[(subject_index + rng.randi_range(1, 5)) % forms.size()])
		var expression := "%s · %s (present): ?" % [str(verb_data.verb), str(RUSSIAN_SUBJECTS[subject_index])]
		if rng.randi_range(0, 1) == 1:
			expression = "For '%s', choose the present form for %s." % [str(verb_data.verb), str(RUSSIAN_SUBJECTS[subject_index])]
		return _question(expression, answer, distractor, "russian_grammar", "hint.russian.grammar", "generated_russian_present", {"subject_index": subject_index})
	if form == 1 and level >= 4:
		var verb_data: Dictionary = _pick(rng, RUSSIAN_PAST)
		var subject_index := rng.randi_range(0, 3)
		var forms: Array = verb_data.forms
		var answer := str(forms[subject_index])
		var distractor := str(forms[(subject_index + rng.randi_range(1, 3)) % forms.size()])
		var expression := "Past tense of '%s' for %s: ?" % [str(verb_data.verb), str(RUSSIAN_PAST_SUBJECTS[subject_index])]
		if rng.randi_range(0, 1) == 1:
			expression = "%s вчера ___ (%s)" % [str(RUSSIAN_PAST_SUBJECTS[subject_index]).capitalize(), str(verb_data.verb)]
		return _question(expression, answer, distractor, "russian_grammar", "hint.russian.grammar", "generated_russian_past", {"subject_index": subject_index})
	if form == 2 and level >= 4:
		var future_verb := str(_pick(rng, RUSSIAN_FUTURE_VERBS))
		var subject_index := rng.randi_range(0, 5)
		var answer := "%s %s" % [str(RUSSIAN_FUTURE[subject_index]), future_verb]
		var alternate_index := (subject_index + rng.randi_range(1, 5)) % RUSSIAN_FUTURE.size()
		var distractor := "%s %s" % [str(RUSSIAN_FUTURE[alternate_index]), future_verb]
		return _question("Future: '%s' · %s: ?" % [future_verb, str(RUSSIAN_SUBJECTS[subject_index])], answer, distractor, "russian_grammar", "hint.russian.grammar", "generated_russian_future")
	if level >= 4:
		var noun_data: Dictionary = _pick(rng, RUSSIAN_NOUNS)
		var case_index := rng.randi_range(1, RUSSIAN_CASES.size() - 1)
		var forms: Array = noun_data.forms
		var answer := str(forms[case_index])
		var wrong_index := (case_index + rng.randi_range(1, RUSSIAN_CASES.size() - 1)) % RUSSIAN_CASES.size()
		var distractor := str(forms[wrong_index])
		while distractor == answer:
			wrong_index = (wrong_index + 1) % RUSSIAN_CASES.size()
			distractor = str(forms[wrong_index])
		var expression := "'%s' · %s case: ?" % [str(noun_data.word), str(RUSSIAN_CASES[case_index])]
		return _question(expression, answer, distractor, "russian_grammar", "hint.russian.grammar", "generated_russian_case", {"case_index": case_index})
	return _language_vocabulary(rng, "russian", level)


static func _russian_aspect(rng: RandomNumberGenerator) -> Dictionary:
	var pair: Dictionary = _pick(rng, RUSSIAN_ASPECT_PAIRS)
	var expression := "Russian verb aspect: which means '%s'?" % str(pair.meaning)
	return _question(expression, str(pair.perfective), str(pair.imperfective), "russian_grammar", "hint.russian.aspect", "generated_russian_aspect", {
		"imperfective": str(pair.imperfective), "perfective": str(pair.perfective),
	})


static func _russian_conditional(rng: RandomNumberGenerator) -> Dictionary:
	var examples: Array[Dictionary] = [
		{"expression":"Я бы прочитал книгу. What does бы add?", "answer":"hypothetical", "distractor":"definite past"},
		{"expression":"Она бы написала письмо. What does бы signal?", "answer":"conditional", "distractor":"present action"},
		{"expression":"Мы бы посмотрели фильм. This expresses...", "answer":"hypothetical", "distractor":"completed fact"},
	]
	var item: Dictionary = _pick(rng, examples)
	return _question(str(item.expression), str(item.answer), str(item.distractor), "russian_grammar", "hint.russian.conditional", "generated_russian_conditional")


static func _science_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 1:
		match rng.randi_range(0, 2):
			0:
				return _science_animal(rng)
			1:
				return _science_plant(rng)
			_:
				return _science_sense(rng)
	if level == 2:
		match rng.randi_range(0, 3):
			0:
				return _science_state(rng)
			1:
				return _science_animal(rng)
			2:
				return _science_earth_force(rng)
			_:
				return _science_plant(rng)
	if level == 3:
		match rng.randi_range(0, 3):
			0:
				return _science_method(rng)
			1:
				return _science_speed(rng)
			2:
				return _science_state(rng)
			_:
				return _science_advanced_fact(rng, level)
	if level == 4:
		match rng.randi_range(0, 3):
			0:
				return _science_force(rng)
			1:
				return _science_density(rng)
			2:
				return _science_advanced_fact(rng, level)
			_:
				return _science_speed(rng)
	if level >= 5:
		match rng.randi_range(0, 3):
			0:
				return _science_voltage(rng)
			1:
				return _science_power(rng)
			2:
				return _science_density(rng)
			_:
				return _science_advanced_fact(rng, level)
	return _science_animal(rng)


static func _science_animal(rng: RandomNumberGenerator) -> Dictionary:
	var item: Dictionary = _pick(rng, SCIENCE_ANIMALS)
	var name := str(_pick(rng, NAMES))
	var distractor := str(_pick(rng, SCIENCE_CLASSES))
	while distractor == str(item["class"]):
		distractor = str(_pick(rng, SCIENCE_CLASSES))
	var form := rng.randi_range(0, 2)
	var expression := "%s saw a %s. Which animal group is it?" % [name, str(item.animal)]
	if form == 1:
		expression = "%s is sorting animals: a %s is a..." % [name, str(item.animal)]
	elif form == 2:
		expression = "Which group does %s put a %s in?" % [name, str(item.animal)]
	return _question(expression, str(item["class"]), distractor, "science_life", "hint.science.life", "generated_science_classification")


static func _science_plant(rng: RandomNumberGenerator) -> Dictionary:
	var item: Dictionary = _pick(rng, SCIENCE_PLANT_PARTS)
	var name := str(_pick(rng, NAMES))
	var form := rng.randi_range(0, 2)
	var expression := "%s investigates a plant. Which part %s?" % [name, str(item.job)]
	if form == 1:
		expression = "Which plant part helps %s %s?" % [name, str(item.job)]
	elif form == 2:
		expression = "%s labels the part that will %s. Which part?" % [name, str(item.job)]
	var other: Dictionary = _pick(rng, SCIENCE_PLANT_PARTS)
	while str(other.part) == str(item.part):
		other = _pick(rng, SCIENCE_PLANT_PARTS)
	return _question(expression, str(item.part), str(other.part), "science_life", "hint.science.life", "generated_science_plant_part", {
		"plant_part": str(item.part), "plant_job": str(item.job),
	})


static func _science_sense(rng: RandomNumberGenerator) -> Dictionary:
	var item: Dictionary = _pick(rng, SCIENCE_SENSES)
	var name := str(_pick(rng, NAMES))
	var other: Dictionary = _pick(rng, SCIENCE_SENSES)
	while str(other.organ) == str(item.organ):
		other = _pick(rng, SCIENCE_SENSES)
	var expression := "%s wants to %s. Which body part helps?" % [name, str(item.sense)]
	if rng.randi_range(0, 1) == 1:
		expression = "To %s, %s uses their..." % [str(item.sense), name]
	return _question(expression, str(item.organ), str(other.organ), "science_life", "hint.science.life", "generated_science_sense")


static func _science_state(rng: RandomNumberGenerator) -> Dictionary:
	var item: Dictionary = _pick(rng, SCIENCE_STATES)
	var name := str(_pick(rng, NAMES))
	var other_states: Array[String] = ["solid", "liquid", "gas"]
	var distractor := str(_pick(rng, other_states))
	while distractor == str(item.state):
		distractor = str(_pick(rng, other_states))
	var form := rng.randi_range(0, 2)
	var expression := "%s observes %s. Its state of matter is..." % [name, str(item.thing)]
	if form == 1:
		expression = "%s asks: is %s a solid, liquid, or gas?" % [name, str(item.thing)]
	elif form == 2:
		expression = "For %s's sample of %s, choose the state of matter." % [name, str(item.thing)]
	return _question(expression, str(item.state), distractor, "science_physical", "hint.science.physical", "generated_science_state", {
		"science_thing": str(item.thing), "science_state": str(item.state),
	})


static func _science_earth_force(rng: RandomNumberGenerator) -> Dictionary:
	var facts: Array = [
		{"q":"What causes day and night?", "a":"Earth rotates", "d":"Earth stops"},
		{"q":"The Moon travels around...", "a":"Earth", "d":"the Sun"},
		{"q":"What does the Sun give Earth?", "a":"light and warmth", "d":"rocks and soil"},
		{"q":"Which force pulls objects toward Earth?", "a":"gravity", "d":"magnetism"},
		{"q":"A magnet can attract objects made of...", "a":"iron", "d":"wood"},
		{"q":"Clouds are made mostly of tiny...", "a":"water droplets", "d":"grains of sand"},
		{"q":"Which material lets light pass through?", "a":"clear glass", "d":"a wooden board"},
	]
	var item: Dictionary = _pick(rng, facts)
	var name := str(_pick(rng, NAMES))
	var form := rng.randi_range(0, 1)
	var expression := "%s asks: %s" % [name, str(item.q)]
	if form == 1:
		expression = "%s's science card: %s" % [name, str(item.q)]
	var topic := "science_earth" if expression.to_lower().contains("moon") or expression.to_lower().contains("sun") or expression.to_lower().contains("day") or expression.to_lower().contains("cloud") else "science_physical"
	var hint := "hint.science.earth" if topic == "science_earth" else "hint.science.physical"
	return _question(expression, str(item.a), str(item.d), topic, hint, "generated_science_everyday_fact")


static func _science_method(rng: RandomNumberGenerator) -> Dictionary:
	var item: Dictionary = _pick(rng, SCIENCE_METHODS)
	var name := str(_pick(rng, NAMES))
	var form := rng.randi_range(0, 2)
	var expression := "%s tests %s. What should be changed?" % [name, str(item.test)]
	if form == 1:
		expression = "In %s's fair test of %s, the independent variable is..." % [name, str(item.test)]
	elif form == 2:
		expression = "Which factor should %s vary to test %s?" % [name, str(item.test)]
	return _question(expression, str(item.change), str(item.wrong), "science_methods", "hint.science.methods", "generated_science_variable")


static func _science_advanced_fact(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for item: Dictionary in SCIENCE_ADVANCED_FACTS:
		if int(item.level) == level:
			eligible.append(item)
	var item: Dictionary = _pick(rng, eligible)
	var expression := str(item.expression)
	if rng.randi_range(0, 1) == 1:
		expression = "Recall: %s" % expression
	return _question(expression, str(item.answer), str(item.distractor), str(item.topic), str(item.hint), "generated_science_concept")


static func _science_speed(rng: RandomNumberGenerator) -> Dictionary:
	var time_hours := rng.randi_range(2, 18)
	var speed := rng.randi_range(3, 45)
	var distance := time_hours * speed
	var scenario := str(_pick(rng, SCIENCE_SCENARIOS))
	var answer := "%d km/h" % speed
	var wrong_value := distance + time_hours
	if wrong_value == speed:
		wrong_value += 2
	var distractor := "%d km/h" % wrong_value
	var expression := "%s travels %d km in %d h. Average speed?" % [scenario.capitalize(), distance, time_hours]
	if rng.randi_range(0, 1) == 1:
		expression = "A %s covers %d km over %d hours; speed = ?" % [scenario, distance, time_hours]
	return _question(expression, answer, distractor, "science_physics", "hint.science.physics", "generated_science_speed", {
		"distance": distance, "time_hours": time_hours, "expected_speed": speed,
	})


static func _science_force(rng: RandomNumberGenerator) -> Dictionary:
	var mass := rng.randi_range(2, 80)
	var acceleration := rng.randi_range(2, 15)
	var force := mass * acceleration
	var distractor_value := mass + acceleration
	if distractor_value == force:
		distractor_value += 1
	var expression := "A %d kg cart accelerates at %d m/s². Net force?" % [mass, acceleration]
	if rng.randi_range(0, 1) == 1:
		expression = "Using F = m × a, find force for %d kg at %d m/s²." % [mass, acceleration]
	return _question(expression, "%d N" % force, "%d N" % distractor_value, "science_physics", "hint.science.physics", "generated_science_force", {
		"mass": mass, "acceleration": acceleration, "expected_force": force,
	})


static func _science_density(rng: RandomNumberGenerator) -> Dictionary:
	var density := rng.randi_range(2, 30)
	var volume := rng.randi_range(2, 30)
	var mass := density * volume
	var expression := "A sample has mass %d g and volume %d cm³. Density?" % [mass, volume]
	if rng.randi_range(0, 1) == 1:
		expression = "Density = mass ÷ volume. %d g in %d cm³ = ?" % [mass, volume]
	var wrong := mass + volume
	if wrong == density:
		wrong += 1
	return _question(expression, "%d g/cm³" % density, "%d g/cm³" % wrong, "science_chemistry", "hint.science.chemistry", "generated_science_density", {
		"mass": mass, "volume": volume, "expected_density": density,
	})


static func _science_voltage(rng: RandomNumberGenerator) -> Dictionary:
	var current := rng.randi_range(2, 15)
	var resistance := rng.randi_range(2, 40)
	var voltage := current * resistance
	var wrong := current + resistance
	if wrong == voltage:
		wrong += 1
	var expression := "A circuit has %d A and %d Ω. By V = I × R, voltage?" % [current, resistance]
	if rng.randi_range(0, 1) == 1:
		expression = "Current is %d A and resistance %d Ω. Find voltage." % [current, resistance]
	return _question(expression, "%d V" % voltage, "%d V" % wrong, "science_physics", "hint.science.physics", "generated_science_voltage", {
		"current": current, "resistance": resistance, "expected_voltage": voltage,
	})


static func _science_power(rng: RandomNumberGenerator) -> Dictionary:
	var power := rng.randi_range(5, 100)
	var time := rng.randi_range(2, 60)
	var work := power * time
	var wrong := work + time
	if wrong == power:
		wrong += 1
	var expression := "A machine transfers %d J in %d s. Average power?" % [work, time]
	if rng.randi_range(0, 1) == 1:
		expression = "Power = work ÷ time. %d J over %d s = ?" % [work, time]
	return _question(expression, "%d W" % power, "%d W" % wrong, "science_physics", "hint.science.physics", "generated_science_power", {
		"work": work, "time": time, "expected_power": power,
	})
