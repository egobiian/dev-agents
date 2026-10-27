## Checks that a level seen from above (isometric or top-down, square or diamond
## cells) can be cleared. Flood-fills the floor from the player spawn, treating
## wall cells, the collision of static props and any passage narrower than the
## player's collision shape as solid, and fails when:
##   - an enemy stands where the player cannot reach,
##   - a required node (trigger, exit, objective, chest) cannot be reached,
##   - reachable floor lies outside the camera limits,
##   - an enemy has no navigation path to the spawn on the level's
##     NavigationRegion2D polygons, or the level has no baked polygon,
##   - the polygons' inset from walls and props (the agent radius) is smaller
##     than the enemies' reach from their feet: the bake is stale,
##   - reachable floor well clear of every solid is missing from the baked
##     polygons, or the polygons cover the centre of a wall cell or a prop's
##     base: walls or props changed after the bake.
##
## Usage:
##   godot --headless --path <project> --script <absolute path to this file> -- <res://level.tscn> [options]
##
## Options (values follow the option):
##   --spawn-group <name>     The spawn marker, at the player's feet. Default player_spawn.
##   --enemy-group <name>     Enemies, at their feet. Default enemies.
##   --required-group <a,b>   Groups of nodes the player must reach. Default required.
##   --solid-group <a,b>      Groups of nodes whose collision shapes are solid, on top
##                            of the bodies on the world mask. Default none.
##   --wall-layer <name>      Name of the TileMapLayer that holds walls. Its cells are
##                            solid (their collision polygons when a tile has any, the
##                            whole cell otherwise). Every other layer is floor.
##                            Default Walls.
##   --world-mask <bits>      Collision layer bits of the static bodies and tile
##                            polygons that block the player. Default 1.
##   --player <res://p.tscn>  The player scene: the collision shapes directly under
##                            its root give the player's box around its feet.
##   --player-group <name>    Else the node of the level in this group. Default player.
##   --size <WxH>             Else a box this big centred on the feet.
##   --reach <px>             How close to a node the player must be able to stand
##                            for the node to count as reached. Default 16.
##   --step <px>              Samples this far apart. Default 2.
##   --no-navigation          Skip the navigation checks.
##   --image <absolute.png>   Write a map, one pixel per sample: walls grey, props
##                            brown, reachable floor green, unreachable floor red,
##                            spawn blue, enemies white, required nodes yellow, the
##                            navigation outline magenta, floor the navigation
##                            misses cyan, wall or prop centres it covers orange.
##
## Exit codes: 0 pass, 1 fail, 2 bad arguments. The last line printed always
## starts with `level_check:`.
extends SceneTree

const MAX_LISTED: int = 8
const SYNC_FRAMES: int = 10
const PATH_END_SLACK: float = 1.0
const NAV_MARGIN: float = 4.0
const NAV_TOLERANCE: float = 1.0
# Bake simplification and cell snapping leave a few stray samples off the polygon; a stale bake misses whole areas.
const NAV_MISS_SHARE: float = 0.02
const NAV_STRIDE_PX: int = 16
const VALUE_OPTIONS: PackedStringArray = [
	"spawn-group", "enemy-group", "required-group", "solid-group", "wall-layer",
	"world-mask", "player", "player-group", "size", "reach", "step", "image",
]
const USAGE: String = "Usage: godot --headless --path <project> --script <this file> -- <res://level.tscn> [--spawn-group n] [--enemy-group n] [--required-group a,b] [--solid-group a,b] [--wall-layer n] [--world-mask bits] [--player res://p.tscn | --player-group n | --size WxH] [--reach px] [--step px] [--no-navigation] [--image file.png]"

const VOID: Color = Color8(14, 13, 20)
const WALL: Color = Color8(110, 110, 120)
const PROP: Color = Color8(135, 88, 45)
const REACHABLE: Color = Color8(60, 165, 80)
const UNREACHABLE: Color = Color8(210, 50, 50)
const SPAWN: Color = Color8(50, 110, 255)
const ENEMY: Color = Color8(255, 255, 255)
const REQUIRED: Color = Color8(255, 215, 0)
const NAVIGATION: Color = Color8(255, 70, 220)
const NAV_MISSED: Color = Color8(0, 230, 230)
const NAV_COVERED: Color = Color8(255, 150, 0)

