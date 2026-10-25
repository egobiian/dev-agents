## Checks that a 2D platformer level can be finished: the goal is reachable from
## the spawn, every checkpoint and every place that must be reached is reachable,
## and no place the player can reach is a trap the goal cannot be reached from.
##
## Usage:
##   godot --headless --path <project> --script <absolute path to this file> -- <res://level.tscn> [options]
##
## Options:
##   --physics <res://resource.tres>  A resource holding the player's movement:
##                           run_speed, jump_velocity and gravity, optionally
##                           fall_gravity and acceleration, in px and seconds.
##   --player <res://player.tscn>  The player scene: its first rectangle or
##                           capsule CollisionShape2D gives the player's size.
##   --size <WxH>            Player collision size, instead of --player.
##   --run-speed, --jump-velocity, --gravity, --fall-gravity, --acceleration <n>
##                           Physics values, instead of or over --physics.
##   --tolerance <0..1>      Fraction of jump height and run speed the route must
##                           work with. Default 0.9, so no jump is pixel-perfect.
##   --drop-layer <name>     The physics layer whose one-way platforms the player
##                           can drop through. Default `platforms`.
##   --image <absolute.png>  Write a map: solids grey, platforms brown, crumbling
##                           platforms tan, the lines of moving platforms steel
##                           blue, hazards magenta, reachable ground green, traps
##                           red, spawn blue, goal yellow, checkpoints orange,
##                           places that must be reached cyan.
##
## Level conventions: solids are TileMapLayer cells with a collision polygon,
## counted as the full cell (one-way polygons are platforms), and StaticBody2D
## rectangles. The player can drop through the one-way platforms on the drop
## layer, falling straight down to the next floor below. The spawn is a node in
## group `player_spawn` at the player's feet, the goal a node in group
## `level_goal` (an Area2D with a RectangleShape2D, or a point the player has to
## pass), checkpoints are nodes in group `checkpoints` at feet height, and
## anything else the player has to be able to get to (a collectible, a key, a
## switch) is a node in group `must_reach` at its feet on the ground: each needs
## a reachable place to stand at it.
## Hazards are nodes in group `hazards`: a place the player can neither stand on
## nor pass through. Crumbling platforms are nodes in group
## `crumbling_platforms`: droppable one-way platforms that hold the player only
## long enough to jump or drop again, so no route walks on them alone. Both give
## the rectangle they cover, in their own coordinates, through
## `get_local_rect()`. Moving platforms are nodes in group `moving_platforms`: a
## crumbling platform at every point of the line they are carried along, which
## they give, sampled no further apart than asked, in their own coordinates
## where they start, through `get_line_rects(spacing)`.
##
## Exit codes: 0 pass, 1 fail, 2 bad arguments. The last line always starts
## with `level_check:`.
extends SceneTree

const DT: float = 1.0 / 60.0
const STEP: float = 8.0
const MAX_FRAMES: int = 300
const EPS: float = 0.01
const EMPTY: int = 0
const SOLID: int = 1
const PLATFORM: int = 2
# A platform on the drop layer, which the player can drop through.
const DROPPABLE: int = 3
const DEFAULT_DROP_LAYER: String = "platforms"
# How far below a platform's top a drop through it starts, past its surface.
const DROP_START: float = 1.0
# Along a moving platform's line: no reachable height is missed by more than half of it.
const MOVING_SAMPLE_SPACING: float = 4.0
const CRUMBLING_COLOR: Color = Color(0.85, 0.65, 0.4)
const MOVING_COLOR: Color = Color(0.45, 0.6, 0.8)
const HAZARD_COLOR: Color = Color(0.9, 0.2, 0.75)
const MUST_REACH_COLOR: Color = Color(0.2, 0.85, 0.9)
# In px from a node at feet height: a place the player stands on this near counts as at it.
const REACH_ALONG: float = 24.0
const REACH_HEIGHT: float = 8.0

var _ts: float = 16.0
var _origin: Vector2i
var _grid_size: Vector2i
var _grid: PackedByteArray
var _rects: Array[Dictionary] = []
var _hazards: Array[Rect2] = []
var _moving_platforms: int = 0
var _w: float
var _h: float
var _run: float
var _jump_v: float
var _gravity: float
var _fall_gravity: float
var _accel: float
var _void_y: float
var _patterns: Array[PackedInt32Array] = []
var _drop_mask: int = 0
# Each a name and a position, as checkpoints are.
var _must_reach: Array[Dictionary] = []


