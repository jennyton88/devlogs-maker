extends MarginContainer

signal connect_startup(component: String);
signal clear_post;
signal fill_in_details(post_info: Dictionary);

@onready var list = $ScrollContainer/List;


var edit_button_ref = null;
var update_dir = false;

var directory = {
	"name": "directory.txt",
	"download_url": "",
	"sha": "",
	"data": "",
	"filename_to_edit": "",
	"action": "",
	"updated_data": ""
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
		get_parent().create_error_popup(error["error"], error["error_type"]);



func _on_http_get_posts_completed(result, response_code, _headers, body):
	var request = Requests.new();
	
	var error = request.process_results(result, response_code);
	if (error.has("error")):
		get_parent().create_notif_popup(error["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			for post in response:
				if (post["name"] != "directory.txt"):
					create_post_info(post["name"], post["download_url"], post["sha"]);
				else:
					update_directory_ref(post["name"], post["download_url"], post["sha"]);
		_:
			pass;
	
	var msg = request.build_notif_msg("get_devlogs", response_code, body_str);
	if (msg != ""):
		get_parent().create_notif_popup(msg);


func _on_edit_button_pressed(button: Button):
	var request = Requests.new();
	
	var error = request.create_edit_download_request(self, button);
	
	if (error.has("error")):
		get_parent().create_error_popup(error["error"], error["error_type"]);
		edit_button_ref = null;
	else:
		edit_button_ref = button;


func _on_http_download_text_completed(result, response_code, _headers, body):
	var request = Requests.new();
	
	var error = request.process_results(result, response_code);
	if (error.has("error")):
		get_parent().create_notif_popup(error["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			check_format_text(body_str);
		_:
			pass;
	
	var msg = request.build_notif_msg("get_file", response_code, body_str);
	get_parent().create_notif_popup(msg);


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
						get_parent().create_notif_popup("Not a recognizable file name!\nPlease edit a different file.");


func _on_delete_button_pressed(log_entry_delete_button: Button):
	get_parent().create_action_popup(
		"Are you sure you want to delete this post?",
		{ 'yes': "Delete Post", 'no': "Cancel" },
		_on_serious_delete_button_pressed.bind(log_entry_delete_button) 
	);


func _on_serious_delete_button_pressed(log_entry_delete_button: Button):
	var button_ref = log_entry_delete_button;
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		get_parent().create_error_popup(error, AppInfo.ErrorType.ConfigError);
		return;
	
	var body = {
		"message": "Deleted devlog.",
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"sha": button_ref.get_meta("sha"),
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	body = JSON.stringify(body);
	
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
		"Content-Type: application/json", 
		"Content-Length: " + str(body.length()),
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_delete_post_completed);
	
	var url = config.get_value("urls", "base_repo");
	url += button_ref.get_meta("name");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_DELETE, body);
	
	if (error != OK):
		get_parent().create_error_popup(error, AppInfo.ErrorType.HTTPError);
	else:
		if (edit_button_ref != null && (button_ref.get_meta("sha") == edit_button_ref.get_meta("sha"))):
			clear_post.emit();
		var deleted_filename = button_ref.get_parent().get_child(0).text; # post name is first in line
		button_ref.get_parent().queue_free(); # delete the log entry in the devlog list
		update_directory_file(deleted_filename, "delete");



func load_config_file() -> ConfigFile:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		get_parent().create_error_popup(error, AppInfo.ErrorType.ConfigError);
		return null;
	
	return config;



func failed_checks(result: int, response_code: int):
	if (result != OK):
		var error_result = "%d\nHTTP request response error.\nResult %d" % [response_code, result];
		get_parent().create_notif_popup(error_result);
		return true;


func convert_to_json(body):
	var json = JSON.new();
	json.parse(body.get_string_from_utf8());
	
	return json.get_data();


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


func _on_http_delete_post_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
		
	var response = convert_to_json(body);
	
	var r_msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			r_msg += "Successfully deleted!";
		HTTPClient.RESPONSE_NOT_FOUND:
			r_msg += "Not found!";
		HTTPClient.RESPONSE_CONFLICT:
			r_msg += "There was a conflict!";
		HTTPClient.RESPONSE_UNPROCESSABLE_ENTITY:
			r_msg += "Validation failed: %s" % [response_code, response["message"]];
		_:
			r_msg += "Not implemented!\n%s" % [response_code, response["message"]];
	
	get_parent().create_notif_popup(r_msg);


func get_edit_ref():
	return edit_button_ref;


func set_edit_ref(updated):
	edit_button_ref = updated;


func update_directory_ref(filename: String, download_url: String, sha: String):
	directory.name = filename;
	directory.download_url = download_url;
	directory.sha = sha;


func update_directory_file(filename: String, action: String):
	directory.filename_to_edit = filename;
	directory.action = action;
		
	fetch_directory_file();


func edit_directory_file():
	var request = Requests.new();
	
	var error = request.create_edit_directory_file_request(self, directory);

	if (error.has("error")):
		get_parent().create_error_popup(error["error"], error["error_type"]);



func get_directory_file():
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		get_parent().create_error_popup(error, AppInfo.ErrorType.ConfigError);
		return;
	
	update_dir = true;
	
	var app_name = config.get_value("app_info", "app_name");
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: text/plain",
		"Accept-Encoding: gzip, deflate",
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_download_text_completed);
	
	var url = directory.download_url;
	error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		get_parent().create_error_popup(error, AppInfo.ErrorType.HTTPError);


func _on_http_edit_directory_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	var r_msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			var info = response["content"];
			update_directory_ref(info["name"], info["download_url"], info["sha"]);
			clean_directory_edit();
		_:
			r_msg += "Not implemented! Failed to edit directory";
			clean_directory_edit();
			print(response);
			get_parent().create_notif_popup(r_msg);


func clean_directory_edit():
	directory.filename_to_edit = "";
	directory.action = "";


func fetch_directory_file():
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		get_parent().create_error_popup(error, AppInfo.ErrorType.ConfigError);
		return;
	
	var app_name = config.get_value("app_info", "app_name");
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_download_json_completed);
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name + "?ref=" + config.get_value("repo_info", "repo_branch_update");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		get_parent().create_error_popup(error, AppInfo.ErrorType.HTTPError);


func _on_http_download_json_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	var r_msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			var info = response;
			update_directory_ref(info["name"], info["download_url"], info["sha"]);
			get_directory_file();
		_:
			r_msg += "Not implemented!";
			print(response);
			get_parent().create_notif_popup(r_msg);
