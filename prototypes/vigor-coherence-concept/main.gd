# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does cutting Coherence links while the Vigor ceiling erodes across
#           back-to-back fights give readable, tactical decisions?
# Date: 2026-10-28
extends Node2D

const ARENA := Vector2(1280, 720)
const EROSION := 0.03        # ceiling lost per point of Vigor spent
const SHOT_COST := 4.0
const BOOST_COST := 22.0     # per second
const REGEN := 18.0          # per second, only after 0.45s without spending
const LINE_HP := 120.0
const RELAY_HP := 72.0
const SHOT_DMG := 12.0
const VIOLET := Color(0.80, 0.72, 1.0)
const AMBER := Color(1.0, 0.72, 0.30)

class Ship:
	var pos: Vector2
	var hp: float
	var is_relay: bool
	var slot: Vector2
	var fire_t: float = 0.0
	var seed_t: float = 0.0

class Bullet:
	var pos: Vector2
	var vel: Vector2
	var friendly: bool
	var life: float = 2.5

class Snap:
	var a: Vector2
	var b: Vector2
	var t: float = 0.7

var bot: bool = false
var bot_move := Vector2.ZERO
var bot_fire: bool = false
var bot_boost: bool = false
var bot_aim := Vector2.ZERO

var t_total: float = 0.0
var paused: bool = false
var mode: String = "play"   # play | defeat | summary
var idx: int = 0
var attempts: int = 1
var ceiling: float = 100.0
var vigor: float = 100.0
var hull: float = 100.0
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var pang: float = 0.0
var exhausted_t: float = 0.0
var idle_t: float = 0.0
var fire_cd: float = 0.0
var ships: Array[Ship] = []
var bullets: Array[Bullet] = []
var snaps: Array[Snap] = []
var center := Vector2(1000, 360)
var volley_t: float = 2.0
var relays_total: int = 1
var elapsed: float = 0.0
var banner: String = ""
var banner_t: float = 0.0

var m_first_kill_relay: int = -1
var m_first_relay_t: float = -1.0
var m_spent: float = 0.0
var m_shots: int = 0
var m_dmg_relay: float = 0.0
var m_dmg_line: float = 0.0
var results: Array[String] = []
var relay_first_count: int = 0


func _ready() -> void:
	bot = OS.get_cmdline_user_args().has("--bot")
	start_skirmish()


func start_skirmish() -> void:
	var n_relays: int = [1, 2, 2][idx]
	var n_line: int = [4, 5, 6][idx]
	relays_total = n_relays
	ships.clear()
	bullets.clear()
	snaps.clear()
	center = Vector2(1000, 360)
	ppos = Vector2(180, 360)
	pvel = Vector2.ZERO
	hull = 100.0
	vigor = ceiling
	exhausted_t = 0.0
	elapsed = 0.0
	volley_t = 2.0
	m_first_kill_relay = -1
	m_first_relay_t = -1.0
	m_spent = 0.0
	m_shots = 0
	m_dmg_relay = 0.0
	m_dmg_line = 0.0
	for i in n_line:
		var s := Ship.new()
		s.is_relay = false
		s.hp = LINE_HP
		s.slot = Vector2(-float(i % 2) * 55.0, (float(i) - (n_line - 1) / 2.0) * 62.0)
		s.pos = center + s.slot + Vector2(300, 0)
		s.fire_t = randf_range(1.0, 2.5)
		s.seed_t = randf() * 6.0
		ships.append(s)
	for r in n_relays:
		var s := Ship.new()
		s.is_relay = true
		s.hp = RELAY_HP
		s.slot = Vector2(120.0, (float(r) - (n_relays - 1) / 2.0) * 150.0)
		s.pos = center + s.slot + Vector2(300, 0)
		ships.append(s)
	mode = "play"


func relays_alive() -> int:
	var n: int = 0
	for s in ships:
		if s.is_relay:
			n += 1
	return n


func link_status() -> String:
	var alive: int = relays_alive()
	if alive == 0:
		return "CUT"
	if alive < relays_total:
		return "DEGRADED"
	return "SOLID"


func spend(x: float) -> void:
	vigor -= x
	m_spent += x
	ceiling = maxf(5.0, ceiling - x * EROSION)
	idle_t = 0.0
	if vigor <= 0.0:
		vigor = 0.0
		exhausted_t = 1.6
	vigor = minf(vigor, ceiling)


