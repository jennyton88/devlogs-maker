extends MarginContainer

signal connect_startup(component: String);
signal clear_post;
signal fill_in_details(post_info: Dictionary);

signal create_error_popup(error, error_type);
signal create_notif_popup(msg);
signal create_action_popup(msg, button_info, action);

@onready var list = $ScrollContainer/List;

var edit_button_ref = null;
var directory = {
	"name": "directory.txt",
	"sha": "",
	"data": "",
};


func startup():
	connect_startup.emit("devlogs_list");


func create_post_info(new_file_name: String, url: String, sha: String):
	var container = HBoxContainer.new();
	var button = Button.new();
	var delete_button = Button.new();
	var a_post = Label.new();
	
	container.add_child(a_post);
	a_post.text = new_file_name;
	a_post.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	
	container.add_child(button);
	button.text = "Edit";
	button.set_meta("url", url);
	button.set_meta("sha", sha);
	button.set_meta("name", new_file_name);
	button.pressed.connect(_on_edit_button_pressed.bind(button));
	
	container.add_child(delete_button);
	delete_button.text = "Delete";
	delete_button.set_meta("name", new_file_name);
	delete_button.set_meta("sha", sha);
	delete_button.pressed.connect(_on_delete_button_pressed.bind(delete_button));
	
	list.add_child(container);


func clear_list():
	var amt_of_children = list.get_child_count();
	if (amt_of_children > 1):
		var children = list.get_children();
		for i in range(amt_of_children - 1, 0, -1):
			list.remove_child(children[i]);
			children[i].queue_free();


func _on_get_devlogs():
	clear_list();
	
	var request = Requests.new();
	var error = request.create_get_devlogs_request(self);
	
	if (error.has("error")):
		create_error_popup.emit(error["error"], error["error_type"]);


func _on_http_request_completed(result, response_code, _headers, body, action: String):
	var request = Requests.new();
	var request_result = request.process_results(result, response_code);
	if (request_result.has("error")):
		create_notif_popup.emit(request_result["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	var msg = "";
	match response_code:
		HTTPClient.RESPONSE_OK:
			match action:
				"get_directory":
					directory["data"] = Marshalls.base64_to_utf8(response["content"]);
					directory["sha"] = response["sha"];
				"get_devlogs":
					for post in response:
						if (post["name"] != "directory.txt"):
							create_post_info(post["name"], post["download_url"], post["sha"]);
						else: # remove directory, projects info from list
							pass;
				"get_file":
					check_format_text(body_str);
				"delete_devlog":
					pass;
		_:
			pass;
	
	msg = request.build_notif_msg(action, response_code, body_str);
	if (msg != ""):
		create_notif_popup.emit(msg);


func _on_edit_button_pressed(button: Button):
	var request = Requests.new();
	
	var error = request.create_edit_download_request(self, button);
	
	if (error.has("error")):
		create_error_popup.emit(error["error"], error["error_type"]);
		edit_button_ref = null;
	else:
		edit_button_ref = button;


func check_format_text(text_blob) -> void:
	if (update_dir):
		directory.data = text_blob;
		update_dir = false;
		
		var dir_data = directory.updated_data if directory.updated_data != "" else directory.data;
		
		var dir_filename = directory.filename_to_edit;
		if (dir_filename.get_extension() != ""):
			dir_filename = dir_filename.rstrip(".txt");
		
		match directory.action:
			"delete":
				var index = dir_data.find(dir_filename);
				if (index != -1):
					directory.data = dir_data.erase(index, dir_filename.length() + 1);
				
				directory.updated_data = directory.data;
				edit_directory_file();
			"add":
				directory.data = dir_filename + "\n" + dir_data;
				directory.updated_data = directory.data;
				edit_directory_file();
			_:
				pass;
	elif (edit_button_ref != null):
		if (edit_button_ref.has_meta("name")):
			var curr_filename = edit_button_ref.get_meta("name");
			var file_type = check_file_name(curr_filename);
			if (file_type != ""):
				match file_type:
					"devlog":
						var split_text = text_blob.rsplit("\n");
						
						var post_data = {
							"filename": curr_filename,
							"creation_date": split_text[1],
							"post_title": split_text[2],
							"post_summary": split_text[3]
						};
					
						var str_len = 0;
						for i in range(4):
							str_len += split_text[i].length();
					
						post_data["post_body"] = text_blob.substr(str_len + 4, -1); # 4 of \n
					
						fill_in_details.emit(post_data);
					"directory":
						pass;
					"project":
						pass;
					_:
						create_notif_popup.emit("Not a recognizable file name!\nPlease edit a different file.");


func _on_delete_button_pressed(log_entry_delete_button: Button):
	create_action_popup.emit(
		"Are you sure you want to delete this post?",
		{ 'yes': "Delete Post", 'no': "Cancel" },
		_on_serious_delete_button_pressed.bind(log_entry_delete_button) 
	);


func _on_serious_delete_button_pressed(entry_delete_button: Button):
	var request = Requests.new();
	var button_ref = entry_delete_button;
	var error = request.create_delete_file_request(self, button_ref);
	
	if (error.has('error')):
		create_error_popup.emit(error, AppInfo.ErrorType.HTTPError);
	else:
		if (edit_button_ref != null && (button_ref.get_meta("sha") == edit_button_ref.get_meta("sha"))):
			clear_post.emit();
		var deleted_filename = button_ref.get_parent().get_child(0).text; # post name is first in line
		button_ref.get_parent().queue_free(); # delete the log entry in the devlog list
		update_directory_file(deleted_filename, "delete");


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


func get_edit_ref():
	return edit_button_ref;


func set_edit_ref(updated):
	edit_button_ref = updated;


## filename: String, full name, to add/delete to the directory.
## action: String, either "add_filename" OR "delete_filename" 
func update_directory(filename: String, action: String):
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	## Get directory for editing
	var result = request.get_file(
		self, "get_directory", 
		config.get_value("repo_info", "content_path") + directory["name"]
	);
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);
		return;
	
	await result["request_signal"];
	
	var commit_data = { "sha": directory["sha"] };
	var update_content = directory["data"];
	# TODO (REDO) use updated ver. of the directory in case of getting old data
	var trimmed_filename = filename.trim_suffix("." + filename.get_extension());
	
	if (action == "add_filename"):
		update_content = trimmed_filename + "\n" + directory["data"];
		commit_data["msg"] = "Added filename to directory!";
	elif (action == "delete_filename"):
		var index = directory["data"].find(trimmed_filename);
		if (index == -1):
			return;
		update_content = directory["data"].erase(
			index, trimmed_filename.length() + 1 # include newline
		);
		commit_data["msg"] = "Deleted filename from directory!";
	
	commit_data["content"] = update_content;
	
	# Update directory with the modified content
	result = request.create_update_file(
		self, "edit_directory", 
		config.get_value("repo_info", "content_path") + directory["name"], 
		commit_data
	);
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);
		return;
