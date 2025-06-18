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


# Popups
@onready var error_popup = $HBoxContainer/VB2/MC1/ErrorPopup;
@onready var error_msg = $HBoxContainer/VB2/MC1/ErrorPopup/S7/VBC2/Message;
@onready var error_button = $HBoxContainer/VB2/MC1/ErrorPopup/S7/VBC2/Ok;

@onready var delete_msg = $HBoxContainer/VB2/MC1/DeletePopup/S7/VBC2/Message;
@onready var delete_popup = $HBoxContainer/VB2/MC1/DeletePopup;
@onready var delete_yes_button = $HBoxContainer/VB2/MC1/DeletePopup/S7/VBC2/HBoxContainer/Yes;
@onready var delete_no_button = $HBoxContainer/VB2/MC1/DeletePopup/S7/VBC2/HBoxContainer/No;

@onready var clear_yes_button = $HBoxContainer/VB2/MC1/DeletePopup/S7/VBC2/HBoxContainer/ClearTextYes;

# Post list
@onready var post_list = $"HBoxContainer/VB2/MC1/Workspace/Devlogs List/VBoxContainer";



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
var edit_post_info = null;
var creation_date = "";

# Called when the node enters the scene tree for the first time.
func _ready():
	menu_options.get_devlogs.connect(_on_get_devlogs);
	menu_options.edit_curr_text.connect(_on_post_curr_text.bind(true));
	menu_options.post_curr_text.connect(_on_post_curr_text.bind(false));
	
	menu_options.clear_text.connect(_on_clear_text);
	
	menu_options.import_file.connect(_on_import_file);
	menu_options.export_file.connect(_on_export_file);
	
	verify_user.enable_buttons.connect(_on_enable_buttons);
	verify_user.refresh_token_expired.connect(_on_token_expired.bind(true));
	verify_user.user_token_expired.connect(_on_token_expired.bind(false));
	
	
	error_button.pressed.connect(_on_error_button_pressed);
	
	delete_no_button.pressed.connect(_on_delete_no_button_pressed);
	clear_yes_button.pressed.connect(_on_serious_clear_button_pressed);
	
	file_dialog.add_filter("*.txt", "Text Files");
	file_dialog.file_selected.connect(file_selected);
	file_dialog.current_dir = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	add_file_name_button.pressed.connect(_on_add_file_name);
	
	update_preview.pressed.connect(_on_update_preview);
	
		
	settings.apply.pressed.connect(settings._on_save_settings_pressed.bind(true));
	settings.cancel.pressed.connect(settings._on_save_settings_pressed.bind(false));
	
	get_curr_date();
	
	verify_user.setup_tokens();
	settings.setup_settings();


# ==========================
# ===== Signal Methods =====
# ==========================


func _on_error_button_pressed():
	error_popup.hide();


func _on_post_curr_text(edit: bool):
	if (file_name.text == "" || post_title.text == "" || post_summary.text == "" || text_editor.text == ""):
		set_error("You haven't completed all parts of your post yet!");
		return;
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	var base64_txt = Marshalls.utf8_to_base64(text_preview.text);
	
	var message_type = "Edited" if edit else "Posted";
	var message = "%s devlog." % message_type;
	
	var body = {
		"message": message,
		"content": base64_txt,
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	if (edit):
		body["sha"] = text_editor.get_meta("sha");
	
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
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);


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
		set_error("%d ERROR\nFailed to load config file." % error);
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
	url = url.rstrip("/") + "?"; # [/textfiles/ vs /textfiles] redirected to main branch
	url += queries;
	
	error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);


func _on_edit_button_pressed(button):
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	edit_post_info = button;
	
	file_name.text = button.get_meta("name");
	text_editor.set_meta("sha", button.get_meta("sha"));
	
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
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);
		edit_post_info = null;


func _on_delete_button_pressed(button):
	delete_msg.text = "Are you sure you want to delete this post?";
	
	if (delete_yes_button.pressed.is_connected(_on_serious_delete_button_pressed)):
		delete_yes_button.pressed.disconnect(_on_serious_delete_button_pressed);
	
	delete_yes_button.pressed.connect(_on_serious_delete_button_pressed.bind(button));
	clear_yes_button.hide();
	delete_yes_button.show();
	delete_popup.show();


func _on_serious_delete_button_pressed(button):
	delete_yes_button.hide();
	delete_popup.hide();
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	var body = {
		"message": "Deleted devlog.",
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"sha": button.get_meta("sha"),
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
	url += button.get_meta("name");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_DELETE, body);
	
	if (error != OK):
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);
	else:
		button.get_parent().queue_free();
		text_editor.text = "";
		text_editor.remove_meta("sha");


func _on_delete_no_button_pressed():
	delete_popup.hide();


func _on_import_file():	
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	file_dialog.show();


func _on_export_file():
	var download_path = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	file_dialog.current_path = download_path + "/" + file_name.text + ".txt";
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE;
	file_dialog.show();