func _process(delta: float) -> void:
	t_total += delta
	if banner_t > 0.0:
		banner_t -= delta
	if mode == "play" and not paused:
		step(delta)
	elif bot and mode == "defeat":
		retry()
	elif bot and mode == "summary":
		for line in results:
			print(line)
		print("RELAY_FIRST %d/3  FINAL_CEILING %.0f%%" % [relay_first_count, ceiling])
		get_tree().quit()
	queue_redraw()


func in_move() -> Vector2:
	if bot:
		return bot_move
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	return v.normalized()


func step(delta: float) -> void:
	elapsed += delta
	if bot:
		bot_think()

	# --- player ---
	var want: Vector2 = in_move()
	var boost_key: bool = bot_boost if bot else Input.is_key_pressed(KEY_SHIFT)
	var max_speed: float = 260.0
	if boost_key and exhausted_t <= 0.0 and want != Vector2.ZERO and vigor > 0.0:
		max_speed = 430.0
		spend(BOOST_COST * delta)
	if exhausted_t > 0.0:
		max_speed *= 0.5
		exhausted_t -= delta
	pvel = pvel.move_toward(want * max_speed, 900.0 * delta)
	ppos += pvel * delta
	ppos = ppos.clamp(Vector2(20, 20), ARENA - Vector2(20, 20))
	var aim: Vector2 = bot_aim if bot else get_global_mouse_position()
	pang = (aim - ppos).angle()

	fire_cd -= delta
	var fire: bool = bot_fire if bot else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if fire and fire_cd <= 0.0 and exhausted_t <= 0.0 and vigor >= SHOT_COST:
		fire_cd = 0.14
		spend(SHOT_COST)
		m_shots += 1
		var b := Bullet.new()
		b.pos = ppos + Vector2.from_angle(pang) * 20.0
		b.vel = Vector2.from_angle(pang) * 760.0
		b.friendly = true
		bullets.append(b)

	idle_t += delta
	if idle_t > 0.45:
		vigor = minf(ceiling, vigor + REGEN * delta)

	# --- machines ---
	var status: String = link_status()
	center.x = maxf(640.0, center.x - 22.0 * delta)
	volley_t -= delta
	var do_volley: bool = false
	if status != "CUT" and volley_t <= 0.0:
		do_volley = true
		volley_t = 1.5 if status == "SOLID" else 2.5
	for s in ships:
		if s.is_relay:
			var target: Vector2 = center + s.slot
			var away: Vector2 = s.pos - ppos
			if away.length() < 320.0:
				target += away.normalized() * 160.0
			target = target.clamp(Vector2(520, 40), Vector2(1240, 680))
			s.pos = s.pos.lerp(target, minf(1.0, 3.0 * delta))
		elif status != "CUT":
			s.pos = s.pos.lerp(center + s.slot, minf(1.0, 4.0 * delta))
			if do_volley:
				enemy_shot(s.pos, 0.05 if status == "SOLID" else 0.14)
		else:
			var to_p: Vector2 = ppos - s.pos
			var d: float = to_p.length()
			var dir: Vector2 = to_p.normalized() if d > 0.01 else Vector2.ZERO
			dir = dir.rotated(sin(t_total * 1.3 + s.seed_t) * 0.9)
			if d > 170.0:
				s.pos += dir * 90.0 * delta
			s.fire_t -= delta
			if s.fire_t <= 0.0:
				s.fire_t = randf_range(2.2, 3.4)
				if d < 560.0:
					enemy_shot(s.pos, 0.3)
		s.pos = s.pos.clamp(Vector2(10, 10), ARENA - Vector2(10, 10))

	# --- bullets ---
	for i in range(bullets.size() - 1, -1, -1):
		var b: Bullet = bullets[i]
		b.pos += b.vel * delta
		b.life -= delta
		if b.friendly:
			for s in ships:
				if b.pos.distance_to(s.pos) < (14.0 if s.is_relay else 17.0):
					s.hp -= SHOT_DMG
					if s.is_relay:
						m_dmg_relay += SHOT_DMG
					else:
						m_dmg_line += SHOT_DMG
					b.life = 0.0
					break
		elif b.pos.distance_to(ppos) < 14.0:
			hull -= 6.0
			b.life = 0.0
		if b.life <= 0.0 or b.pos.x < -50.0 or b.pos.x > ARENA.x + 50.0 \
				or b.pos.y < -50.0 or b.pos.y > ARENA.y + 50.0:
			bullets.remove_at(i)

	for i in range(snaps.size() - 1, -1, -1):
		snaps[i].t -= delta
		if snaps[i].t <= 0.0:
			snaps.remove_at(i)

	reap()

	if hull <= 0.0:
		mode = "defeat"
		banner = "DEFEATED - press R to retry (your Vigor ceiling stays eroded)"
		banner_t = 999.0
	elif ships.is_empty():
		finish_skirmish()