var _spawn_group: StringName = &"player_spawn"
var _enemy_group: StringName = &"enemies"
var _required_groups: Array[StringName] = [&"required"]
var _solid_groups: Array[StringName] = []
var _wall_layer: String = "Walls"
var _world_mask: int = 1
var _player_scene: String = ""
var _player_group: StringName = &"player"
var _size: Vector2 = Vector2.ZERO
var _reach: float = 16.0
var _step: int = 2
var _navigation: bool = true
var _image_path: String = ""

var _origin: Vector2
var _columns: int = 0
var _rows: int = 0
var _ground: PackedByteArray
var _wall: PackedByteArray
var _prop: PackedByteArray
var _reachable: PackedByteArray
var _covered: PackedByteArray
var _blocked: PackedInt32Array
var _box: Rect2i
var _grid: TileMapLayer
var _failures: PackedStringArray = []
var _paths: int = 0
var _solid_centres: PackedVector2Array = []
var _missed: PackedVector2Array = []
var _covering: PackedVector2Array = []


func _initialize() -> void:
	var scene_path: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	var values: Dictionary[String, String] = {}
	while index < args.size():
		var arg: String = args[index]
		if arg == "--help" or arg == "-h":
			print(USAGE)
			print("level_check: usage only, nothing checked")
			quit(0)
			return
		if arg == "--no-navigation":
			_navigation = false
		elif arg.begins_with("--") and arg.trim_prefix("--") in VALUE_OPTIONS:
			index += 1
			if index >= args.size():
				_bad_arguments("%s needs a value" % arg)
				return
			values[arg.trim_prefix("--")] = args[index]
		elif scene_path.is_empty() and not arg.begins_with("-"):
			scene_path = arg
		else:
			_bad_arguments("unexpected argument \"%s\"" % arg)
			return
		index += 1
	if scene_path.is_empty():
		_bad_arguments("no level scene given")
		return
	if not _apply(values):
		return
	var packed: PackedScene = load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
	if packed == null:
		_bad_arguments("%s is not a scene" % scene_path)
		return
	var level: Node = packed.instantiate()
	var summary: String = await _check(level)
	level.free()
	for failure: String in _failures:
		print("FAIL ", failure)
	print("level_check: ", summary)
	quit(1 if not _failures.is_empty() else 0)


func _apply(values: Dictionary[String, String]) -> bool:
	_spawn_group = StringName(values.get("spawn-group", _spawn_group))
	_enemy_group = StringName(values.get("enemy-group", _enemy_group))
	_player_group = StringName(values.get("player-group", _player_group))
	_wall_layer = values.get("wall-layer", _wall_layer)
	_player_scene = values.get("player", "")
	_image_path = values.get("image", "")
	if values.has("required-group"):
		_required_groups = _names(values["required-group"])
	if values.has("solid-group"):
		_solid_groups = _names(values["solid-group"])
	if values.has("world-mask"):
		if not values["world-mask"].is_valid_int():
			_bad_arguments("--world-mask is not a number")
			return false
		_world_mask = values["world-mask"].to_int()
	if values.has("reach"):
		_reach = values["reach"].to_float()
	if values.has("step"):
		_step = values["step"].to_int()
	if _step < 1 or _reach < 0.0:
		_bad_arguments("--step must be at least 1 and --reach not negative")
		return false
	if values.has("size"):
		var parts: PackedStringArray = values["size"].to_lower().split("x")
		if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
			_bad_arguments("--size is not WxH")
			return false
		_size = Vector2(parts[0].to_float(), parts[1].to_float())
	return true


func _names(list: String) -> Array[StringName]:
	var names: Array[StringName] = []
	for part: String in list.split(",", false):
		names.append(StringName(part.strip_edges()))
	return names


func _bad_arguments(message: String) -> void:
	printerr("Error: %s.\n%s" % [message, USAGE])
	print("level_check: bad arguments")
	quit(2)


