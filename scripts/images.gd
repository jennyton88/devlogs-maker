extends MarginContainer


signal connect_startup(component: String);

signal create_notif_popup(msg);


@onready var img_list = $Scroll/VBox;

func startup():
	load_imgs();
	
	connect_startup.emit("images");

func load_imgs():
	var request = Requests.new();
	var config = request.load_config();
	
	if (typeof(config) == TYPE_DICTIONARY): # error
		create_notif_popup.emit("Failed to load config file.");
		return;
	
	var img_path =  config.get_value("repo_info", "image_path");
	img_path = img_path.rstrip("/");
	var dir_access = DirAccess.open("user://");
	
	if (!dir_access.dir_exists("assets")): # startup
		return;
	
	var path = "assets/%s" % img_path;
	if (dir_access.dir_exists(path)):
		dir_access.change_dir(path);
		var files = dir_access.get_files();
		for filename in files:
			match filename.get_extension():
				"jpg":
					load_curr_img(img_path, filename);
				"png":
					load_curr_img(img_path, filename);
				_:
					pass;


func load_curr_img(path: String, filename: String):
	var img = Image.new();
	img.load("user://assets/" + path + "/%s" % filename); # should check for errors
	var tex = ImageTexture.new();
	tex.set_image(img);
	var img_path = path.replace("public", ""); # specific to website here
	save_img(tex, img_path + "/" + filename);


func save_img(img_data, img_name):
	img_list.add_child(build_img_part(img_data, img_name));


func build_img_part(img_data, img_name):
	var panel_cont = PanelContainer.new();
	panel_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	var bg_mat = load("res://assets/materials/image_part.tres");
	panel_cont.add_theme_stylebox_override("panel", bg_mat);
	
	var hbox = HBoxContainer.new();
	
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
	
	var copy_button = Button.new();
	copy_button.text = "Copy";
	copy_button.pressed.connect(_on_copy_button_pressed.bind(copy_button));
	
	var delete_button = Button.new();
	delete_button.text = "Delete";
	delete_button.pressed.connect(_on_delete_button_pressed.bind(delete_button));
	
	panel_cont.add_child(hbox);  # TODO ENUM for each feature
	hbox.add_child(check); # 0
	hbox.add_child(thumb); # 1
	hbox.add_child(filename); # 2
	hbox.add_child(copy_button); # 3
	hbox.add_child(delete_button); # 4
	hbox.add_child(MarginContainer.new()); # 5
	
	return panel_cont;


func _on_delete_button_pressed(delete_button):
	delete_button.get_parent().queue_free();


func _on_copy_button_pressed(copy_button):
	DisplayServer.clipboard_set(copy_button.get_parent().get_child(2).text);
	
