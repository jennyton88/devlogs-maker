extends MarginContainer


@onready var menu_options = $HBoxContainer/TextOptions;

# Other Modules
@onready var text_editor = $HBoxContainer/VB2/MC1/Workspace/Editor/EditText;
@onready var verify_user = $"HBoxContainer/VB2/MC1/Workspace/Verify User";
@onready var text_preview = $HBoxContainer/VB2/MC1/Workspace/Preview/PostPreview;
@onready var settings = $HBoxContainer/VB2/MC1/Workspace/Settings;

# Finalize
@onready var post_title = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/Title;
@onready var post_summary = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/Summary;
@onready var file_name = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/FileName;
@onready var curr_date = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/Date;
@onready var add_file_name_button = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/AddFileName;
@onready var update_preview = $HBoxContainer/VB2/MC1/Workspace/Finalize/VBoxContainer/UpdatePreview;

# Import / Export
@onready var file_dialog = $FileDialog;


# Message Popup
@onready var msg_popup = $HBoxContainer/VB2/MC1/MsgPopup;


# Post list
@onready var post_list = $"HBoxContainer/VB2/MC1/Workspace/Devlogs List/ScrollContainer/VBoxContainer";


enum MsgType {
	RequireAction,
	Notification,
}

enum ErrorType {
	ConfigError,
	HTTPError,
}


enum Month {
	January = 1,
	Feburary = 2,
	March = 3,
	April = 4,
	May = 5,
	June = 6,
	July = 7,
	August = 8,
	September = 9,
	October = 10,
	November = 11,
	December = 12,
}


# Temporary Variables
var edit_button_ref = null;

var creation_date = "";

# Called when the node enters the scene tree for the first time.
func _ready():
	menu_options.get_devlogs.connect(_on_get_devlogs);
	menu_options.post_curr_text.connect(_on_post_curr_text);
	
	menu_options.clear_text.connect(_on_clear_text);
	
	menu_options.import_file.connect(_on_import_file);
	menu_options.export_file.connect(_on_export_file);
	
	verify_user.enable_buttons.connect(_on_enable_buttons);
	verify_user.refresh_token_expired.connect(_on_token_expired.bind(true));
	verify_user.user_token_expired.connect(_on_token_expired.bind(false));
	
	post_title.text_changed.connect(_on_text_changed_preview);
	text_editor.text_changed.connect(_on_update_preview);
	post_summary.text_changed.connect(_on_update_preview);
	
	file_dialog.add_filter("*.txt", "Text Files");
	file_dialog.file_selected.connect(file_selected);
	file_dialog.current_dir = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	add_file_name_button.pressed.connect(_on_add_file_name);
	
	settings.apply.pressed.connect(settings._on_save_settings_pressed.bind(true));
	settings.cancel.pressed.connect(settings._on_save_settings_pressed.bind(false));
	
	get_curr_date();
	
	verify_user.setup_tokens();
	settings.setup_settings();


# ==========================
# ===== Signal Methods =====
# ==========================

func _on_post_curr_text():
	if (file_name.text == "" || post_title.text == "" || 
		post_summary.text == "" || text_editor.text == ""):
		create_notif_popup("You haven't completed all parts of your post yet!");
		return;
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup(error, ErrorType.ConfigError);
		return;
	
	var msg_type = "Edited" if edit_button_ref != null else "Posted";
	
	var body = {
		"message": "%s devlog." % msg_type,
		"content": Marshalls.utf8_to_base64(text_preview.text),
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	if (edit_button_ref != null):
		body["sha"] = edit_button_ref.get_meta("sha");
	
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
	h_client.request_completed.connect(_on_http_post_completed);
	
	var url = config.get_value("urls", "base_repo");
	url += file_name.text;
	
	error = h_client.request(url, headers, HTTPClient.METHOD_PUT, body);
	
	if (error != OK):
		create_error_popup(error, ErrorType.HTTPError);


func _on_get_devlogs():
	var amt_of_children = post_list.get_child_count();
	if (amt_of_children > 1):
		var children = post_list.get_children();
		for i in range(amt_of_children - 1, 0, -1):
			post_list.remove_child(children[i]);
			children[i].queue_free();
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup(error, ErrorType.ConfigError);
		return;
	
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	var fields = { 
		"ref": config.get_value("repo_info", "repo_branch_update"),
	};
	
	var queries = create_query_string_from_dict(fields);
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_get_posts_completed);
	
	var url = config.get_value("urls", "base_repo");
	# TODO url stripping depending on type of content path
	url = url.rstrip("/") + "?"; # [/text_files/ vs /text_files] redirected to main branch
	url += queries;
	
	error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		create_error_popup(error, ErrorType.HTTPError);