func _check(level: Node) -> String:
	var layers: Array[TileMapLayer] = []
	var bodies: Array[Node2D] = []
	_collect(level, layers, bodies)
	var spawn: Node2D = _first_in_group(level, _spawn_group)
	var player_shapes: Node = null
	var player_instance: Node = null
	if _size == Vector2.ZERO:
		if not _player_scene.is_empty():
			var player_packed: PackedScene = load(_player_scene) as PackedScene if ResourceLoader.exists(_player_scene) else null
			if player_packed == null:
				_failures.append("--player %s is not a scene" % _player_scene)
			else:
				player_instance = player_packed.instantiate()
				player_shapes = player_instance
		else:
			player_shapes = _first_in_group(level, _player_group)
	var camera: Camera2D = _first_camera(level)
	if camera == null and player_instance != null:
		camera = _first_camera(player_instance)
	if layers.is_empty():
		_failures.append("the level has no TileMapLayer")
	if spawn == null:
		_failures.append("no node in group %s" % _spawn_group)
	if _size == Vector2.ZERO and (player_shapes == null or _shape_polygons(player_shapes, Transform2D.IDENTITY).is_empty()):
		_failures.append("no player collision shape: pass --player, --size, or put the player in group %s" % _player_group)
	if not _failures.is_empty():
		if player_instance != null:
			player_instance.free()
		return "FAIL, %d problem%s" % [_failures.size(), "" if _failures.size() == 1 else "s"]

	_rasterize(layers, bodies)
	_box = _player_box(player_shapes)
	if player_instance != null:
		player_instance.free()
	var start: Vector2i = _sample_of(_global_xform(spawn).origin)
	if not _fits(start):
		_failures.append("the spawn at %s has no room for the player" % _describe(_global_xform(spawn).origin))
	else:
		_flood(start)
	_cover()

	var enemies: Array[Node2D] = _in_group(level, _enemy_group)
	for enemy: Node2D in enemies:
		var feet: Vector2 = _global_xform(enemy).origin
		if not _is_floor(_sample_of(feet)):
			_failures.append("%s at %s stands in a wall, a prop or outside the level" % [level.get_path_to(enemy), _describe(feet)])
		elif not _any(_reachable, Rect2(feet - Vector2.ONE * _reach, Vector2.ONE * _reach * 2.0)):
			_failures.append("%s at %s stands where the player cannot reach" % [level.get_path_to(enemy), _describe(feet)])

	var required: Array[Node2D] = []
	for group: StringName in _required_groups:
		for node: Node2D in _in_group(level, group):
			if not node in required:
				required.append(node)
	for node: Node2D in required:
		var area: Rect2 = Rect2(_global_xform(node).origin, Vector2.ZERO)
		for polygon: PackedVector2Array in _shape_polygons(node, _global_xform(node)):
			for point: Vector2 in polygon:
				area = area.expand(point)
		if not _any(_reachable, area.grow(_reach)):
			_failures.append("%s at %s cannot be reached" % [level.get_path_to(node), _describe(_global_xform(node).origin)])

	var note: String = ""
	if camera == null:
		note = ", no Camera2D so the limits were not checked"
	else:
		_check_limits(camera)

	var regions: Array[NavigationRegion2D] = _regions(level)
	if _navigation:
		await _check_navigation(level, regions, spawn, enemies)

	var floor_samples: int = 0
	var reachable_floor: int = 0
	for index: int in _columns * _rows:
		if _ground[index] and not _wall[index] and not _prop[index]:
			floor_samples += 1
			reachable_floor += _covered[index]
	if not _image_path.is_empty():
		_save_image(spawn, enemies, required, regions)
	return "%s, %d enemies, %d required, %.1f%% of the floor reachable, %s%s%s" % [
		"FAIL, %d problem%s" % [_failures.size(), "" if _failures.size() == 1 else "s"] if not _failures.is_empty() else "OK",
		enemies.size(),
		required.size(),
		100.0 * reachable_floor / maxi(floor_samples, 1),
		"%d of %d enemies with a navigation path" % [_paths, enemies.size()] if _navigation else "navigation skipped",
		note,
		", map in %s" % _image_path if not _image_path.is_empty() else "",
	]