func _initialize() -> void:
	quit(_main())


func _main() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].begins_with("res://"):
		printerr("Usage: -- <res://level.tscn> --physics <res://resource.tres> --player <res://player.tscn> [--image out.png] [--tolerance 0.9]")
		print("level_check: bad arguments")
		return 2
	var level_path: String = args[0]
	var opts: Dictionary = {}
	var i: int = 1
	while i < args.size():
		if i + 1 >= args.size():
			printerr("Missing value for %s" % args[i])
			print("level_check: bad arguments")
			return 2
		opts[args[i].trim_prefix("--")] = args[i + 1]
		i += 2

	if not _load_physics(opts) or not _load_size(opts):
		print("level_check: bad arguments")
		return 2
	var tolerance: float = float(opts.get("tolerance", "0.9"))
	_jump_v *= sqrt(tolerance)
	_run *= tolerance

	var drop_layer: String = opts.get("drop-layer", DEFAULT_DROP_LAYER)
	_drop_mask = _layer_mask(drop_layer)
	var packed: PackedScene = load(level_path) as PackedScene
	if packed == null:
		printerr("Cannot load %s" % level_path)
		print("level_check: bad arguments")
		return 2
	var level: Node = packed.instantiate()
	var spawns: Array[Vector2] = []
	var goals: Array[Rect2] = []
	var checkpoints: Array[Dictionary] = []
	var tiles: Dictionary[Vector2i, int] = {}
	_scan(level, tiles, spawns, goals, checkpoints)
	level.free()
	if spawns.size() != 1 or goals.is_empty():
		printerr("Need exactly one node in group player_spawn (found %d) and one in level_goal (found %d)." % [spawns.size(), goals.size()])
		print("level_check: bad arguments")
		return 2
	_build_grid(tiles)
	for dir: int in [-1, 1]:
		_patterns.append(_delayed(0, dir))
		_patterns.append(_delayed(6, dir))
		_patterns.append(_delayed(14, dir))
		_patterns.append(_stopped(dir, 8))
		_patterns.append(_stopped(dir, 16))
		_patterns.append(_stopped(dir, 26))
	_patterns.append(PackedInt32Array([0]))

	var start: Vector2 = Vector2(spawns[0].x - _w / 2.0, spawns[0].y - _h)
	var landed: Dictionary = _simulate(start.x, start.y, 0.0, PackedInt32Array([0]))
	if landed.is_empty():
		print("FAIL the spawn at %s is inside a solid or above the void" % spawns[0])
		print("level_check: FAIL")
		return 1

	var nodes: Dictionary[Vector2i, Vector2] = {}
	var edges: Dictionary[Vector2i, Array] = {}
	var start_key: Vector2i = _key(landed.pos)
	nodes[start_key] = landed.pos
	var queue: Array[Vector2i] = [start_key]
	var head: int = 0
	while head < queue.size():
		var key: Vector2i = queue[head]
		head += 1
		var targets: Array = []
		for result: Dictionary in _expand(nodes[key]):
			var k: Vector2i = _key(result.pos)
			if not nodes.has(k):
				nodes[k] = result.pos
				queue.append(k)
			if k != key and not targets.has(k):
				targets.append(k)
		edges[key] = targets

	var reverse: Dictionary[Vector2i, Array] = {}
	for from: Vector2i in edges:
		for to: Vector2i in edges[from]:
			if not reverse.has(to):
				reverse[to] = []
			reverse[to].append(from)
	var finishes: Dictionary[Vector2i, bool] = {}
	var back: Array[Vector2i] = []
	for key: Vector2i in nodes:
		if _in_goal(nodes[key], goals):
			finishes[key] = true
			back.append(key)
	head = 0
	while head < back.size():
		var key: Vector2i = back[head]
		head += 1
		for from: Vector2i in reverse.get(key, []):
			if not finishes.has(from):
				finishes[from] = true
				back.append(from)

	var failed: bool = false
	print("level_check: %s, player %dx%d, run %.0f px/s, jump %.0f px high at tolerance %.2f" % [
		level_path, _w, _h, _run, _jump_v * _jump_v / (2.0 * _gravity), tolerance])
	print("  %d standing positions reachable from the spawn" % nodes.size())
	if _drop_mask == 0:
		print("  no physics layer named %s: no drop through a platform was tried" % drop_layer)
	var crumbling: int = _rects.filter(func(r: Dictionary) -> bool: return r.get("crumbles", false) and not r.get("moving", false)).size()
	if not _hazards.is_empty() or crumbling > 0 or _moving_platforms > 0:
		print("  %d hazards, %d crumbling platforms and %d moving platforms" % [_hazards.size(), crumbling, _moving_platforms])
	if not finishes.has(start_key):
		failed = true
		var furthest: Vector2 = nodes[start_key]
		for key: Vector2i in nodes:
			if nodes[key].x > furthest.x:
				furthest = nodes[key]
		print("FAIL the goal cannot be reached from the spawn. The route ends at feet (%.0f, %.0f)" % [
			furthest.x + _w / 2.0, furthest.y + _h])

	var traps: Array[Vector2] = []
	for key: Vector2i in nodes:
		if not finishes.has(key):
			traps.append(nodes[key])
	if finishes.has(start_key) and not traps.is_empty():
		failed = true
		for region: Rect2 in _regions(traps):
			print("FAIL trap: the goal cannot be reached from feet x %.0f..%.0f, y %.0f" % [
				region.position.x + _w / 2.0, region.end.x + _w / 2.0, region.position.y + _h])

	if not _must_reach.is_empty():
		print("  %d places that must be reached" % _must_reach.size())
	var places: Dictionary[String, Array] = {"checkpoint": checkpoints, "must_reach": _must_reach}
	for kind: String in places:
		for place: Dictionary in places[kind]:
			if not _reached(place.pos, nodes):
				failed = true
				print("FAIL %s %s at %s cannot be reached" % [kind, place.name, place.pos])

	if opts.has("image"):
		_draw(opts["image"], nodes, finishes, spawns[0], goals, checkpoints)
		print("  map written to %s" % opts["image"])
	print("level_check: %s" % ("FAIL" if failed else "PASS"))
	return 1 if failed else 0