func _on_edit_button_pressed(button):
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup(error, ErrorType.ConfigError);
		return;
	
	edit_button_ref = button;
	
	var app_name = config.get_value("app_info", "app_name");
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: text/plain",
		"Accept-Encoding: gzip, deflate",
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_download_text_completed);
	
	var url = button.get_meta("url");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		create_error_popup(error, ErrorType.HTTPError);
		edit_button_ref = null;


func _on_delete_button_pressed(log_entry_delete_button: Button):
	msg_popup.create_popup(
		"Are you sure you want to delete this post?",
		{'yes': ["Delete Post", _on_serious_delete_button_pressed.bind(log_entry_delete_button)], 'no': ["Cancel", _on_hide_popup]},
		MsgType.RequireAction
	);





func _on_serious_delete_button_pressed(yes_button, no_button, log_entry_delete_button):
	var button_ref = log_entry_delete_button;
	
	msg_popup.exit(yes_button, _on_serious_delete_button_pressed);
	msg_popup.exit(no_button, _on_hide_popup);
	return;
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup(error, ErrorType.ConfigError);
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
		create_error_popup(error, ErrorType.HTTPError);
	else:
		button_ref.get_parent().queue_free(); # delete the log entry in the devlog list
		text_editor.text = ""; # TODO Check this
		edit_button_ref = null;


func _on_import_file():	
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	file_dialog.show();


func _on_export_file():
	var download_path = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	file_dialog.current_path = download_path + "/" + file_name.text + ".txt";
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE;
	file_dialog.show();


func _on_text_changed_preview(_new_text: String) -> void:
	_on_update_preview();


func _on_http_post_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	var r_msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			r_msg += "Successfully edited!";
			var info = response["content"];
			if (edit_button_ref != null):
				edit_button_ref.set_meta("sha", info["sha"]);
				edit_button_ref = null;
				clear_post();
		HTTPClient.RESPONSE_CREATED: # new post
			r_msg += "Successfully created!";
			var info = response["content"];
			create_post_info(info["name"], info["download_url"], info["sha"]);
			clear_post();
		_:
			r_msg += "Not implemented!";
			print(response);
	
	create_notif_popup(r_msg);


func _on_http_get_posts_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			for post in response:
				create_post_info(post["name"], post["download_url"], post["sha"]);
		_:
			create_notif_popup("%d\nNot implemented!" % response_code);
			print(response);


func _on_http_download_text_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			var downloaded_text = body.get_string_from_utf8();
			check_format_text(downloaded_text);
		_:
			create_notif_popup("%d\nNot implemented!" % response_code);
			
			print(body.get_string_from_utf8());


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
	
	create_notif_popup(r_msg);


func file_selected(path: String):
	if (FileAccess.file_exists(path) && file_dialog.file_mode != FileDialog.FileMode.FILE_MODE_SAVE_FILE):
		clear_post();
		
		file_name.text = path.get_file();
		
		var txt_file = FileAccess.open(path, FileAccess.READ_WRITE);
		txt_file.get_line(); # ignore first line, date edited
		
		var curr_str = txt_file.get_line();
		creation_date = curr_str.substr(0, curr_str.length());
		
		curr_str = txt_file.get_line();
		post_title.text = curr_str.substr(0, curr_str.length());
		
		curr_str = txt_file.get_line();
		post_summary.text = curr_str.substr(0, curr_str.length());
		
		var text = "";
		while txt_file.get_position() < txt_file.get_length():
			text += txt_file.get_line() + "\n";
		
		text_editor.text = text;
		
		_on_update_preview();
	else:
		var txt_file = FileAccess.open(path, FileAccess.WRITE);
		txt_file.store_string(text_preview.text);


func _on_add_file_name():
	var curr_time = Time.get_datetime_dict_from_system();
	
	var named_file = "%d_" % curr_time["year"];
	if (curr_time["month"] < 10):
		named_file += "0";
		
	named_file += "%d_" % curr_time["month"];
	
	if (curr_time["day"] < 10):
		named_file += "0";
	
	named_file += "%d_" % curr_time["day"];
	
	file_name.text = named_file + ".txt";


func _on_enable_buttons():
	menu_options.post.disabled = false;
	menu_options.get_posts.disabled = false;


func _on_token_expired(refresh_token: bool):
	menu_options.post.disabled = true;
	menu_options.get_posts.disabled = true;
	
	if (refresh_token):
		create_notif_popup("Update your refresh token please! (Steps 1,2,3)");
	else:
		create_notif_popup("Update your user token please! (Step 4)");


