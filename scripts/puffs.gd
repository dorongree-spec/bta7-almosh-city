## Soft billboard particle clouds. Tyre smoke, engine smoke, fire, blasts and
## wind-blown dust are all the same thing with different numbers.
class_name Puffs
extends RefCounted


## tint: colour; box: emitter half-size; rise: upward pull (m/s^2);
## puff: sprite size in metres; glowing: additive, for fire.
static func make(tint: Color, amount: int, lifetime: float, box: Vector3, rise: float, puff: float, glowing := false) -> GPUParticles3D:
	var sprite := GradientTexture2D.new()
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 0.5))
	falloff.set_color(1, Color(1, 1, 1, 0.0))
	sprite.gradient = falloff
	sprite.fill = GradientTexture2D.FILL_RADIAL
	sprite.fill_from = Vector2(0.5, 0.5)
	sprite.fill_to = Vector2(1.0, 0.5)
	sprite.width = 64
	sprite.height = 64

	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = sprite
	look.albedo_color = tint
	if glowing:
		look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade

	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 40.0
	motion.initial_velocity_min = 0.5
	motion.initial_velocity_max = 1.8
	motion.gravity = Vector3(0, rise, 0)
	motion.scale_min = 0.6
	motion.scale_max = 1.6
	motion.color_ramp = fade_tex
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = box

	var quad := QuadMesh.new()
	quad.size = Vector2(puff, puff)
	quad.material = look

	var puffs := GPUParticles3D.new()
	puffs.amount = amount
	puffs.lifetime = lifetime
	puffs.local_coords = false
	puffs.process_material = motion
	puffs.draw_pass_1 = quad
	puffs.emitting = false
	return puffs