func _reached(at: Vector2, nodes: Dictionary[Vector2i, Vector2]) -> bool:
	for key: Vector2i in nodes:
		var p: Vector2 = nodes[key]
		if absf(p.x + _w / 2.0 - at.x) <= REACH_ALONG and absf(p.y + _h - at.y) <= REACH_HEIGHT:
			return true
	return false


func _load_physics(opts: Dictionary) -> bool:
	var physics: Resource = null
	if opts.has("physics"):
		var path: String = opts["physics"]
		if not ResourceLoader.exists(path):
			printerr("Cannot load %s" % path)
			return false
		physics = load(path)
	var values: Dictionary = {}
	for prop: String in ["run_speed", "jump_velocity", "gravity", "fall_gravity", "acceleration"]:
		var opt: String = prop.replace("_", "-")
		if opts.has(opt):
			values[prop] = float(opts[opt])
		elif physics != null and physics.get(prop) != null:
			values[prop] = float(physics.get(prop))
	for required: String in ["run_speed", "jump_velocity", "gravity"]:
		if not values.has(required):
			printerr("No %s: pass a --physics resource that has it, or --%s." % [required, required.replace("_", "-")])
			return false
	_run = values["run_speed"]
	_jump_v = absf(values["jump_velocity"])
	_gravity = values["gravity"]
	_fall_gravity = values.get("fall_gravity", _gravity)
	_accel = values.get("acceleration", 0.0)
	return true


func _load_size(opts: Dictionary) -> bool:
	if opts.has("size"):
		var parts: PackedStringArray = String(opts["size"]).split("x")
		if parts.size() != 2:
			printerr("--size takes WxH, such as 12x24.")
			return false
		_w = float(parts[0])
		_h = float(parts[1])
		return _w > 0.0 and _h > 0.0
	if opts.has("player"):
		var path: String = opts["player"]
		if not ResourceLoader.exists(path):
			printerr("Cannot load %s" % path)
			return false
		var player: Node = (load(path) as PackedScene).instantiate()
		for child: Node in player.get_children():
			if child is CollisionShape2D:
				var shape: Shape2D = (child as CollisionShape2D).shape
				if shape is RectangleShape2D:
					_w = (shape as RectangleShape2D).size.x
					_h = (shape as RectangleShape2D).size.y
				elif shape is CapsuleShape2D:
					_w = (shape as CapsuleShape2D).radius * 2.0
					_h = (shape as CapsuleShape2D).height
				break
		player.free()
	if _w <= 0.0:
		printerr("No player size: pass --player with a scene whose rectangle or capsule CollisionShape2D is a direct child of its root, or --size WxH.")
		return false
	return true


