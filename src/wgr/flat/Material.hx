package wgr.flat;

// wgr_material.h — how a surface is shaded, flat

import wgr.impl.Raw;

/**
	The flat form of `wgr.Material`: every operation is a static whose name says which
	C call it makes.

	```haxe
	final m = Material.create(Pbr);
	Material.setRoughness(m, 0.35);
	Material.setBaseColorTexture(m, albedo);
	Material.setBaseColor(m, 0.9, 0.2, 0.2);
	Model.setMaterial(model, 0, m);
	Material.release(m);
	```

	Every `set*` returns what C returned. That is the visible difference from
	`wgr.Material`, whose property setters cannot: Haxe requires `set_roughness` to
	return `Float`, so the `Bool` from `wgr_material_set_float` is dropped on the floor
	and a refused parameter is silent at the call site. Four float properties and five
	texture properties do that today.
**/
abstract Material(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create(shading:MaterialShading = Pbr):Material
		return (Raw.wgr_material_create(shading) : Handle);

	/** A material drawn by a custom shader; it holds its own reference to the shader. **/
	public static inline function createCustom(shader:Handle):Material
		return (Raw.wgr_material_create_custom(shader) : Handle);

	/** Drop this reference; the material goes when the last one does. **/
	public static inline function release(material:Material):Void
		Raw.wgr_material_release(material);

	// --- the built-in glTF parameters, by name in the header's table ---

	/** 0..1. **/
	public static inline function setMetallic(material:Material, value:Float):Bool
		return setFloat(material, "metallic", value);

	/** 0..1. **/
	public static inline function setRoughness(material:Material, value:Float):Bool
		return setFloat(material, "roughness", value);

	public static inline function setNormalScale(material:Material, value:Float):Bool
		return setFloat(material, "normal_scale", value);

	/** 0..1. **/
	public static inline function setOcclusionStrength(material:Material, value:Float):Bool
		return setFloat(material, "occlusion_strength", value);

	/** sRGB rgba. **/
	public static inline function setBaseColorTexture(material:Material, texture:Texture):Bool
		return setTexture(material, "base_color_texture", texture);

	/** Green is roughness, blue is metallic. **/
	public static inline function setMetallicRoughnessTexture(material:Material, texture:Texture):Bool
		return setTexture(material, "metallic_roughness_texture", texture);

	/** Tangent-space normal map. **/
	public static inline function setNormalTexture(material:Material, texture:Texture):Bool
		return setTexture(material, "normal_texture", texture);

	/** Red is ambient occlusion. **/
	public static inline function setOcclusionTexture(material:Material, texture:Texture):Bool
		return setTexture(material, "occlusion_texture", texture);

	/** sRGB rgb. **/
	public static inline function setEmissiveTexture(material:Material, texture:Texture):Bool
		return setTexture(material, "emissive_texture", texture);

	/** Linear rgba, glTF's factor — not an sRGB `Color`. Alpha drives Mask and Blend. **/
	public static inline function setBaseColor(material:Material, r:Float, g:Float, b:Float, a:Float = 1):Bool
		return setVec4(material, "base_color", r, g, b, a);

	/** Linear rgb, and may exceed 1. **/
	public static inline function setEmissive(material:Material, r:Float, g:Float, b:Float):Bool
		return setVec3(material, "emissive", r, g, b);

	/**
		How it uses alpha; `cutoff` applies to `Mask`. `Add` is not supported for
		materials yet and is refused — additive belongs to sprites and particles.
	**/
	public static inline function setAlphaMode(material:Material, mode:AlphaMode, cutoff:Float = 0.5):Bool
		return Raw.wgr_material_set_alpha_mode(material, mode, cutoff);

	public static inline function getAlphaMode(material:Material):AlphaMode
		return AlphaMode.of(Raw.wgr_material_get_alpha_mode(material));

	/** Built-in shading mode; `Custom` only ever comes from `Material.createCustom`. **/
	public static inline function getShading(material:Material):MaterialShading
		return Raw.wgr_material_get_shading(material);

	public static inline function setShading(material:Material, shading:MaterialShading):Bool
		return Raw.wgr_material_set_shading(material, shading);

	/** Drawn from both sides. Default: single sided. **/
	public static inline function isDoubleSided(material:Material):Bool
		return Raw.wgr_material_is_double_sided(material);

	public static inline function setDoubleSided(material:Material, value:Bool):Bool
		return Raw.wgr_material_set_double_sided(material, value);

	/** Its custom shader, or none for built-in shading. **/
	public static inline function getShader(material:Material):Handle
		return Raw.wgr_material_get_shader(material);

	// --- by name, for a custom shader's own parameters ---

	public static inline function setInt(material:Material, name:String, value:Int):Bool
		return Raw.wgr_material_set_int(material, name, value);

	public static inline function setFloat(material:Material, name:String, value:Float):Bool
		return Raw.wgr_material_set_float(material, name, value);

	public static inline function setVec2(material:Material, name:String, x:Float, y:Float):Bool
		return Raw.wgr_material_set_vec2(material, name, x, y);

	public static inline function setVec3(material:Material, name:String, x:Float, y:Float, z:Float):Bool
		return Raw.wgr_material_set_vec3(material, name, x, y, z);

	public static inline function setVec4(material:Material, name:String, x:Float, y:Float, z:Float, w:Float):Bool
		return Raw.wgr_material_set_vec4(material, name, x, y, z, w);

	/** An sRGB colour handle, converted to linear. **/
	public static inline function setColor(material:Material, name:String, color:Color):Bool
		return Raw.wgr_material_set_color(material, name, color);

	public static inline function setTexture(material:Material, name:String, texture:Texture):Bool
		return Raw.wgr_material_set_texture(material, name, texture);

	public static inline function setTextureSampling(material:Material, name:String, wrapU:TextureWrap,
			wrapV:TextureWrap, filter:TextureFilter):Bool
		return Raw.wgr_material_set_texture_sampling(material, name, wrapU, wrapV, filter);
}