func _check_limits(camera: Camera2D) -> void:
	var limits: Rect2 = Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top),
	)
	var outside: Dictionary[Vector2i, bool] = {}
	for row: int in _rows:
		for column: int in _columns:
			var sample: Vector2i = Vector2i(column, row)
			if _reachable[_index(sample)] and not limits.has_point(_position_of(sample)):
				outside[_cell_of(_position_of(sample))] = true
	if not outside.is_empty():
		var cells: Array = outside.keys().slice(0, MAX_LISTED).map(func(cell: Vector2i) -> String: return str(cell))
		_failures.append("reachable floor outside the camera limits %s, in %d cells such as %s" % [limits, outside.size(), ", ".join(cells)])


func _collect(node: Node, layers: Array[TileMapLayer], bodies: Array[Node2D]) -> void:
	if node is TileMapLayer:
		layers.append(node)
	elif node is Node2D:
		var solid: bool = false
		for group: StringName in _solid_groups:
			solid = solid or node.is_in_group(group)
		if node is PhysicsBody2D and not node is CharacterBody2D and (node as CollisionObject2D).collision_layer & _world_mask:
			solid = true
		if solid:
			bodies.append(node)
	for child: Node in node.get_children():
		_collect(child, layers, bodies)


## The level is never added to the tree, so transforms are composed by hand.
func _global_xform(node: Node) -> Transform2D:
	var xform: Transform2D = Transform2D.IDENTITY
	var current: Node = node
	while current != null:
		if current is Node2D:
			xform = (current as Node2D).transform * xform
		current = current.get_parent()
	return xform


func _first_in_group(node: Node, group: StringName) -> Node2D:
	var found: Array[Node2D] = _in_group(node, group)
	return found[0] if not found.is_empty() else null


func _in_group(node: Node, group: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if node is Node2D and node.is_in_group(group):
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_in_group(child, group))
	return found


func _regions(node: Node) -> Array[NavigationRegion2D]:
	var found: Array[NavigationRegion2D] = []
	var region: NavigationRegion2D = node as NavigationRegion2D
	if region != null and region.enabled and region.navigation_polygon != null \
			and region.navigation_polygon.get_polygon_count() > 0:
		found.append(region)
	for child: Node in node.get_children():
		found.append_array(_regions(child))
	return found


func _first_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child: Node in node.get_children():
		var camera: Camera2D = _first_camera(child)
		if camera != null:
			return camera
	return null


## The world-space polygons of an object's enabled collision children.
func _shape_polygons(owner_node: Node, xform: Transform2D) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for child: Node in owner_node.get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		var polygon: CollisionPolygon2D = child as CollisionPolygon2D
		if shape != null and not shape.disabled and shape.shape != null:
			var points: PackedVector2Array = _shape_points(shape.shape)
			if not points.is_empty():
				polygons.append((xform * shape.transform) * points)
		elif polygon != null and not polygon.disabled and polygon.polygon.size() >= 3:
			polygons.append((xform * polygon.transform) * polygon.polygon)
	return polygons


