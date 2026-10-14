extends SceneTree
# Savaş ekranı dokunma: bir dokunuş bir çağrı, sürükle-bırak birleştirir, SAT bölgesi satar.
const Battle = preload("res://native/uga/uga_battle.gd")
const Sim = preload("res://native/uga/uga_sim.gd")
var failed = false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func touch(b, pos: Vector2, pressed: bool) -> void:
	var e = InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = 0
	b._gui_input(e)
	var m = InputEventMouseButton.new()
	m.position = pos
	m.pressed = pressed
	m.button_index = MOUSE_BUTTON_LEFT
	b._gui_input(m)
func drag(b, pos: Vector2) -> void:
	var e = InputEventScreenDrag.new()
	e.position = pos
	e.index = 0
	b._gui_input(e)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sim = Sim.new(11, 0)
	var b = Battle.new()
	root.add_child(b)
	b.size = Vector2(390, 844)
	b.setup(sim, func(n): return null, ThemeDB.fallback_font, ThemeDB.fallback_font)
	b.set_process(false)
	b.layout()
	var g0 = sim.gold
	touch(b, b.r_summon.get_center(), true)
	touch(b, b.r_summon.get_center(), false)
	check(sim.stats.summons == 1 and sim.gold == g0 - 10, "Bir dokunuş tam bir çağrı yapmalı (çift sayım yok)")
	sim.slots = []
	sim.slots.resize(15)
	sim.slots[0] = {"h": "okcu", "s": 1, "cd": 0.0}
	sim.slots[1] = {"h": "okcu", "s": 1, "cd": 0.0}
	touch(b, b.slot_rects[0].get_center(), true)
	drag(b, b.slot_rects[1].get_center())
	touch(b, b.slot_rects[1].get_center(), false)
	check(sim.slots[0] == null and sim.slots[1] != null and int(sim.slots[1].s) == 2, "Sürükle-bırak birleştirmeli")
	var g1 = sim.gold
	touch(b, b.slot_rects[1].get_center(), true)
	drag(b, b.r_sell.get_center())
	touch(b, b.r_sell.get_center(), false)
	check(sim.slots[1] == null and sim.gold == g1 + 10, "SAT bölgesine bırakınca satmalı")
	sim.slots[2] = {"h": "kilic", "s": 1, "cd": 0.0}
	touch(b, b.slot_rects[2].get_center(), true)
	touch(b, b.slot_rects[2].get_center(), false)
	check(b.info_slot == 2, "Dokunmak kart bilgisini açmalı")
	sim.gold = 500
	var h = sim.deck[0]
	touch(b, b.power_rects[h].get_center(), true)
	touch(b, b.power_rects[h].get_center(), false)
	check(int(sim.run_levels.get(h, 0)) == 1, "Güçlendirme şeridi tek dokunuşta bir seviye")
	touch(b, b.r_exit.get_center(), true)
	check(b.paused, "Duraklat düğmesi")
	b.queue_free()
	for i in 3:
		await process_frame
	print("UGA INPUT " + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
