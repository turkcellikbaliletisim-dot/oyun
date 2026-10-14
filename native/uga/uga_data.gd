extends RefCounted
# UGACHA tarzı mod için sabit veriler: kahramanlar, düşmanlar, dünyalar, iksirler.

const SLOTS = 15
const COLS = 5
const MAX_STARS = 6
const TICK = 0.05
const START_GOLD = 60
const START_SUMMON_COST = 10
const CASTLE_HP = 20

# Yıldız başına hasar ve hız çarpanı.
const STAR_DMG = [1.0, 2.3, 5.2, 11.5, 25.0, 55.0]
const STAR_SPEED = [1.0, 1.08, 1.16, 1.25, 1.35, 1.5]

const HEROES = {
	"kilic": {"reach": 0.42, "name": "Alp Kılıççı", "dmg": 10.0, "interval": 0.9, "proj": "spear", "crit": 0.15, "text": "%15 kritik vuruş (x2)", "art": "unit_kilic"},
	"okcu": {"name": "Okçu", "dmg": 6.0, "interval": 0.45, "proj": "arrow", "text": "Çok hızlı atış", "art": "unit_okcu"},
	"buyucu": {"name": "Büyücü", "dmg": 9.0, "interval": 1.0, "proj": "orb", "chain": 1, "text": "Büyü ikinci düşmana sıçrar", "art": "unit_buyucu"},
	"kalkan": {"reach": 0.42, "name": "Kalkancı", "dmg": 7.0, "interval": 1.0, "proj": "rock", "stun": 0.12, "text": "%12 şansla 1 sn sersemletir", "art": "unit_kalkan"},
	"kam": {"name": "Kam", "dmg": 6.0, "interval": 0.9, "proj": "orb", "slow": 0.3, "text": "Düşmanı %30 yavaşlatır", "art": "hero_kam"},
	"mizrakci": {"reach": 0.42, "name": "Mızrakçı", "dmg": 9.0, "interval": 1.0, "proj": "spear", "pierce": 2, "text": "İki düşmanı deler", "art": "hero_mizrakci"},
	"kurt_binicisi": {"reach": 0.42, "name": "Kurt Binicisi", "dmg": 4.0, "interval": 0.3, "proj": "arrow", "text": "En hızlı saldırı", "art": "hero_kurt_binicisi"},
	"simyaci": {"name": "Simyacı", "dmg": 3.0, "interval": 1.0, "proj": "orb", "poison": 6.0, "text": "Zehir: 3 sn hasar, zırhı yok sayar", "art": "hero_simyaci"},
	"mancinik": {"reach": 0.1, "name": "Mancınık", "dmg": 20.0, "interval": 2.2, "proj": "rock", "splash": 3, "text": "Öndeki 3 düşmana alan hasarı", "art": "hero_mancinik"},
	"tulpar_okcu": {"reach": 0.1, "name": "Tulpar Okçu", "dmg": 8.0, "interval": 0.8, "proj": "arrow", "boss_bonus": 0.5, "text": "Boss'a +%50 hasar", "art": "hero_tulpar_okcu"},
	"umay": {"name": "Umay", "dmg": 4.0, "interval": 1.0, "proj": "orb", "aura": 0.2, "kill_gold": 1, "text": "Komşu kartlara +%20 hasar, öldürmede +1 altın", "art": "hero_umay"},
	"ejder_yavrusu": {"name": "Ejder Yavrusu", "dmg": 26.0, "interval": 1.2, "proj": "fireball", "splash": 3, "burn": 8.0, "legendary": true, "text": "Efsanevi: alan hasarı + yanma", "art": "hero_ejder_yavrusu"},
}
const SUMMON_POOL = ["kilic", "okcu", "buyucu", "kalkan", "kam", "mizrakci", "kurt_binicisi", "simyaci", "mancinik", "tulpar_okcu", "umay"]
const LEGEND_CHANCE = 0.12
const DEFAULT_DECK = ["kilic", "okcu", "buyucu", "kalkan", "kam"]
const START_HEROES = ["kilic", "okcu", "buyucu", "kalkan", "kam", "mizrakci"]

# Düşmanlar dünyaya göre değişir; "speed" yol ilerlemesi/sn (1.0 = yolun tamamı).
const ENEMIES = {
	"kurt": {"name": "Kurt", "hp": 1.0, "speed": 0.075, "art": "enemy_kurt"},
	"haydut": {"name": "Haydut", "hp": 1.2, "speed": 0.06, "art": "enemy_haydut"},
	"iskelet": {"name": "İskelet", "hp": 0.9, "speed": 0.065, "art": "enemy_iskelet"},
	"cin": {"name": "Cin", "hp": 0.8, "speed": 0.09, "art": "enemy_cin"},
	"golem_kucuk": {"name": "Taş Golem", "hp": 2.2, "speed": 0.045, "art": "enemy_golem_kucuk", "armor": 0.3},
	"kara_okcu": {"name": "Kara Okçu", "hp": 1.1, "speed": 0.065, "art": "enemy_kara_okcu"},
	"gulyabani": {"name": "Gulyabani", "hp": 1.6, "speed": 0.06, "art": "enemy_gulyabani"},
	"karakoncolos": {"name": "Karakoncolos", "hp": 1.4, "speed": 0.07, "art": "enemy_karakoncolos", "regen": 0.015},
	"albasti": {"name": "Albastı", "hp": 1.0, "speed": 0.095, "art": "enemy_albasti"},
	"tepegoz": {"name": "Tepegöz", "hp": 3.0, "speed": 0.04, "art": "enemy_tepegoz", "armor": 0.4},
}
const BOSSES = [
	{"name": "Taş Dev", "art": "boss_1"},
	{"name": "Gök Ejderi", "art": "boss_2"},
	{"name": "Kara Büyücü", "art": "boss_3"},
	{"name": "Erlik Han", "art": "boss_4"},
	{"name": "Şahmeran", "art": "boss_5"},
]
const WORLDS = [
	{"name": "Yeşil Ova", "enemies": ["kurt", "haydut", "iskelet"], "hp": 1.9},
	{"name": "Karanlık Orman", "enemies": ["iskelet", "cin", "kara_okcu", "kurt"], "hp": 4.4},
	{"name": "Taş Dağlar", "enemies": ["golem_kucuk", "haydut", "kara_okcu", "albasti"], "hp": 6.5},
	{"name": "Kayıp Bozkır", "enemies": ["gulyabani", "albasti", "karakoncolos", "cin"], "hp": 10.0},
	{"name": "Yeraltı", "enemies": ["tepegoz", "karakoncolos", "gulyabani", "iskelet"], "hp": 17.0},
]
const WAVES_PER_WORLD = 30

const POTIONS = {
	"rage": {"name": "Öfke İksiri", "text": "10 sn saldırı hızı x2", "art": "potion_rage"},
	"gold": {"name": "Altın İksiri", "text": "Anında 60 altın", "art": "potion_gold"},
	"freeze": {"name": "Buz İksiri", "text": "Tüm düşmanlar 5 sn donar", "art": "potion_freeze"},
	"heal": {"name": "Şifa İksiri", "text": "Kaleye +8 can", "art": "potion_heal"},
}
