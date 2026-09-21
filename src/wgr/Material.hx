package wgr;

// wgr_material.h — how a surface is shaded

/**
	A material: reference counted and shared, like a `Texture` or a `Mesh`. Assign it
	to a model's slot with `Model.setMaterial`; the model takes its own reference, so
	release yours when done.

	A new one carries glTF's defaults — white, fully metallic, fully rough, opaque,
	single sided — and shading follows glTF metallic-roughness in linear colour space.

	Parameters are set by name. The built-ins have properties here, which is the
	difference between a typo being a compile error and a silent `false`:

	```haxe
	final m = new Material(Pbr);
	m.roughness = 0.35;
	m.baseColorTexture = albedo;
	m.setBaseColor(0.9, 0.2, 0.2);   // linear rgba, glTF's factors
	model.setMaterial(0, m);
	m.release();                     // the model holds its own reference
	```

	A custom shader's parameters are whatever it declares, so those go through the
	`set*` methods by name.
**/
abstract Material(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	/** Built-in shading mode; `Custom` only ever comes from `Material.custom`. **/
	public var shading(get, set):MaterialShading;

	/** Drawn from both sides. Default: single sided. **/
	public var doubleSided(get, set):Bool;

	// --- the built-in glTF parameters, by name in the header's table ---

	/** 0..1. **/
	public var metallic(never, set):Float;

	/** 0..1. **/
	public var roughness(never, set):Float;

	public var normalScale(never, set):Float;

	/** 0..1. **/
	public var occlusionStrength(never, set):Float;

	/** sRGB rgba. **/
	public var baseColorTexture(never, set):Texture;

	/** Green is roughness, blue is metallic. **/
	public var metallicRoughnessTexture(never, set):Texture;

	/** Tangent-space normal map. **/
	public var normalTexture(never, set):Texture;

	/** Red is ambient occlusion. **/
	public var occlusionTexture(never, set):Texture;

	/** sRGB rgb. **/
	public var emissiveTexture(never, set):Texture;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new(shading:MaterialShading = Pbr)
		this = (Raw.wgr_material_create(shading) : Handle);

	/** A material drawn by a custom shader; it holds its own reference to the shader. **/
	public static inline function custom(shader:Handle):Material
		return (Raw.wgr_material_create_custom(shader) : Handle);

	/** Its custom shader, or none for built-in shading. **/
	public inline function getShader():Handle
		return Raw.wgr_material_get_shader(this);

	/** Drop this reference; the material goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_material_release(this);

	inline function get_shading():MaterialShading
		return Raw.wgr_material_get_shading(this);

	inline function set_shading(v:MaterialShading):MaterialShading {
		Raw.wgr_material_set_shading(this, v);
		return v;
	}

	inline function get_doubleSided():Bool
		return Raw.wgr_material_is_double_sided(this);

	inline function set_doubleSided(v:Bool):Bool {
		Raw.wgr_material_set_double_sided(this, v);
		return v;
	}

	/** How it uses alpha. Set it with `setAlphaMode`. **/
	public var alphaMode(get, never):AlphaMode;

	inline function get_alphaMode():AlphaMode
		return AlphaMode.of(Raw.wgr_material_get_alpha_mode(this));

	/**
		How it uses alpha; `cutoff` applies to `Mask`. `Add` is not supported for
		materials yet and is refused — additive belongs to sprites and particles.
	**/
	public inline function setAlphaMode(mode:AlphaMode, cutoff:Float = 0.5):Bool
		return Raw.wgr_material_set_alpha_mode(this, mode, cutoff);

	inline function set_metallic(v:Float):Float {
		setFloat("metallic", v);
		return v;
	}

	inline function set_roughness(v:Float):Float {
		setFloat("roughness", v);
		return v;
	}

	inline function set_normalScale(v:Float):Float {
		setFloat("normal_scale", v);
		return v;
	}

	inline function set_occlusionStrength(v:Float):Float {
		setFloat("occlusion_strength", v);
		return v;
	}

	inline function set_baseColorTexture(v:Texture):Texture {
		setTexture("base_color_texture", v);
		return v;
	}

	inline function set_metallicRoughnessTexture(v:Texture):Texture {
		setTexture("metallic_roughness_texture", v);
		return v;
	}

	inline function set_normalTexture(v:Texture):Texture {
		setTexture("normal_texture", v);
		return v;
	}

	inline function set_occlusionTexture(v:Texture):Texture {
		setTexture("occlusion_texture", v);
		return v;
	}

	inline function set_emissiveTexture(v:Texture):Texture {
		setTexture("emissive_texture", v);
		return v;
	}

	/** Linear rgba, glTF's factor — not an sRGB `Color`. Alpha drives Mask and Blend. **/
	public inline function setBaseColor(r:Float, g:Float, b:Float, a:Float = 1):Bool
		return setVec4("base_color", r, g, b, a);

	/** Linear rgb, and may exceed 1. **/
	public inline function setEmissive(r:Float, g:Float, b:Float):Bool
		return setVec3("emissive", r, g, b);

	// --- by name, for a custom shader's own parameters ---

	public inline function setInt(name:String, value:Int):Bool
		return Raw.wgr_material_set_int(this, name, value);

	public inline function setFloat(name:String, value:Float):Bool
		return Raw.wgr_material_set_float(this, name, value);

	public inline function setVec2(name:String, x:Float, y:Float):Bool
		return Raw.wgr_material_set_vec2(this, name, x, y);

	public inline function setVec3(name:String, x:Float, y:Float, z:Float):Bool
		return Raw.wgr_material_set_vec3(this, name, x, y, z);

	public inline function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Bool
		return Raw.wgr_material_set_vec4(this, name, x, y, z, w);

	/** An sRGB colour handle, converted to linear. **/
	public inline function setColor(name:String, color:Color):Bool
		return Raw.wgr_material_set_color(this, name, color);

	public inline function setTexture(name:String, texture:Texture):Bool
		return Raw.wgr_material_set_texture(this, name, texture);

	public inline function setTextureSampling(name:String, wrapU:TextureWrap, wrapV:TextureWrap,
			filter:TextureFilter):Bool
		return Raw.wgr_material_set_texture_sampling(this, name, wrapU, wrapV, filter);
}