func _scan(node: Node, tiles: Dictionary[Vector2i, int], spawns: Array[Vector2], goals: Array[Rect2], checkpoints: Array[Dictionary]) -> void:
	var xf: Transform2D = _global_transform(node)
	if node is TileMapLayer:
		var layer: TileMapLayer = node
		if layer.tile_set != null and layer.collision_enabled:
			_ts = float(layer.tile_set.tile_size.x)
			var offset: Vector2i = Vector2i((xf.origin / _ts).round())
			for cell: Vector2i in layer.get_used_cells():
				var data: TileData = layer.get_cell_tile_data(cell)
				if data == null or layer.tile_set.get_physics_layers_count() == 0:
					continue
				var count: int = data.get_collision_polygons_count(0)
				if count == 0:
					continue
				var kind: int = SOLID
				if data.is_collision_polygon_one_way(0, 0):
					var droppable: bool = (layer.tile_set.get_physics_layer_collision_layer(0) & _drop_mask) != 0
					kind = DROPPABLE if droppable else PLATFORM
				var at: Vector2i = cell + offset
				if tiles.get(at, EMPTY) != SOLID:
					tiles[at] = kind
	elif node is CollisionShape2D and node.get_parent() is StaticBody2D:
		var shape: CollisionShape2D = node
		if shape.shape is RectangleShape2D and not shape.disabled:
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			var droppable: bool = shape.one_way_collision and ((node.get_parent() as StaticBody2D).collision_layer & _drop_mask) != 0
			_rects.append({"rect": Rect2(xf.origin - size / 2.0, size), "platform": shape.one_way_collision, "drop": droppable})
	if node.is_in_group("hazards"):
		_hazards.append(xf * (node.call("get_local_rect") as Rect2))
	if node.is_in_group("crumbling_platforms"):
		var rect: Rect2 = xf * (node.call("get_local_rect") as Rect2)
		_rects.append({"rect": rect, "platform": true, "drop": true, "crumbles": true})
	if node.is_in_group("moving_platforms"):
		_moving_platforms += 1
		var line: Array[Rect2] = []
		for local: Rect2 in node.call("get_line_rects", MOVING_SAMPLE_SPACING):
			var rect: Rect2 = xf * local
			# Along a level stretch of the line the samples join into one platform.
			if not line.is_empty() and is_equal_approx(line[-1].position.y, rect.position.y) and line[-1].intersects(rect, true):
				line[-1] = line[-1].merge(rect)
			else:
				line.append(rect)
		for rect: Rect2 in line:
			_rects.append({"rect": rect, "platform": true, "drop": true, "crumbles": true, "moving": true})
	if node.is_in_group("player_spawn"):
		spawns.append(xf.origin)
	if node.is_in_group("level_goal"):
		var rect: Rect2 = Rect2(xf.origin.x - 8.0, -100000.0, 16.0, 200000.0)
		for child: Node in node.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
				var size: Vector2 = ((child as CollisionShape2D).shape as RectangleShape2D).size
				rect = Rect2(_global_transform(child).origin - size / 2.0, size)
		goals.append(rect)
	if node.is_in_group("checkpoints"):
		checkpoints.append({"name": _path_name(node), "pos": xf.origin})
	if node.is_in_group("must_reach"):
		_must_reach.append({"name": _path_name(node), "pos": xf.origin})
	for child: Node in node.get_children():
		_scan(child, tiles, spawns, goals, checkpoints)


# From the level's root, as several nodes may share a name.
func _path_name(node: Node) -> String:
	var names: PackedStringArray = []
	var current: Node = node
	while current.get_parent() != null:
		names.insert(0, current.name)
		current = current.get_parent()
	return "/".join(names)


func _layer_mask(layer_name: String) -> int:
	for layer: int in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	return 0