func _shape_points(shape: Shape2D) -> PackedVector2Array:
	var points: PackedVector2Array = []
	if shape is RectangleShape2D:
		var half: Vector2 = (shape as RectangleShape2D).size * 0.5
		points = [-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	elif shape is CircleShape2D:
		for step: int in 16:
			points.append(Vector2.from_angle(TAU * step / 16.0) * (shape as CircleShape2D).radius)
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		var reach: float = maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		for step: int in 17:
			points.append(Vector2(0.0, -reach) + Vector2.from_angle(PI + PI * step / 16.0) * capsule.radius)
		for step: int in 17:
			points.append(Vector2(0.0, reach) + Vector2.from_angle(PI * step / 16.0) * capsule.radius)
	elif shape is ConvexPolygonShape2D:
		points = (shape as ConvexPolygonShape2D).points
	return points


## The level never enters the tree, so its regions go on a navigation map of the check's own.
func _check_navigation(level: Node, regions: Array[NavigationRegion2D], spawn: Node2D, enemies: Array[Node2D]) -> void:
	if enemies.is_empty():
		return
	if regions.is_empty():
		_failures.append("no NavigationRegion2D with a baked polygon: the enemies cannot find paths")
		return
	var reach: float = 0.0
	for enemy: Node2D in enemies:
		for polygon: PackedVector2Array in _shape_polygons(enemy, Transform2D.IDENTITY):
			for point: Vector2 in polygon:
				reach = maxf(reach, point.length())
	var inset: float = INF
	for region: NavigationRegion2D in regions:
		inset = minf(inset, region.navigation_polygon.agent_radius)
	if ceilf(reach) > inset:
		_failures.append("the navigation polygon is inset %.0f px from walls and props, but the enemies' collision shape reaches %.1f px from their feet: rebake the navigation" % [inset, reach])
	var map: RID = NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(map, regions[0].navigation_polygon.cell_size)
	NavigationServer2D.map_set_use_async_iterations(map, false)
	NavigationServer2D.map_set_active(map, true)
	var rids: Array[RID] = []
	for region: NavigationRegion2D in regions:
		var rid: RID = NavigationServer2D.region_create()
		NavigationServer2D.region_set_use_async_iterations(rid, false)
		NavigationServer2D.region_set_map(rid, map)
		NavigationServer2D.region_set_transform(rid, _global_xform(region))
		NavigationServer2D.region_set_navigation_layers(rid, region.navigation_layers)
		NavigationServer2D.region_set_navigation_polygon(rid, region.navigation_polygon)
		rids.append(rid)
	var frames: int = 0
	while NavigationServer2D.map_get_iteration_id(map) == 0 and frames < SYNC_FRAMES:
		await physics_frame
		frames += 1
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		_failures.append("the navigation map did not synchronise within %d physics frames" % SYNC_FRAMES)
	else:
		_query_paths(level, map, inset, spawn, enemies)
		_check_stale(map, inset)
	for rid: RID in rids:
		NavigationServer2D.free_rid(rid)
	NavigationServer2D.free_rid(map)


## Walls or props changed after the bake leave floor outside the polygon or polygon over solids.
func _check_stale(map: RID, inset: float) -> void:
	var clear: int = ceili((inset + NAV_MARGIN) / _step)
	var stride: int = maxi(NAV_STRIDE_PX / _step, 1)
	var table: PackedInt32Array = _table(func(index: int) -> bool: return not _ground[index] or _wall[index] or _prop[index])
	var tested: int = 0
	var missed: PackedVector2Array = []
	for row: int in range(clear, _rows - clear, stride):
		for column: int in range(clear, _columns - clear, stride):
			var sample: Vector2i = Vector2i(column, row)
			if not _reachable[_index(sample)] or _count(table, sample - Vector2i.ONE * clear, sample + Vector2i.ONE * clear) > 0:
				continue
			tested += 1
			var point: Vector2 = _position_of(sample)
			if NavigationServer2D.map_get_closest_point(map, point).distance_to(point) > NAV_TOLERANCE:
				missed.append(point)
	if tested > 0 and missed.size() > NAV_MISS_SHARE * tested:
		_failures.append("navigation misses reachable floor: rebake (%d of %d clear samples, e.g. %s)" % [missed.size(), tested, _list(missed)])
		_missed = missed
	var covering: PackedVector2Array = []
	for point: Vector2 in _solid_centres:
		if NavigationServer2D.map_get_closest_point(map, point).distance_to(point) <= NAV_TOLERANCE:
			covering.append(point)
	if not covering.is_empty():
		_failures.append("navigation covers walls or props: rebake (%d of %d centres, e.g. %s)" % [covering.size(), _solid_centres.size(), _list(covering)])
		_covering = covering


func _list(points: PackedVector2Array) -> String:
	var parts: PackedStringArray = []
	for index: int in mini(points.size(), 3):
		var point: Vector2 = points[index * points.size() / mini(points.size(), 3)]
		parts.append(_describe(point))
	return "; ".join(parts)


## A path to an unreachable target stops at the reachable point nearest it, so it has to end at the
## spawn's nearest point; feet within the inset of the polygon are on it.
func _query_paths(level: Node, map: RID, inset: float, spawn: Node2D, enemies: Array[Node2D]) -> void:
	var target: Vector2 = _global_xform(spawn).origin
	var goal: Vector2 = NavigationServer2D.map_get_closest_point(map, target)
	if goal.distance_to(target) > inset:
		_failures.append("the spawn at %s is %.0f px from the navigation polygon" % [_describe(target), goal.distance_to(target)])
		return
	for enemy: Node2D in enemies:
		var feet: Vector2 = _global_xform(enemy).origin
		var path: PackedVector2Array = NavigationServer2D.map_get_path(map, feet, target, true)
		var reason: String = ""
		if path.is_empty():
			reason = "the query found none"
		elif path[0].distance_to(feet) > inset:
			reason = "its feet are %.0f px from the navigation polygon" % path[0].distance_to(feet)
		elif path[path.size() - 1].distance_to(goal) > PATH_END_SLACK:
			reason = "the nearest it gets is %s" % _describe(path[path.size() - 1])
		if reason.is_empty():
			_paths += 1
		else:
			_failures.append("%s at %s has no navigation path to the spawn: %s" % [level.get_path_to(enemy), _describe(feet), reason])


## Tile outline by cell shape: a diamond for isometric sets, a rectangle otherwise.
func _cell_outline(layer: TileMapLayer) -> PackedVector2Array:
	var half: Vector2 = Vector2(layer.tile_set.tile_size) * 0.5
	if layer.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC:
		return [Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y), Vector2(-half.x, 0.0)]
	return [-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]