func enemy_shot(from: Vector2, err: float) -> void:
	var b := Bullet.new()
	b.pos = from
	b.vel = (ppos - from).normalized().rotated(randf_range(-err, err)) * 400.0
	b.friendly = false
	bullets.append(b)


func reap() -> void:
	for i in range(ships.size() - 1, -1, -1):
		var s: Ship = ships[i]
		if s.hp > 0.0:
			continue
		ships.remove_at(i)
		if m_first_kill_relay == -1:
			m_first_kill_relay = 1 if s.is_relay else 0
		if s.is_relay:
			if m_first_relay_t < 0.0:
				m_first_relay_t = elapsed
			for o in ships:
				if not o.is_relay:
					var sn := Snap.new()
					sn.a = s.pos
					sn.b = o.pos
					snaps.append(sn)
			banner = "LINK CUT" if relays_alive() == 0 else "LINK DEGRADED"
			banner_t = 1.6


func finish_skirmish() -> void:
	if m_first_kill_relay == 1:
		relay_first_count += 1
	results.append("S%d attempts=%d first_kill_relay=%s first_relay_kill=%.1fs time=%.1fs shots=%d vigor_spent=%.0f dmg_relay=%.0f dmg_line=%.0f ceiling_end=%.0f%%" % [
		idx + 1, attempts, str(m_first_kill_relay == 1), m_first_relay_t, elapsed,
		m_shots, m_spent, m_dmg_relay, m_dmg_line, ceiling])
	idx += 1
	attempts = 1
	if idx >= 3:
		mode = "summary"
		banner = ""
	else:
		start_skirmish()
		banner = "SKIRMISH CLEARED - ceiling carries over"
		banner_t = 2.5


func retry() -> void:
	attempts += 1
	banner = ""
	banner_t = 0.0
	start_skirmish()


func new_run() -> void:
	idx = 0
	attempts = 1
	ceiling = 100.0
	relay_first_count = 0
	results.clear()
	banner = ""
	start_skirmish()


func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE and mode == "play":
		paused = not paused
	elif ke.keycode == KEY_R and mode == "defeat":
		retry()
	elif ke.keycode == KEY_N and mode == "summary":
		new_run()


func bot_think() -> void:
	var tgt: Ship = null
	var best: float = 1e9
	for s in ships:
		var score: float = ppos.distance_to(s.pos) + (0.0 if s.is_relay else 1000.0)
		if score < best:
			best = score
			tgt = s
	if tgt == null:
		return
	bot_aim = tgt.pos
	var d: float = ppos.distance_to(tgt.pos)
	var dir: Vector2 = (tgt.pos - ppos).normalized()
	var strafe: Vector2 = dir.orthogonal() * sin(t_total * 2.0)
	bot_move = (dir * (1.0 if d > 380.0 else -0.2) + strafe).normalized()
	bot_fire = d < 650.0
	bot_boost = d > 500.0


# ----------------------------------------------------------------- drawing