func _global_transform(node: Node) -> Transform2D:
	var xf: Transform2D = Transform2D.IDENTITY
	var current: Node = node
	while current != null:
		if current is Node2D:
			xf = (current as Node2D).transform * xf
		current = current.get_parent()
	return xf


func _build_grid(tiles: Dictionary[Vector2i, int]) -> void:
	var lo: Vector2i = Vector2i(0, 0)
	var hi: Vector2i = Vector2i(0, 0)
	var first: bool = true
	for cell: Vector2i in tiles:
		lo = cell if first else lo.min(cell)
		hi = cell if first else hi.max(cell)
		first = false
	_origin = lo
	_grid_size = hi - lo + Vector2i.ONE
	_grid.resize(_grid_size.x * _grid_size.y)
	_grid.fill(EMPTY)
	for cell: Vector2i in tiles:
		var c: Vector2i = cell - lo
		_grid[c.y * _grid_size.x + c.x] = tiles[cell]
	_void_y = float(hi.y + 1) * _ts + 64.0
	for r: Dictionary in _rects:
		_void_y = maxf(_void_y, (r.rect as Rect2).end.y + 64.0)


func _cell(cx: int, cy: int) -> int:
	var x: int = cx - _origin.x
	var y: int = cy - _origin.y
	if x < 0 or y < 0 or x >= _grid_size.x or y >= _grid_size.y:
		return EMPTY
	return _grid[y * _grid_size.x + x]


# Horizontal input per frame while airborne; the last entry holds.
func _delayed(frames: int, dir: int) -> PackedInt32Array:
	var p: PackedInt32Array = []
	p.resize(frames)
	p.append(dir)
	return p


func _stopped(dir: int, frames: int) -> PackedInt32Array:
	var p: PackedInt32Array = []
	for f: int in frames:
		p.append(dir)
	p.append(0)
	return p