func _rasterize(layers: Array[TileMapLayer], bodies: Array[Node2D]) -> void:
	var bounds: Rect2 = Rect2()
	var cells: Array[PackedVector2Array] = []
	var walls: Array[PackedVector2Array] = []
	for layer: TileMapLayer in layers:
		if layer.tile_set == null:
			continue
		var is_wall_layer: bool = String(layer.name) == _wall_layer
		if _grid == null or (_grid.name == _wall_layer and not is_wall_layer):
			_grid = layer
		var xform: Transform2D = _global_xform(layer)
		var shape: PackedVector2Array = _cell_outline(layer)
		var world_layers: Array[int] = []
		for physics_layer: int in layer.tile_set.get_physics_layers_count():
			if layer.tile_set.get_physics_layer_collision_layer(physics_layer) & _world_mask:
				world_layers.append(physics_layer)
		for cell: Vector2i in layer.get_used_cells():
			var centre: Transform2D = xform * Transform2D(0.0, layer.map_to_local(cell))
			var outline: PackedVector2Array = centre * shape
			if cells.is_empty():
				bounds = Rect2(outline[0], Vector2.ZERO)
			cells.append(outline)
			for point: Vector2 in outline:
				bounds = bounds.expand(point)
			var data: TileData = layer.get_cell_tile_data(cell)
			var found: bool = false
			if data != null and layer.collision_enabled:
				for physics_layer: int in world_layers:
					for polygon: int in data.get_collision_polygons_count(physics_layer):
						walls.append(centre * data.get_collision_polygon_points(physics_layer, polygon))
						found = true
			if is_wall_layer and not found:
				walls.append(outline)
	_origin = bounds.position
	_columns = ceili(bounds.size.x / _step)
	_rows = ceili(bounds.size.y / _step)
	_ground.resize(_columns * _rows)
	_wall.resize(_columns * _rows)
	_prop.resize(_columns * _rows)
	for polygon: PackedVector2Array in cells:
		_fill_polygon(_ground, polygon)
	for polygon: PackedVector2Array in walls:
		_fill_polygon(_wall, polygon)
		_solid_centres.append(_centroid(polygon))
	for body: Node2D in bodies:
		for polygon: PackedVector2Array in _shape_polygons(body, _global_xform(body)):
			_fill_polygon(_prop, polygon)
			_solid_centres.append(_centroid(polygon))