func txt(p: Vector2, s: String, size: int = 16, c: Color = Color(0.9, 0.9, 0.9)) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.035, 0.04, 0.06))
	var status: String = link_status()
	var telegraph: bool = status != "CUT" and volley_t < 0.4

	# links
	for r in ships:
		if not r.is_relay:
			continue
		for s in ships:
			if s.is_relay:
				continue
			var w: float = 5.0 if telegraph else 3.0
			if status == "SOLID":
				draw_line(r.pos, s.pos, Color(VIOLET, 0.75 if telegraph else 0.5), w)
			else:
				draw_dashed_line(r.pos, s.pos, Color(VIOLET, 0.55), 3.0, 10.0)
	for sn in snaps:
		var f: float = sn.t / 0.7
		var tip: Vector2 = sn.a.lerp(sn.b, 0.25)
		draw_line(sn.a, tip, Color(1, 1, 1, f), 3.0)
		draw_circle(tip, 4.0 + 8.0 * (1.0 - f), Color(1.0, 0.95, 0.8, f))

	# machines
	for s in ships:
		if s.is_relay:
			var pr: float = 0.5 + 0.5 * sin(t_total * 5.0)
			var pts := PackedVector2Array([s.pos + Vector2(0, -17), s.pos + Vector2(17, 0),
				s.pos + Vector2(0, 17), s.pos + Vector2(-17, 0)])
			draw_colored_polygon(pts, VIOLET)
			draw_arc(s.pos, 24.0, 0.0, TAU, 32, Color(VIOLET, 0.4 + 0.4 * pr), 3.0)
		else:
			var col := Color(0.85, 0.84, 0.78) if status != "CUT" else Color(0.5, 0.5, 0.55)
			draw_rect(Rect2(s.pos - Vector2(13, 13), Vector2(26, 26)), col)
			draw_circle(s.pos, 4.0, VIOLET if status != "CUT" else Color(0.35, 0.35, 0.4))
		var max_hp: float = RELAY_HP if s.is_relay else LINE_HP
		draw_rect(Rect2(s.pos + Vector2(-14, -26), Vector2(28.0 * s.hp / max_hp, 3)), Color(0.9, 0.9, 0.9))

	# bullets
	for b in bullets:
		draw_circle(b.pos, 3.0 if b.friendly else 3.5, AMBER if b.friendly else VIOLET)

	# player flagship: glow = Vigor, outer ring = ceiling
	var vr: float = vigor / maxf(ceiling, 1.0)
	var rate: float = 2.0 + 4.0 * vr
	var glow: float = (0.25 + 0.75 * (vigor / 100.0)) * (0.75 + 0.25 * sin(t_total * rate))
	if exhausted_t > 0.0:
		glow = 0.1
	draw_set_transform(ppos, pang, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(-10, 11), Vector2(-6, 0), Vector2(-10, -11)]),
		Color(0.30, 0.20, 0.12))
	draw_circle(Vector2(-2, 0), 7.0, Color(AMBER, glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(ppos, 30.0, -PI / 2.0, -PI / 2.0 + TAU * ceiling / 100.0, 48, Color(AMBER, 0.35), 3.0)
	draw_arc(ppos, 25.0, -PI / 2.0, -PI / 2.0 + TAU * vigor / 100.0, 48, Color(AMBER, 0.9), 3.0)

	# HUD
	txt(Vector2(20, 26), "SKIRMISH %d/3   attempt %d   LINK: %s" % [mini(idx + 1, 3), attempts, status], 18)
	draw_rect(Rect2(20, 38, 300, 14), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(20, 38, 3.0 * ceiling, 14), Color(AMBER, 0.3))
	draw_rect(Rect2(20, 38, 3.0 * vigor, 14), Color(AMBER, 0.95))
	txt(Vector2(330, 51), "VIGOR %d / CEILING %d" % [roundi(vigor), roundi(ceiling)] + ("   EXHAUSTED" if exhausted_t > 0.0 else ""), 14)
	draw_rect(Rect2(20, 58, 300, 8), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(20, 58, 3.0 * maxf(hull, 0.0), 8), Color(0.8, 0.35, 0.35))
	txt(Vector2(20, ARENA.y - 14), "WASD move   mouse aim   LMB fire   Shift boost   Space pause   R retry (after defeat)", 14, Color(0.6, 0.6, 0.65))

	if banner_t > 0.0 and banner != "":
		txt(Vector2(ARENA.x / 2.0 - 220.0, 120), banner, 24, Color(1, 0.95, 0.8))
	if paused:
		draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0, 0, 0, 0.4))
		txt(Vector2(ARENA.x / 2.0 - 60.0, ARENA.y / 2.0), "PAUSED", 32)
	if mode == "summary":
		draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0, 0, 0, 0.75))
		txt(Vector2(60, 90), "RUN COMPLETE", 32)
		var y: float = 140.0
		for line in results:
			txt(Vector2(60, y), line, 14)
			y += 26.0
		txt(Vector2(60, y + 20.0), "Relay-first: %d/3   (signal: >= 2)" % relay_first_count, 20)
		txt(Vector2(60, y + 50.0), "Final Vigor ceiling: %d%%   (signal: 25-70%%)" % roundi(ceiling), 20)
		txt(Vector2(60, y + 90.0), "Press N for a new run", 16, Color(0.7, 0.7, 0.75))
