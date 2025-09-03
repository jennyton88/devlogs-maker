extends MarginContainer

@onready var img_list = $Scroll/VBox;

var curr_img_num = 0;

func save_img(img_data, img_name):
	img_list.add_child(build_img_part(img_data, img_name));
	
	curr_img_num += 1;


func build_img_part(img_data, img_name):
	var panel_cont = PanelContainer.new();
	panel_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	var bg_mat = load("res://assets/materials/image_part.tres");
	panel_cont.add_theme_stylebox_override("panel", bg_mat);
	
	var hbox = HBoxContainer.new();
	
	var num_label = Label.new();
	num_label.text = "%d" % curr_img_num;
	
	var check = CheckBox.new();
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER;
	
	var thumb = TextureRect.new();
	thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL;
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED;
	thumb.custom_minimum_size = Vector2(128,128);
	
	thumb.texture = img_data;
	
	var filename = Label.new();
	filename.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	filename.text = img_name;
	
	var delete_button = Button.new();
	delete_button.text = "Delete";
	delete_button.pressed.connect(_on_delete_button_pressed.bind(delete_button));
	
	panel_cont.add_child(hbox);
	hbox.add_child(num_label);
	hbox.add_child(check);
	hbox.add_child(thumb);
	hbox.add_child(filename);
	hbox.add_child(delete_button);
	hbox.add_child(MarginContainer.new());
	
	return panel_cont;


func _on_delete_button_pressed(delete_button):
	delete_button.get_parent().queue_free();
