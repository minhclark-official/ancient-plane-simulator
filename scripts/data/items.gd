class_name Items
extends RefCounted
## Collectible items thrown at the aircraft by sandstorms, plus PDA mail / web content.

const MAX_ITEMS := 12

const DATA := {
	"bible": {
		"name": "ALEX BIBLE", "sub": "CHAPTER 69", "kind": "book", "img": "res://assets/sprites/alex_bible.jpg", "kb": 412,
		"desc": "A hefty paperback that arrived through the windshield at 215 knots. Smells of sand. Spine uncracked. Pages: infinite.",
		"meta": [["TITLE", "ALEX BIBLE"], ["SUBTITLE", "CHAPTER 69"], ["AUTHOR", "ALEX"], ["FORMAT", "PAPERBACK"], ["PAGES", "INFINITE (5 READABLE)"],
			["ISBN", "969-6969-69-6"], ["CLASS", "SCRIPTURE / DUBIOUS"], ["MASS", "0.41 KG"], ["CONDITION", "SANDY"]],
		"pages": [
			["ALEX BIBLE\nCHAPTER 69\n\nIn the beginning there was a runway, and the runway was good. And the pilot said: let there be autoland. And there was autoland. And it was fine."],
			["CHAPTER 69  (CONT.)\n\nAnd lo, the airplane did descend toward the great pyramid MASTER KING, which was built of bricks, and every brick had a face, and the faces did stare.\n\nAnd the pilot said: this is fine."],
			["THE BOOK OF HARRY\n\nHarry went out to the runway at dusk and a plane fell upon him. And the people sang. And the song was long.\n\nDo not question the song."],
			["THE LAW OF THREE\n\nWhosoever shall gather three copies of this book shall be granted a descent that cannot be refused.\n\n(Seek the secret in the sandstorm. Bring the bibles.)"],
			["COLOPHON\n\nPrinted on a paper that was once a tree, which was once a seed, which was once a rumour.\n\nTHE END. (IT IS NOT THE END.)"],
		],
	},
	"booklet": {
		"name": "NAICOLIOUS DATA BOOKLET", "sub": "BY THE MAN WHO SPEAKS IN CHEMISTRY", "kind": "doc", "img": "res://assets/sprites/nb_cover.jpg", "kb": 938,
		"desc": "A slim reference booklet. Cover: a man with his arms crossed against a drawing of an atom. Inside: a very rotated periodic table.",
		"meta": [["TITLE", "NAICOLIOUS DATA BOOKLET"], ["AUTHOR", "THE MAN WHO SPEAKS IN CHEMISTRY"], ["FORMAT", "BOOKLET / SCANNED"], ["PAGES", "4 (COVER + DATA)"],
			["CONTENTS", "PERIODIC TABLE; ISOTOPES; REDUCTION POTENTIALS"]],
		"images": [["res://assets/sprites/nb_cover.jpg", "FRONT COVER"], ["res://assets/sprites/nb_pages.jpg", "PERIODIC TABLE - PROPERTIES OF THE ELEMENTS"],
			["res://assets/sprites/nb_page3.jpg", "PAGE 3 - DEFINE AN ISOTOPE"], ["res://assets/sprites/nb_page4.jpg", "PAGE 4 - STANDARD REDUCTION POTENTIAL AT 298 K"]],
	},
	"dvd": {
		"name": "THE DARK KNIGHT", "sub": "DVD-ROM  REGION FREE", "kind": "disc", "img": "res://assets/sprites/dvd.jpg", "kb": 2048,
		"desc": "A DVD in a slightly bent case. The cover features a man in a suit who is definitely not who the title promises.",
		"meta": [["TITLE", "THE DARK KNIGHT"], ["MEDIA", "DVD-ROM  4.7 GB"], ["REGION", "ALL"], ["SURFACE", "SCRATCHED / SANDED"], ["STATUS", "UNREADABLE"], ["CONDITION", "GRITTY"]],
	},
	"danilo": {
		"name": "DANILO TUNA FISH", "sub": "THE COMMERCIAL  AUDIO DISC", "kind": "audio", "img": "res://assets/sprites/danilo_cover.jpg", "kb": 719,
		"desc": "A shiny disc in a blue case. The cover: a man who is also a tuna, on a can, on a cover. Reads fine. Opens in the audio player.",
		"meta": [["TITLE", "DANILO TUNA FISH"], ["MEDIA", "AUDIO DISC"], ["TRACK", "01  THE COMMERCIAL"], ["FILE", "DANILO_COMMERCIAL.MP3"], ["TAGLINE", "REAL TUNA. REAL DANILO."]],
		"audio": "danilo",
	},
}

const MAIL: Array = [
	["ANCIENT AIR OPS", "WELCOME ABOARD 001", "Welcome to Ancient Air flight 001. Destination: MASTER KING. Please do not ask why the runway is made of bricks. Autoland is fully certified in a way we would rather not discuss."],
	["PERLICA WAYNE ENT.", "YOUR NEW PDA-84", "Congratulations on your PDA-84. It maps, stores, reads and surfs. It does not make coffee. Items you find in sandstorm debris are scanned and stored automatically."],
	["DESERT WEATHER SVC", "SANDSTORM ADVISORY", "Scattered sandstorms. Debris includes rocks, crates, barrels, planks, books and discs. Keep your eyes open. Keep your pockets open."],
	["HARRY", "RE: THE CONCERT", "Heard the concert is at night. Do not go to the runway at dusk. I am not saying why. I am saying do not."],
]

const WEB := {
	"home": "ANCIENTAIR.NET\n\nWELCOME TO THE ANCIENT AIR WEB PORTAL\n\n>> NEWS      LATEST FROM OPS\n>> FORUM     PILOT CHATTER\n\nBEST VIEWED IN 640X480 AT 16 COLOURS.\nTHIS SITE HAS BEEN VISITED 000069 TIMES.",
	"news": "NEWS\n\nMASTER KING PYRAMID DENIES HAVING FACES\n  \"Those are just very detailed bricks,\" says spokesbrick.\n\nJRNA RUNWAY REPAINTED IN RECORD TIME\n  Locals report it now says \"36\" in a friendlier font.\n\nBOOK RAINS FROM SKY AGAIN\n  Author unavailable for comment.",
	"forum": "FORUM\n\nRE: RE: IS THE PYRAMID LOOKING AT US?  (47 REPLIES)\n  user_a: no\n  user_b: yes\n  user_c: it winked\n\nRE: BEST WAY TO SURVIVE A SANDSTORM\n  user_d: have you tried not being in it\n\nRE: WHO WROTE THE NAICOLIOUS BOOKLET\n  user_e: a man",
}


static func info(id: String) -> Dictionary:
	return DATA.get(id, {})
