extends MarginContainer

@onready var img_list = $Scroll/VBox;


func save_img(img_data, img_name):
	img_list.add_child(build_img_part(img_data, img_name));


func build_img_part(img_data, img_name):
	var panel_cont = PanelContainer.new();
	panel_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	var bg_mat = load("res://assets/materials/image_part.tres");
	panel_cont.add_theme_stylebox_override("panel", bg_mat);
	
	var hbox = HBoxContainer.new();
	
	var thumb = TextureRect.new();
	thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL;
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED;
	thumb.custom_minimum_size = Vector2(128,128);
	
	thumb.texture = img_data;
	
	var filename = Label.new();
	filename.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	filename.text = img_name;
	
	panel_cont.add_child(hbox);
	hbox.add_child(thumb);
	hbox.add_child(filename);
	
	return panel_cont;
