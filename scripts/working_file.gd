extends FileDialog

signal create_notif_popup(msg_text: String);
signal fill_in_details(post_info: Dictionary);
signal clear_post;

var text_to_save = "";

func startup(fill_details: Callable, clear: Callable, notif_popup: Callable):
	clear_post.connect(clear);
	fill_in_details.connect(fill_details);
	create_notif_popup.connect(notif_popup);
	
	file_selected.connect(_on_file_selected);
	
	add_filter("*.txt", "Text Files");
	current_dir = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);


func import_file():
	file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	show();


func export_file(filename: String, file_text: String):
	text_to_save = file_text;
	var download_path = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	current_path = download_path + "/" + filename + ".txt";
	file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE;
	show();


func _on_file_selected(path: String):
	if (
		FileAccess.file_exists(path) && 
		file_mode != FileDialog.FileMode.FILE_MODE_SAVE_FILE
	):
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
