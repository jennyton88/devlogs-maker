extends FileDialog

signal connect_startup(component: String);
signal fill_in_details(post_info: Dictionary);
signal clear_post;
signal collected_img(img_data, img_name: String);

signal create_notif_popup(msg);

var text_to_save = "";
var curr_file_mode = "";

func startup():
	
	file_selected.connect(_on_file_selected);
	
	current_dir = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	connect_startup.emit("file_dialog");


func import_file():
	file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	curr_file_mode = "txt_file";
	clear_filters();
	add_filter("*.txt", "Text Files");
	show();


func export_file(filename: String, file_text: String):
	text_to_save = file_text;
	var download_path = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	current_path = download_path + "/" + filename + ".txt";
	file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE;
	show();


func import_image():
	file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	curr_file_mode = "img_file";
	clear_filters();
	add_filter("*.png, *.jpg", "Image Files");
	show();


func _on_file_selected(path: String):
	if (
		FileAccess.file_exists(path) && 
		file_mode != FileDialog.FileMode.FILE_MODE_SAVE_FILE
	):
		if (curr_file_mode == "txt_file"):
			var filename = path.get_file();
			
			if (check_file_name(filename) == ""):
				create_notif_popup.emit("Not a recognizable file name!\nPlease edit a different file.");
				return;
			
			clear_post.emit();
			
			var post_data = {
				"filename": filename,
			};
			
			var txt_file = FileAccess.open(path, FileAccess.READ_WRITE);
			txt_file.get_line(); # ignore first line, date edited
			
			post_data["creation_date"] = txt_file.get_line();
			post_data["post_title"] = txt_file.get_line();
			post_data["post_summary"] = txt_file.get_line();
			
			var text = "";
			while txt_file.get_position() < txt_file.get_length():
				text += txt_file.get_line() + "\n";
			
			post_data["post_body"] = text;
			
			fill_in_details.emit(post_data);
		elif (curr_file_mode == "img_file"):
			var request = Requests.new();
			var config = request.load_config();
			
			if (typeof(config) == TYPE_DICTIONARY): # error
				create_notif_popup.emit("Failed to load config file.");
				return;
			
			create_img_folder(config);
			
			var file_exts = ["jpg", "png"];
			var filename = path.get_file();
			var ext = filename.get_extension();
			
			var img_path = config.get_value("repo_info", "image_path");
			img_path = img_path.rstrip("/");
			
			for file_ext in file_exts:
				if (ext == file_ext):
					var img = Image.new();
					img.load(path);
					
					match ext:
						"jpg":
							img.save_jpg("user://assets/%s/%s" % [img_path, filename]);
						"png":
							img.save_png("user://assets/%s/%s" % [img_path, filename]);
					var tex = ImageTexture.new();
					tex.set_image(img);
					img_path = img_path.replace("public", ""); # specific to website here
					collected_img.emit(tex, img_path + "/" + filename);
					return;
	else: # export
		var txt_file = FileAccess.open(path, FileAccess.WRITE);
		txt_file.store_string(text_to_save);
		text_to_save = "";


func check_file_name(curr_file_name: String) -> String:
	var regex = RegEx.new();
	regex.compile("^(\\d{4})_(\\d{2})_(\\d{2})");
	var matches = regex.search(curr_file_name);

	if (matches):
		return "devlog";

	if (curr_file_name == "directory.txt"):
		return "directory";
	
	if (curr_file_name == "projects_info.txt"):
		return "project";
	
	return "";


func create_img_folder(config: ConfigFile):
	var dir_access = DirAccess.open("user://");
	if (!dir_access.dir_exists("assets")):
		var error = dir_access.make_dir("assets");
		if (error != OK):
			create_notif_popup.emit("Failed to create assets folder!");
	
	var img_path = config.get_value("repo_info", "image_path");
	img_path = img_path.rstrip("/");
	if (!dir_access.dir_exists("assets/%s" % img_path)):
		var error = dir_access.make_dir_recursive("assets/%s" % img_path);
		if (error != OK):
			create_notif_popup.emit("Failed to create folder(s) for image!");
	