func _centroid(polygon: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		sum += point
	return sum / polygon.size()


func _player_box(shapes: Node) -> Rect2i:
	var box: Rect2 = Rect2(-_size * 0.5, _size)
	if shapes != null:
		var first: bool = true
		for polygon: PackedVector2Array in _shape_polygons(shapes, Transform2D.IDENTITY):
			for point: Vector2 in polygon:
				box = Rect2(point, Vector2.ZERO) if first else box.expand(point)
				first = false
	var from: Vector2i = Vector2i(roundi(box.position.x / _step), roundi(box.position.y / _step))
	var to: Vector2i = Vector2i(roundi(box.end.x / _step), roundi(box.end.y / _step))
	return Rect2i(from, to - from)


func _index(sample: Vector2i) -> int:
	return sample.y * _columns + sample.x


func _inside(sample: Vector2i) -> bool:
	return sample.x >= 0 and sample.y >= 0 and sample.x < _columns and sample.y < _rows


func _sample_of(point: Vector2) -> Vector2i:
	return Vector2i(((point - _origin) / _step).floor())


func _position_of(sample: Vector2i) -> Vector2:
	return _origin + (Vector2(sample) + Vector2(0.5, 0.5)) * _step


func _describe(point: Vector2) -> String:
	return "(%d, %d), cell %s" % [roundi(point.x), roundi(point.y), _cell_of(point)]


func _cell_of(point: Vector2) -> Vector2i:
	return _grid.local_to_map(_global_xform(_grid).affine_inverse() * point)


func _is_floor(sample: Vector2i) -> bool:
	if not _inside(sample):
		return false
	var index: int = _index(sample)
	return _ground[index] and not _wall[index] and not _prop[index]


func _fill_polygon(target: PackedByteArray, polygon: PackedVector2Array) -> void:
	var box: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		box = box.expand(point)
	var from: Vector2i = _sample_of(box.position).clamp(Vector2i.ZERO, Vector2i(_columns, _rows))
	var to: Vector2i = (_sample_of(box.end) + Vector2i.ONE).clamp(Vector2i.ZERO, Vector2i(_columns, _rows))
	for row: int in range(from.y, to.y):
		for column: int in range(from.x, to.x):
			if Geometry2D.is_point_in_polygon(_position_of(Vector2i(column, row)), polygon):
				target[row * _columns + column] = 1


## Summed-area table of a mask, one row and column larger than the grid.
func _table(mask: Callable) -> PackedInt32Array:
	var table: PackedInt32Array = []
	table.resize((_columns + 1) * (_rows + 1))
	for row: int in _rows:
		var running: int = 0
		for column: int in _columns:
			running += 1 if mask.call(row * _columns + column) else 0
			table[(row + 1) * (_columns + 1) + column + 1] = table[row * (_columns + 1) + column + 1] + running
	return table


## How many marked samples lie in the rectangle of samples, clipped to the grid.
func _count(table: PackedInt32Array, from: Vector2i, to: Vector2i) -> int:
	var a: Vector2i = from.clamp(Vector2i.ZERO, Vector2i(_columns, _rows))
	var b: Vector2i = (to + Vector2i.ONE).clamp(Vector2i.ZERO, Vector2i(_columns, _rows))
	if a.x >= b.x or a.y >= b.y:
		return 0
	var width: int = _columns + 1
	return table[b.y * width + b.x] - table[a.y * width + b.x] - table[b.y * width + a.x] + table[a.y * width + a.x]


func _fits(sample: Vector2i) -> bool:
	if _blocked.is_empty():
		_blocked = _table(func(index: int) -> bool: return not _ground[index] or _wall[index] or _prop[index])
	var from: Vector2i = sample + _box.position
	var to: Vector2i = sample + _box.end
	if from.x < 0 or from.y < 0 or to.x >= _columns or to.y >= _rows:
		return false
	return _count(_blocked, from, to) == 0


func _flood(start: Vector2i) -> void:
	_reachable.resize(_columns * _rows)
	var queue: PackedInt32Array = [_index(start)]
	_reachable[_index(start)] = 1
	var head: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var sample: Vector2i = Vector2i(index % _columns, index / _columns)
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = sample + step
			if not _inside(next) or _reachable[_index(next)] or not _fits(next):
				continue
			_reachable[_index(next)] = 1
			queue.append(_index(next))


## Marks every sample the player's collision box covers from some reachable position.
func _cover() -> void:
	_reachable.resize(_columns * _rows)
	_covered.resize(_columns * _rows)
	var table: PackedInt32Array = _table(func(index: int) -> bool: return _reachable[index] == 1)
	for row: int in _rows:
		for column: int in _columns:
			var sample: Vector2i = Vector2i(column, row)
			if _count(table, sample - _box.end, sample - _box.position) > 0:
				_covered[_index(sample)] = 1


func _any(mask: PackedByteArray, rect: Rect2) -> bool:
	var from: Vector2i = _sample_of(rect.position)
	var to: Vector2i = _sample_of(rect.end)
	for row: int in range(maxi(from.y, 0), mini(to.y + 1, _rows)):
		for column: int in range(maxi(from.x, 0), mini(to.x + 1, _columns)):
			if mask[row * _columns + column]:
				return true
	return false


func _save_image(spawn: Node2D, enemies: Array[Node2D], required: Array[Node2D], regions: Array[NavigationRegion2D]) -> void:
	var pixels: PackedByteArray = []
	pixels.resize(_columns * _rows * 3)
	for index: int in _columns * _rows:
		var color: Color = VOID
		if _prop[index]:
			color = PROP
		elif _wall[index]:
			color = WALL
		elif _ground[index]:
			color = REACHABLE if _covered[index] else UNREACHABLE
		pixels[index * 3] = color.r8
		pixels[index * 3 + 1] = color.g8
		pixels[index * 3 + 2] = color.b8
	var image: Image = Image.create_from_data(_columns, _rows, false, Image.FORMAT_RGB8, pixels)
	for region: NavigationRegion2D in regions:
		_draw_outline(image, region)
	for point: Vector2 in _missed:
		_mark(image, point, 1, NAV_MISSED)
	for point: Vector2 in _covering:
		_mark(image, point, 1, NAV_COVERED)
	for node: Node2D in required:
		_mark(image, _global_xform(node).origin, 3, REQUIRED)
	for enemy: Node2D in enemies:
		_mark(image, _global_xform(enemy).origin, 2, ENEMY)
	_mark(image, _global_xform(spawn).origin, 3, SPAWN)
	DirAccess.make_dir_recursive_absolute(_image_path.get_base_dir())
	var error: Error = image.save_png(_image_path)
	if error != OK:
		printerr("Error: cannot write %s: %s" % [_image_path, error_string(error)])


## Draws the edges that belong to a single polygon of the region: its outline and holes.
func _draw_outline(image: Image, region: NavigationRegion2D) -> void:
	var polygon: NavigationPolygon = region.navigation_polygon
	var vertices: PackedVector2Array = _global_xform(region) * polygon.get_vertices()
	var edges: Dictionary[Vector2i, int] = {}
	for index: int in polygon.get_polygon_count():
		var corners: PackedInt32Array = polygon.get_polygon(index)
		for corner: int in corners.size():
			var a: int = corners[corner]
			var b: int = corners[(corner + 1) % corners.size()]
			var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			edges[edge] = edges.get(edge, 0) + 1
	for edge: Vector2i in edges:
		if edges[edge] == 1:
			_line(image, vertices[edge.x], vertices[edge.y], NAVIGATION)


func _line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var a: Vector2 = (from - _origin) / _step
	var b: Vector2 = (to - _origin) / _step
	var steps: int = maxi(ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))), 1)
	for step: int in steps + 1:
		var sample: Vector2i = Vector2i(a.lerp(b, float(step) / steps).floor())
		if _inside(sample):
			image.set_pixelv(sample, color)


func _mark(image: Image, point: Vector2, radius: int, color: Color) -> void:
	var centre: Vector2i = _sample_of(point)
	for row: int in range(centre.y - radius, centre.y + radius + 1):
		for column: int in range(centre.x - radius, centre.x + radius + 1):
			if _inside(Vector2i(column, row)):
				image.set_pixel(column, row, color)