func _expand(pos: Vector2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not _on_crumbling_only(pos):
		for dir: int in [-1, 1]:
			for keep: int in [dir, 0]:
				var r: Dictionary = _walk(pos, dir, keep)
				if not r.is_empty():
					results.append(r)
	for pattern: PackedInt32Array in _patterns:
		var r: Dictionary = _simulate(pos.x, pos.y, -_jump_v, pattern)
		if not r.is_empty():
			results.append(r)
	if _can_drop(pos):
		var r: Dictionary = _simulate(pos.x, pos.y + DROP_START, 0.0, PackedInt32Array([0]))
		if not r.is_empty():
			results.append(r)
	return results


# Standing on platforms the player can drop through, with nothing else under the feet.
func _can_drop(pos: Vector2) -> bool:
	var feet: float = pos.y + _h
	var droppable: bool = false
	var row: int = roundi(feet / _ts)
	if absf(feet - row * _ts) <= EPS:
		var cols: Vector2i = _cols(pos.x)
		for cx: int in range(cols.x, cols.y + 1):
			var kind: int = _cell(cx, row)
			if kind == DROPPABLE:
				droppable = true
			elif kind != EMPTY:
				return false
	for r: Dictionary in _rects:
		var rect: Rect2 = r.rect
		if absf(rect.position.y - feet) <= EPS and rect.position.x < pos.x + _w and rect.end.x > pos.x:
			if not r.drop:
				return false
			droppable = true
	return droppable


# Crumbling platforms and nothing else under the feet.
func _on_crumbling_only(pos: Vector2) -> bool:
	var feet: float = pos.y + _h
	var row: int = roundi(feet / _ts)
	if absf(feet - row * _ts) <= EPS:
		var cols: Vector2i = _cols(pos.x)
		for cx: int in range(cols.x, cols.y + 1):
			if _cell(cx, row) != EMPTY and _cell(cx, row - 1) != SOLID:
				return false
	var on_crumbling: bool = false
	for r: Dictionary in _rects:
		var rect: Rect2 = r.rect
		if absf(rect.position.y - feet) <= EPS and rect.position.x < pos.x + _w and rect.end.x > pos.x:
			if not r.get("crumbles", false):
				return false
			on_crumbling = true
	return on_crumbling


func _walk(pos: Vector2, dir: int, keep: int) -> Dictionary:
	var x: float = pos.x
	var vx: float = 0.0
	for f: int in MAX_FRAMES:
		vx = _toward(vx, dir * _run)
		var nx: float = _move_x(x, pos.y, vx * DT)
		if is_equal_approx(nx, x) and not is_zero_approx(vx):
			return {}
		x = nx
		if _in_hazard(x, pos.y):
			return {}
		if not _supported(x, pos.y):
			return _simulate(x, pos.y, 0.0, PackedInt32Array([keep]), vx)
		if absf(x - pos.x) >= STEP:
			return {"pos": Vector2(x, pos.y)}
	return {}


func _simulate(x: float, y: float, vy: float, pattern: PackedInt32Array, vx: float = 0.0) -> Dictionary:
	if _blocked(x, y) or _in_hazard(x, y):
		return {}
	for f: int in MAX_FRAMES:
		var dir: int = pattern[mini(f, pattern.size() - 1)]
		vx = _toward(vx, dir * _run)
		x = _move_x(x, y, vx * DT)
		vy += (_gravity if vy < 0.0 else _fall_gravity) * DT
		var dy: float = vy * DT
		if dy > 0.0:
			var top: float = _floor_top(x, y + _h, y + _h + dy)
			if top < INF:
				y = top - _h
				return {} if _in_hazard(x, y) else {"pos": Vector2(x, y)}
		elif dy < 0.0:
			var bottom: float = _ceiling_bottom(x, y, y + dy)
			if bottom > -INF:
				dy = bottom - y
				vy = 0.0
		y += dy
		if _in_hazard(x, y):
			return {}
		if y > _void_y:
			return {}
	return {}


func _toward(vx: float, target: float) -> float:
	if _accel <= 0.0:
		return target
	return move_toward(vx, target, _accel * DT)


func _cols(x: float) -> Vector2i:
	return Vector2i(floori(x / _ts), floori((x + _w - EPS) / _ts))


func _rows(y: float) -> Vector2i:
	return Vector2i(floori(y / _ts), floori((y + _h - EPS) / _ts))


func _blocked(x: float, y: float) -> bool:
	var cols: Vector2i = _cols(x)
	var rows: Vector2i = _rows(y)
	for cy: int in range(rows.x, rows.y + 1):
		for cx: int in range(cols.x, cols.y + 1):
			if _cell(cx, cy) == SOLID:
				return true
	var me: Rect2 = Rect2(x, y, _w, _h)
	for r: Dictionary in _rects:
		if not r.platform and (r.rect as Rect2).intersects(me):
			return true
	return false


func _in_hazard(x: float, y: float) -> bool:
	var me: Rect2 = Rect2(x, y, _w, _h)
	for hazard: Rect2 in _hazards:
		if hazard.intersects(me):
			return true
	return false


func _supported(x: float, y: float) -> bool:
	return _floor_top(x, y + _h, y + _h + 0.5) < INF


func _floor_top(x: float, bottom_old: float, bottom_new: float) -> float:
	var best: float = INF
	var cols: Vector2i = _cols(x)
	for cy: int in range(floori((bottom_old - EPS) / _ts), floori(bottom_new / _ts) + 1):
		var top: float = cy * _ts
		if top < bottom_old - EPS or top > bottom_new:
			continue
		for cx: int in range(cols.x, cols.y + 1):
			if _cell(cx, cy) != EMPTY and _cell(cx, cy - 1) != SOLID:
				best = minf(best, top)
				break
	for r: Dictionary in _rects:
		var rect: Rect2 = r.rect
		if rect.position.y >= bottom_old - EPS and rect.position.y <= bottom_new \
				and rect.position.x < x + _w and rect.end.x > x:
			best = minf(best, rect.position.y)
	return best


func _ceiling_bottom(x: float, top_old: float, top_new: float) -> float:
	var best: float = -INF
	var cols: Vector2i = _cols(x)
	for cy: int in range(floori(top_new / _ts), floori((top_old + EPS) / _ts) + 1):
		var bottom: float = (cy + 1) * _ts
		if bottom > top_old + EPS or bottom < top_new:
			continue
		for cx: int in range(cols.x, cols.y + 1):
			if _cell(cx, cy) == SOLID:
				best = maxf(best, bottom)
				break
	for r: Dictionary in _rects:
		var rect: Rect2 = r.rect
		if not r.platform and rect.end.y <= top_old + EPS and rect.end.y >= top_new \
				and rect.position.x < x + _w and rect.end.x > x:
			best = maxf(best, rect.end.y)
	return best


func _move_x(x: float, y: float, dx: float) -> float:
	if dx == 0.0:
		return x
	var steps: int = ceili(absf(dx) / 0.5)
	var s: float = dx / steps
	for i: int in steps:
		if _blocked(x + s, y):
			return x
		x += s
	return x


func _key(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / STEP), roundi(pos.y + _h))


