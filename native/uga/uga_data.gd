extends RefCounted
# UGACHA tarzı mod için sabit veriler: kahramanlar, düşmanlar, dünyalar, iksirler.

const SLOTS = 15
const COLS = 3
const MAX_STARS = 6
const TICK = 0.05
const START_GOLD = 60
const START_SUMMON_COST = 10
const CASTLE_HP = 20

# Yıldız başına hasar ve hız çarpanı.
const STAR_DMG = [1.0, 2.3, 5.2, 11.5, 25.0, 55.0]
const STAR_SPEED = [1.0, 1.08, 1.16, 1.25, 1.35, 1.5]

const HEROES = {
	"kilic": {"range": 125, "name": "Alp Kılıççı", "dmg": 10.0, "interval": 0.9, "proj": "spear", "crit": 0.15, "text": "%15 kritik vuruş (x2)", "art": "unit_kilic"},
	"okcu": {"range": 205, "name": "Okçu", "dmg": 6.0, "interval": 0.45, "proj": "arrow", "text": "Çok hızlı atış", "art": "unit_okcu"},
	"buyucu": {"range": 195, "name": "Büyücü", "dmg": 9.0, "interval": 1.0, "proj": "orb", "chain": 1, "text": "Büyü ikinci düşmana sıçrar", "art": "unit_buyucu"},
	"kalkan": {"range": 125, "name": "Kalkancı", "dmg": 7.0, "interval": 1.0, "proj": "rock", "stun": 0.12, "text": "%12 şansla 1 sn sersemletir", "art": "unit_kalkan"},
	"kam": {"range": 195, "name": "Kam", "dmg": 6.0, "interval": 0.9, "proj": "orb", "slow": 0.3, "text": "Düşmanı %30 yavaşlatır", "art": "hero_kam"},
	"mizrakci": {"range": 150, "name": "Mızrakçı", "dmg": 9.0, "interval": 1.0, "proj": "spear", "pierce": 2, "text": "İki düşmanı deler", "art": "hero_mizrakci"},
	"kurt_binicisi": {"range": 170, "name": "Kurt Binicisi", "dmg": 4.0, "interval": 0.3, "proj": "arrow", "text": "En hızlı saldırı", "art": "hero_kurt_binicisi"},
	"simyaci": {"range": 195, "name": "Simyacı", "dmg": 3.0, "interval": 1.0, "proj": "orb", "poison": 6.0, "text": "Zehir: 3 sn hasar, zırhı yok sayar", "art": "hero_simyaci"},
	"mancinik": {"range": 270, "name": "Mancınık", "dmg": 20.0, "interval": 2.2, "proj": "rock", "splash": 3, "text": "Öndeki 3 düşmana alan hasarı", "art": "hero_mancinik"},
	"tulpar_okcu": {"range": 285, "name": "Tulpar Okçu", "dmg": 8.0, "interval": 0.8, "proj": "arrow", "boss_bonus": 0.5, "text": "Boss'a +%50 hasar", "art": "hero_tulpar_okcu"},
	"umay": {"range": 185, "name": "Umay", "dmg": 4.0, "interval": 1.0, "proj": "orb", "aura": 0.2, "kill_gold": 1, "text": "Komşu kartlara +%20 hasar, öldürmede +1 altın", "art": "hero_umay"},
	"ejder_yavrusu": {"range": 220, "name": "Ejder Yavrusu", "dmg": 26.0, "interval": 1.2, "proj": "fireball", "splash": 3, "burn": 8.0, "legendary": true, "text": "Efsanevi: alan hasarı + yanma", "art": "hero_ejder_yavrusu"},
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
	{"name": "Yeşil Ova", "enemies": ["kurt", "haydut", "iskelet"], "hp": 2.6},
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

# ---------- arena geometrisi (390x632 referans piksel) ----------
# Ortada 3 sütun x 5 satır kahraman ızgarası; düşmanlar sol üstten girip
# saat yönünde ızgaranın etrafını dolaşır ve sol taraftaki kale kapısına varır.
const REF = Vector2(390, 632)
const ROAD_INSET = 40.0
const ROAD_W = 46.0
const GRID_RECT = Rect2(78, 76, 234, 480)

static func path_ref() -> PackedVector2Array:
	var l = ROAD_INSET
	var t = ROAD_INSET
	var r = REF.x - ROAD_INSET
	var b = REF.y - ROAD_INSET
	var rad = 34.0
	var pts = PackedVector2Array()
	pts.append(Vector2(l, -30))
	_corner(pts, Vector2(l, t), rad, PI, PI * 1.5, Vector2(l + rad, t + rad))
	_corner(pts, Vector2(r, t), rad, PI * 1.5, TAU, Vector2(r - rad, t + rad))
	_corner(pts, Vector2(r, b), rad, 0.0, PI * 0.5, Vector2(r - rad, b - rad))
	_corner(pts, Vector2(l, b), rad, PI * 0.5, PI, Vector2(l + rad, b - rad))
	pts.append(Vector2(l, REF.y * 0.3))
	return pts

static func _corner(pts: PackedVector2Array, _c: Vector2, rad: float, a0: float, a1: float, center: Vector2) -> void:
	for k in range(7):
		var a = lerpf(a0, a1, k / 6.0)
		pts.append(center + Vector2(cos(a), sin(a)) * rad)

static func path_lengths(pts: PackedVector2Array) -> Array:
	var out = [0.0]
	for i in range(1, pts.size()):
		out.append(out[i - 1] + pts[i].distance_to(pts[i - 1]))
	return out

static func point_on(pts: PackedVector2Array, lens: Array, d: float) -> Vector2:
	var target = clampf(d, 0.0, 1.0) * float(lens[lens.size() - 1])
	for i in range(1, pts.size()):
		if target <= float(lens[i]):
			var seg = float(lens[i]) - float(lens[i - 1])
			var f = 0.0 if seg <= 0.0 else (target - float(lens[i - 1])) / seg
			return pts[i - 1].lerp(pts[i], f)
	return pts[pts.size() - 1]

static func slot_ref(i: int) -> Vector2:
	var c = i % COLS
	var r = i / COLS
	var cw = GRID_RECT.size.x / COLS
	var ch = GRID_RECT.size.y / (SLOTS / COLS)
	return GRID_RECT.position + Vector2(cw * (c + 0.5), ch * (r + 0.5))

static func cell_ref() -> Vector2:
	return Vector2(GRID_RECT.size.x / COLS, GRID_RECT.size.y / (SLOTS / COLS))
