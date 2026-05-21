class_name RenderSystem
extends RefCounted

var _render_node: Node2D

func _init(render_node: Node2D) -> void:
	_render_node = render_node

func update(world: ECSWorld, delta: float) -> void:
	_render_node.queue_redraw()

func draw(world: ECSWorld) -> void:
	_draw_entities(world, world.enemies)
	_draw_entities(world, world.weapon_entities)
	_draw_entities(world, world.projectiles)
	_draw_entities(world, world.players)
	_draw_entities(world, world.lifetimes)

func _draw_entities(world: ECSWorld, entities: Dictionary) -> void:
	for eid in entities:
		if not world.transforms.has(eid) or not world.sprites.has(eid):
			continue

		var trans = world.transforms[eid]
		var sprite = world.sprites[eid]
		var pos: Vector2 = trans["position"]
		var color: Color = sprite["color"]
		var size: float = sprite["size"]
		var rot: float = sprite.get("rotation", 0.0)
		var subs: Array = sprite.get("sub_sprites", [])
		var outline_radius: float = sprite.get("outline_radius", size * 0.55)
		var height_ratio: float = sprite.get("height", 1.0)

		var invincible = false
		if world.healths.has(eid):
			if world.healths[eid]["invincible_timer"] > 0:
				invincible = true

		var shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		var shadow_offset = Vector2(3.0, 4.0)
		var shadow_scale = 0.85

		if subs.size() > 0:
			for sub in subs:
				var sub_shape: String = sub.get("shape", "circle")
				var sub_size: float = sub.get("size", size)
				var sub_rot: float = sub.get("rotation", rot)
				var shadow_size = sub_size * shadow_scale
				if height_ratio > 0.8:
					_draw_shadow(sub_shape, pos + sub_offset_from(sprite, sub), shadow_size, shadow_color, shadow_offset, sub_rot)

			for sub in subs:
				var sub_offset: Vector2 = sub.get("offset", Vector2.ZERO)
				var sub_shape: String = sub.get("shape", "circle")
				var sub_size: float = sub.get("size", size)
				var sub_rot: float = sub.get("rotation", rot)
				var outline_size = sub_size + 2.5
				_draw_shape(sub_shape, pos + sub_offset, outline_size, Color(0.0, 0.0, 0.0, 0.85), sub_rot)

			for sub in subs:
				var sub_offset: Vector2 = sub.get("offset", Vector2.ZERO)
				var sub_shape: String = sub.get("shape", "circle")
				var sub_color: Color = sub.get("color", color)
				var sub_size: float = sub.get("size", size)
				var sub_rot: float = sub.get("rotation", rot)
				var draw_c = sub_color
				if invincible:
					draw_c = Color(sub_color.r, sub_color.g, sub_color.b, 0.4)
				_draw_shape(sub_shape, pos + sub_offset, sub_size, draw_c, sub_rot)
		else:
			var draw_color = color
			if invincible:
				draw_color = Color(color.r, color.g, color.b, 0.4)
			if height_ratio > 0.8:
				_draw_shadow(sprite["shape"], pos, size, shadow_color, shadow_offset, rot)
			_draw_shape(sprite["shape"], pos, size + 3.0, Color(0.0, 0.0, 0.0, 0.85), rot)
			_draw_shape(sprite["shape"], pos, size, draw_color, rot)

func sub_offset_from(sprite: Dictionary, sub: Dictionary) -> Vector2:
	return sub.get("offset", Vector2.ZERO)

func _draw_shadow(shape: String, pos: Vector2, size: float, color: Color, offset: Vector2, rotation: float) -> void:
	var shadow_pos = pos + offset
	var half = size * 0.5
	match shape:
		"circle":
			_render_node.draw_circle(shadow_pos, half, color)
		"rect", "barrel", "arc":
			_render_node.draw_rect(Rect2(shadow_pos - Vector2(half, half), Vector2(size, size)), color)
		"diamond":
			var pts = PackedVector2Array([
				shadow_pos + Vector2(0, -half),
				shadow_pos + Vector2(half, 0),
				shadow_pos + Vector2(0, half),
				shadow_pos + Vector2(-half, 0)
			])
			_render_node.draw_colored_polygon(pts, color)
		_:
			_render_node.draw_circle(shadow_pos, half, color)

func _draw_shape(shape: String, pos: Vector2, size: float, color: Color, rotation: float) -> void:
	match shape:
		"circle":
			_render_node.draw_circle(pos, size * 0.5, color)
		"rect":
			var half = size * 0.5
			var r = Rect2(pos - Vector2(half, half), Vector2(size, size))
			_render_node.draw_rect(r, color)
		"diamond":
			var h = size * 0.5
			var points = PackedVector2Array([
				pos + Vector2(0, -h),
				pos + Vector2(h, 0),
				pos + Vector2(0, h),
				pos + Vector2(-h, 0)
			])
			_render_node.draw_colored_polygon(points, color)
		"triangle":
			var h = size * 0.6
			var points = PackedVector2Array([
				pos + Vector2(cos(rotation - PI / 2) * h, sin(rotation - PI / 2) * h),
				pos + Vector2(cos(rotation + PI * 5 / 6) * h, sin(rotation + PI * 5 / 6) * h),
				pos + Vector2(cos(rotation + PI / 6) * h, sin(rotation + PI / 6) * h)
			])
			_render_node.draw_colored_polygon(points, color)
		"hexagon":
			var h = size * 0.5
			var pts = PackedVector2Array()
			for i in range(6):
				var angle = rotation + i * PI / 3.0
				pts.append(pos + Vector2(cos(angle) * h, sin(angle) * h))
			_render_node.draw_colored_polygon(pts, color)
		"barrel":
			var half_w = size * 0.22
			var half_h = size * 0.6
			var pts = PackedVector2Array([
				pos + Vector2(cos(rotation) * half_h - sin(rotation) * half_w, sin(rotation) * half_h + cos(rotation) * half_w),
				pos + Vector2(cos(rotation) * half_h + sin(rotation) * half_w, sin(rotation) * half_h - cos(rotation) * half_w),
				pos + Vector2(-cos(rotation) * half_h * 0.3 + sin(rotation) * half_w, -sin(rotation) * half_h * 0.3 - cos(rotation) * half_w),
				pos + Vector2(-cos(rotation) * half_h * 0.3 - sin(rotation) * half_w, -sin(rotation) * half_h * 0.3 + cos(rotation) * half_w)
			])
			_render_node.draw_colored_polygon(pts, color)
		"arc":
			var r = size * 0.5
			var arc_pts = PackedVector2Array()
			arc_pts.append(pos)
			var arc_start = rotation - PI * 0.55
			var arc_end = rotation + PI * 0.55
			var steps = 12
			for j in range(steps + 1):
				var a = arc_start + (arc_end - arc_start) * j / steps
				arc_pts.append(pos + Vector2(cos(a), sin(a)) * r)
			_render_node.draw_colored_polygon(arc_pts, color)
		_:
			_render_node.draw_circle(pos, size * 0.5, color)