func _in_goal(pos: Vector2, goals: Array[Rect2]) -> bool:
	var me: Rect2 = Rect2(pos, Vector2(_w, _h))
	for goal: Rect2 in goals:
		if goal.intersects(me, true):
			return true
	return false


func _regions(points: Array[Vector2]) -> Array[Rect2]:
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var regions: Array[Rect2] = []
	for p: Vector2 in points:
		var merged: bool = false
		for i: int in regions.size():
			var grown: Rect2 = regions[i].grow(48.0)
			if grown.has_point(p):
				regions[i] = regions[i].expand(p)
				merged = true
				break
		if not merged:
			regions.append(Rect2(p, Vector2.ZERO))
	return regions


func _draw(path: String, nodes: Dictionary[Vector2i, Vector2], finishes: Dictionary[Vector2i, bool], spawn: Vector2, goals: Array[Rect2], checkpoints: Array[Dictionary]) -> void:
	var left: float = _origin.x * _ts
	var top: float = _origin.y * _ts - 128.0
	var width: int = int(_grid_size.x * _ts)
	var height: int = int(_grid_size.y * _ts + 192.0)
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.08, 0.08, 0.12))
	for cy: int in _grid_size.y:
		for cx: int in _grid_size.x:
			var kind: int = _grid[cy * _grid_size.x + cx]
			if kind != EMPTY:
				var color: Color = Color(0.45, 0.45, 0.5) if kind == SOLID else Color(0.55, 0.35, 0.2)
				image.fill_rect(Rect2i(cx * int(_ts), cy * int(_ts) + 128, int(_ts), int(_ts)), color)
	for r: Dictionary in _rects:
		var rect: Rect2 = r.rect
		var color: Color = Color(0.45, 0.45, 0.5)
		if r.get("moving", false):
			color = MOVING_COLOR
		elif r.get("crumbles", false):
			color = CRUMBLING_COLOR
		elif r.platform:
			color = Color(0.55, 0.35, 0.2)
		image.fill_rect(Rect2i(Vector2i(rect.position - Vector2(left, top)), Vector2i(rect.size)), color)
	for hazard: Rect2 in _hazards:
		image.fill_rect(Rect2i(Vector2i(hazard.position - Vector2(left, top)), Vector2i(hazard.size)), HAZARD_COLOR)
	for key: Vector2i in nodes:
		var p: Vector2 = nodes[key] - Vector2(left, top)
		var color: Color = Color(0.2, 0.85, 0.3) if finishes.has(key) else Color(0.95, 0.15, 0.15)
		image.fill_rect(Rect2i(int(p.x), int(p.y + _h) - 2, int(_w), 2), color)
	for goal: Rect2 in goals:
		var g: Rect2 = goal.intersection(Rect2(left, top, width, height))
		image.fill_rect(Rect2i(Vector2i(g.position - Vector2(left, top)), Vector2i(maxf(g.size.x, 2.0), 2)), Color(1, 0.9, 0.1))
		image.fill_rect(Rect2i(Vector2i(g.position - Vector2(left, top)), Vector2i(2, int(g.size.y))), Color(1, 0.9, 0.1))
	for c: Dictionary in checkpoints:
		var cp: Vector2 = (c.pos as Vector2) - Vector2(left, top)
		image.fill_rect(Rect2i(int(cp.x) - 4, int(cp.y) - 12, 8, 12), Color(1, 0.55, 0.1))
	for place: Dictionary in _must_reach:
		var at: Vector2 = (place.pos as Vector2) - Vector2(left, top)
		image.fill_rect(Rect2i(int(at.x) - 4, int(at.y) - 8, 8, 8), MUST_REACH_COLOR)
	var sp: Vector2 = spawn - Vector2(left, top)
	image.fill_rect(Rect2i(int(sp.x) - 4, int(sp.y) - 12, 8, 12), Color(0.2, 0.5, 1))
	image.save_png(path)
