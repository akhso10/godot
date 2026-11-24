extends Control
## Canvas authored in 1280 × 720 design units, scaled by Godot.
const PAPER = Color("#e8e5d7")
const MUTED = Color("#a8b1a7")
const RED = Color("#b74b3c")
const DARK = Color("#121915")
const SANS = preload("res://assets/ui/fonts/OpenSans-Regular.ttf")
const BOLD = preload("res://assets/ui/fonts/OpenSans-Semibold.ttf")
const TALL = preload("res://assets/ui/fonts/OpenSans-CondBold.ttf")
const SERIF = preload("res://assets/ui/fonts/DejaVuSerifCondensed.ttf")
const MENU = "res://assets/art/menu.webp"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func place(node:Control, pos:Vector2, extent:Vector2, parent:Control=null) -> Control:
	(parent if parent else self).add_child(node)
	node.position = pos
	node.size = extent
	return node

func box(pos:Vector2, extent:Vector2, color:Color, parent:Control=null) -> ColorRect:
	var rect = ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(rect,pos,extent,parent)
	return rect

func label(value:String, pos:Vector2, extent:Vector2, pt:int=18, face:Font=SANS, tint:Color=PAPER, wrap:bool=false, parent:Control=null) -> Label:
	var field = Label.new()
	field.text = value
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_theme_font_override("font",face)
	field.add_theme_font_size_override("font_size",pt)
	field.add_theme_color_override("font_color",tint)
	if wrap:
		field.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(field,pos,extent,parent)
	return field

func picture(path:String, pos:Vector2, extent:Vector2, cover:bool=true, parent:Control=null) -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		image.texture = load(path)
	place(image,pos,extent,parent)
	return image

func style(bg:Color, edge:Color, left:int=0) -> StyleBoxFlat:
	var skin = StyleBoxFlat.new()
	skin.bg_color = bg
	skin.border_color = edge
	skin.border_width_left = left
	skin.content_margin_left = 17
	skin.content_margin_right = 12
	return skin

func button(title:String,pos:Vector2,extent:Vector2,pressed:Callable,primary:bool=false,enabled:bool=true,icon_id:String="") -> Button:
	var b = Button.new()
	b.text = title
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",BOLD)
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_color_override("font_disabled_color",Color("#79837c"))
	if icon_id != "":
		b.icon = load("res://assets/ui/icons/icon_%s.svg" % icon_id)
		b.add_theme_constant_override("icon_max_width",20)
		b.add_theme_constant_override("h_separation",14)
	b.add_theme_stylebox_override("normal",style(Color("#813b31") if primary else Color(0.05,0.08,0.07,0.74),RED,3 if primary else 0))
	b.add_theme_stylebox_override("hover",style(Color("#485046"),PAPER,3))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),PAPER,3))
	b.add_theme_stylebox_override("pressed",style(RED,PAPER,3))
	b.add_theme_stylebox_override("disabled",style(Color(0.06,0.08,0.07,0.5),MUTED))
	place(b,pos,extent)
	b.pressed.connect(pressed)
	return b

func backplate(path:String=MENU,dim:float=0.0) -> void:
	picture(path, Vector2.ZERO,Vector2(1280,720))
	var layer = box(Vector2.ZERO,Vector2(1280,720),Color.WHITE)
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float dimness = 0.0;
	float hash(vec2 s){return fract(sin(dot(s,vec2(12.9898,78.233)))*43758.5453);}
	void fragment(){
		vec2 p=UV;
		float shade=.48*(1.-smoothstep(.06,.62,p.x))+.37*smoothstep(.60,1.,p.y)+.12*(1.-smoothstep(.0,.2,p.y));
		float col=floor(p.x*230.+p.y*3.);
		float streak=smoothstep(.985,1.,sin((p.x*230.+p.y*3.)*6.283))*smoothstep(.94,1.,fract(p.y*1.8+hash(vec2(col,12.))+TIME*(.6+hash(vec2(col,7.)))))*.08;
		COLOR=vec4(vec3(.025,.045,.038)+streak,max(shade,dimness));
	}"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("dimness",dim)
	layer.material = mat

func header(kicker:String,heading:String) -> void:
	box(Vector2(74,65),Vector2(33,3),RED)
	label(kicker.to_upper(),Vector2(120,51),Vector2(1080,30),14,BOLD,MUTED)
	label(heading,Vector2(72,92),Vector2(1144,83),52,SERIF)
	box(Vector2(74,193),Vector2(1130,1),Color("#51584e"))

func home(available:bool, act:Callable) -> void:
	clear()
	backplate()
	picture("res://assets/ui/crest.svg",Vector2(63,44),Vector2(48,55),false)
	label("SMA NUSA BANGSA",Vector2(125,45),Vector2(260,24),16,BOLD)
	label("J A W A   B A R A T",Vector2(126,72),Vector2(250,20),11,SANS,MUTED)
	var clock = label("23 : 47",Vector2(1034,45),Vector2(175,48),34,SERIF)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label("SEKOLAH",Vector2(67,113),Vector2(690,129),100,SERIF)
	label("S E T E L A H   T E N G A H   M A L A M",Vector2(77,244),Vector2(650,33),22,BOLD)
	box(Vector2(78,302),Vector2(43,3),RED)
	label("Bel pulang sudah berbunyi.\nTapi tidak semua murid boleh pulang.",Vector2(77,321),Vector2(500,68),20,SERIF,PAPER)
	var main_id = "continue" if available else "new"
	var second_id = "new" if available else "continue"
	button("Lanjutkan" if available else "Permainan baru",Vector2(77,418),Vector2(310,48),act.bind(main_id),true,true,"play")
	button("Permainan baru" if available else "Lanjutkan",Vector2(77,476),Vector2(310,44),act.bind(second_id),false,available,"continue")
	button("Pengaturan",Vector2(77,530),Vector2(310,44),act.bind("settings"),false,true,"settings")
	button("Panduan kontrol",Vector2(77,584),Vector2(310,44),act.bind("controls"),false,true,"keyboard")
	box(Vector2(76,654),Vector2(1128,1),Color(0.62,0.65,0.6,0.44))
	button("Kredit",Vector2(65,661),Vector2(120,42),act.bind("credits"))
	button("Keluar",Vector2(1104,661),Vector2(100,42),act.bind("quit"),false,true,"exit")