func _on_http_post_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			set_error("%d\nSuccess!" % response_code);
			
			var info = response["content"];
			edit_post_info.set_meta("sha", info["sha"]);
			edit_post_info = null;
			
			text_editor.remove_meta("sha");
			
		HTTPClient.RESPONSE_CREATED: # new post
			set_error("%d\nSuccessfully created!" % response_code);
			var info = response["content"];
			create_post_info(info["name"], info["download_url"], info["sha"]); 
		_:
			set_error("%d\nNot implemented!" % response_code);
			print(response);


func _on_http_get_posts_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			for post in response:
				create_post_info(post["name"], post["download_url"], post["sha"]);
		_:
			set_error("%d\nNot implemented!" % response_code);
			print(response);


func _on_http_download_text_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			var text = body.get_string_from_utf8();
			var split_text = text.rsplit("\n");
			if (split_text.size() > 3): # TODO Fix better checks please for formatted code
				creation_date = split_text[1].rstrip(";");
				post_title.text = split_text[2].rstrip(";");
				post_summary.text = split_text[3].rstrip(";");
				
				var str_len = 0;
				for i in range(4):
					str_len += split_text[i].length();
			
				text_editor.text = text.substr(str_len + 4, -1); # 4 is for the ;'s and \n counted
			else:
				set_error("Not formatted correctly! Please edit a different file.");
		_:
			set_error("%d\nNot implemented!" % response_code);
			print(body.get_string_from_utf8());


func _on_http_delete_post_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
		
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			set_error("%d\nSuccessfully deleted!" % response_code);
		HTTPClient.RESPONSE_NOT_FOUND:
			set_error("%d\nNot found!" % response_code);
		HTTPClient.RESPONSE_CONFLICT:
			set_error("%d\nThere was a conflict!" % response_code);
		HTTPClient.RESPONSE_UNPROCESSABLE_ENTITY:
			set_error("%d\n Validation failed: %s" % [response_code, response["message"]]);
		_:
			set_error("%d\nNot implemented!\n%s" % [response_code, response["message"]]);
			print(response);


func file_selected(path: String):
	if (FileAccess.file_exists(path) && file_dialog.file_mode != FileDialog.FileMode.FILE_MODE_SAVE_FILE):
		_on_serious_clear_button_pressed();
		
		file_name.text = path.get_file();
		
		var txt_file = FileAccess.open(path, FileAccess.READ_WRITE);
		txt_file.get_line(); # ignore first line, date edited
		
		var curr_str = txt_file.get_line();
		creation_date = curr_str.substr(0, curr_str.length() - 1);
		
		curr_str = txt_file.get_line();
		post_title.text = curr_str.substr(0, curr_str.length() - 1);
		
		curr_str = txt_file.get_line();
		post_summary.text = curr_str.substr(0, curr_str.length() - 1);
		
		var text = "";
		while txt_file.get_position() < txt_file.get_length():
			text += txt_file.get_line() + "\n";
		
		text_editor.text = text;
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
	menu_options.edit_post.disabled = false;
	menu_options.post.disabled = false;
	menu_options.get_posts.disabled = false;


func _on_token_expired(refresh_token: bool):
	menu_options.edit_post.disabled = true;
	menu_options.post.disabled = true;
	menu_options.get_posts.disabled = true;
	
	if (refresh_token):
		set_error("Update your refresh token please! (Step 1,2,3)");
	else:
		set_error("Update your user token please! (Step 4)");


func _on_clear_text():
	delete_yes_button.hide();
	clear_yes_button.show();
	
	delete_msg.text = "Are you sure you want to clear this post? (Content, Title, Name, Summary)";
	delete_popup.show();


func _on_serious_clear_button_pressed():
	clear_yes_button.hide();
	delete_popup.hide();
	
	text_editor.text = "";
	
	file_name.text = "";
	post_title.text = "";
	post_summary.text = "";
	
	text_preview.text = "";
	
	creation_date = "";
	
	if (text_editor.has_meta("sha")):
		text_editor.remove_meta("sha");


func _on_update_preview(): # TODO automatically format as you type please
	text_preview.text = "";
	
	# edit date
	text_preview.text += get_curr_formatted_date() + ";\n";
	
	# first created
	if (creation_date != ""):
		text_preview.text += creation_date + ";\n"; 
	else:
		text_preview.text += get_curr_formatted_date() + ";\n";
	
	text_preview.text += post_title.text + ";\n";
	text_preview.text += post_summary.text + ";\n";
	text_preview.text += text_editor.text;



# ============================
# ===== Helper Functions =====
# ============================


## For error popup
func set_error(error_text: String) -> void:
	error_msg.text = error_text;
	error_popup.show();


func failed_checks(result: int, response_code: int):
	if (result != OK):
		var error_result = "%d ERROR\nHTTP request response error.\nResult %d" % [response_code, result];
		set_error(error_result);
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