func _on_clear_text():
	msg_popup.create_popup(
		"Are you sure you want to clear EVERYTHING for this post?\n(Text, title, summary, post, file name, etc.)",
		{'yes': ["Clear All", _on_serious_clear_button_pressed], 'no': ["Cancel", _on_hide_popup]},
		MsgType.RequireAction
	);


func _on_serious_clear_button_pressed(yes_button: Button, no_button: Button):
	clear_post();
	msg_popup.exit(yes_button, _on_serious_clear_button_pressed);
	msg_popup.exit(no_button, _on_hide_popup);


func clear_post():
	text_editor.text = "";
	
	file_name.text = "";
	post_title.text = "";
	post_summary.text = "";
	
	text_preview.text = "";
	
	creation_date = "";
	
	edit_button_ref = null;



func _on_update_preview():
	text_preview.text = "";
	
	# edit date
	text_preview.text += get_curr_formatted_date() + "\n";
	
	# first created
	if (creation_date != ""):
		text_preview.text += creation_date + "\n"; 
	else:
		text_preview.text += get_curr_formatted_date() + "\n";
	
	text_preview.text += post_title.text + "\n";
	text_preview.text += post_summary.text + "\n";
	
	text_preview.text += text_editor.text;



# ============================
# ===== Helper Functions =====
# ============================


func failed_checks(result: int, response_code: int):
	if (result != OK):
		var error_result = "%d\nHTTP request response error.\nResult %d" % [response_code, result];
		create_notif_popup(error_result);
		return true;


func convert_to_json(body):
	var json = JSON.new();
	json.parse(body.get_string_from_utf8());
	
	return json.get_data();


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
	
	post_list.add_child(container);


func get_curr_date():
	var curr_time = Time.get_datetime_dict_from_system();
	curr_date.text = "Today is (%d) %s %d, %d" % [curr_time["month"], Month.keys()[(curr_time["month"] % 12) - 1], curr_time["day"], curr_time["year"]];


func get_curr_formatted_date():
	var curr_time = Time.get_datetime_dict_from_system();
	
	var formatted_date = "%d." % curr_time["year"];
	if (curr_time["month"] < 10):
		formatted_date += "0";
		
	formatted_date += "%d." % curr_time["month"];
	
	if (curr_time["day"] < 10):
		formatted_date += "0";
	
	formatted_date += "%d" % curr_time["day"];
	
	return formatted_date;


## Creating query strings is provided in HTTPClient, not HTTPRequest, so implemented here!
## Simplistic version
func create_query_string_from_dict(fields: Dictionary) -> String:
	var query_string = "";
	var field_counter = 0;
	for key in fields:
		var value = fields[key];
		
		if (value == null):
			query_string += str(key);
		elif (typeof(value) == TYPE_ARRAY):
			var counter = 0;
			for item in value:
				query_string += str(key) + "=" + str(item);
				if (counter != value.size() - 1):
					query_string += "&";
				counter += 1;
		else:
			query_string += str(key) + "=" + str(value);
		
		if (field_counter != fields.size() - 1):
			query_string += "&";
		field_counter += 1;
	
	return query_string;


func check_format_text(text_blob) -> void:
	if (edit_button_ref != null):
		if (edit_button_ref.has_meta("name")):
			var curr_file_name = edit_button_ref.get_meta("name");
			var file_type = check_file_name(curr_file_name);

			if (file_type != ""):
				match file_type:
					"devlog":
						var split_text = text_blob.rsplit("\n");
				
						creation_date = split_text[1];
						post_title.text = split_text[2];
						post_summary.text = split_text[3];
					
						var str_len = 0;
						for i in range(4):
							str_len += split_text[i].length();
					
						text_editor.text = text_blob.substr(str_len + 4, -1); # 4 of \n
						file_name.text = curr_file_name;
					
						_on_update_preview();
					"directory":
						print("directory")
						pass;
					"project":
						print("project")
						pass;
					_:
						create_notif_popup("Not a recognizable file name!\nPlease edit a different file.");


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


func _on_hide_popup(button: Button):
	msg_popup.exit(button, _on_hide_popup);


func create_notif_popup(code_text: String):
	msg_popup.create_popup(
		code_text,
		{'yes': ["Ok", _on_hide_popup]},
		MsgType.Notification
	);


func create_error_popup(error_code: Error, error_type: ErrorType):
	var error_msg = "%d\n" % error_code;
	
	match error_type:
		ErrorType.ConfigError:
			error_msg += "Failed to load config file.";
		ErrorType.HTTPError:
			error_msg += "Couldn't perform HTTP request.";
	
	create_notif_popup(error_msg);
