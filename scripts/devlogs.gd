extends MarginContainer


@onready var menu_options = $HB/MenuOptions;

# Workspace Modules
@onready var finalize = $HB/VB/MC/Workspace/Finalize;
@onready var editor = $HB/VB/MC/Workspace/Editor;
@onready var text_preview = $HB/VB/MC/Workspace/Preview;
@onready var verify_user = $"HB/VB/MC/Workspace/Verify User";
@onready var post_list = $"HB/VB/MC/Workspace/Devlogs List";
@onready var settings = $HB/VB/MC/Workspace/Settings;
@onready var images = $HB/VB/MC/Workspace/Images;

# Import / Export
@onready var file_dialog = $FileDialog;

# Message Popup
@onready var msg_popup = $HB/VB/MC/MsgPopup;


# Temporary Variables
var creation_date = "";

# Called when the node enters the scene tree for the first time.
func _ready():
	menu_options.connect_startup.connect(_on_connect_startup);
	menu_options.startup();
	
	file_dialog.connect_startup.connect(_on_connect_startup);
	file_dialog.startup();
	
	editor.startup(update_preview);
	finalize.startup(_on_text_changed_preview, update_preview);
	post_list.startup([
		create_error_popup,
		create_notif_popup,
		create_popup,
		disconnect_popup,
		clear_post,
		fill_in_details
	]);
	
	settings.connect_startup.connect(_on_connect_startup);
	settings.startup();
	
	verify_user.connect_startup.connect(_on_connect_startup);
	verify_user.startup();


# ==========================
# ===== Signal Methods =====
# ==========================

func _on_post_curr_text():
	if (finalize.text_is_empty() || editor.text_is_empty()):
		create_notif_popup("You haven't completed all parts of your post yet!");
		return;
	
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup(error, AppInfo.ErrorType.ConfigError);
		return;
	
	var msg_type = "Edited" if post_list.get_edit_ref() != null else "Posted";
	
	var body = {
		"message": "%s devlog." % msg_type,
		"content": Marshalls.utf8_to_base64(text_preview.get_text()),
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	var edit_ref = post_list.get_edit_ref();
	if (edit_ref != null):
		body["sha"] = edit_ref.get_meta("sha");
	
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
	url += finalize.get_filename();
	
	error = h_client.request(url, headers, HTTPClient.METHOD_PUT, body);
	
	if (error != OK):
		create_error_popup(error, AppInfo.ErrorType.HTTPError);



func _on_text_changed_preview(_new_text: String) -> void:
	update_preview();


func _on_http_post_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	var r_msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			r_msg += "Successfully edited!";
			var info = response["content"];
			var edit_ref = post_list.get_edit_ref();
			if (edit_ref != null):
				edit_ref.set_meta("sha", info["sha"]);
				post_list.set_edit_ref(null);
				clear_post();
		HTTPClient.RESPONSE_CREATED: # new post
			r_msg += "Successfully created!";
			var info = response["content"];
			post_list.create_post_info(info["name"], info["download_url"], info["sha"]);
			post_list.update_directory_file(info["name"], "add");
			clear_post();
		_:
			r_msg += "Not implemented!";
			print(response);
	
	create_notif_popup(r_msg);


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
		AppInfo.MsgType.RequireAction
	);


func _on_serious_clear_button_pressed():
	msg_popup.exit();
	clear_post();


func clear_post():
	finalize.clear_text();
	editor.clear_text();
	text_preview.clear_text();
	
	creation_date = "";
	
	post_list.set_edit_ref(null);



func update_preview():
	text_preview.update_preview({
		"edit_date": get_curr_formatted_date(),
		"creation_date": creation_date if creation_date != "" else get_curr_formatted_date(),
		"post_title": finalize.get_post_title(),
		"post_summary": finalize.get_post_summary(),
		"post_body": editor.get_text(),
		"post_images": images.img_list
	});



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


func _on_hide_popup():
	msg_popup.exit();


func create_notif_popup(code_text: String):
	msg_popup.create_popup(
		code_text,
		{'yes': ["Ok", _on_hide_popup]},
		AppInfo.MsgType.Notification
	);


func create_error_popup(error_code: Error, error_type: AppInfo.ErrorType):
	var error_msg = "%d\n" % error_code;
	
	match error_type:
		AppInfo.ErrorType.ConfigError:
			error_msg += "Failed to load config file.";
		AppInfo.ErrorType.HTTPError:
			error_msg += "Couldn't perform HTTP request.";
	
	create_notif_popup(error_msg);


func create_popup(msg_text: String, button_info: Dictionary, msg_type: AppInfo.MsgType):
	msg_popup.create_popup(
		msg_text,
		button_info,
		msg_type
	);


func fill_in_details(post_info: Dictionary):
	creation_date = post_info["creation_date"];
	finalize.set_post_title(post_info["post_title"]);
	finalize.set_post_summary(post_info["post_summary"]);
	editor.set_text(post_info["post_body"]);
	finalize.set_filename(post_info["filename"]);
	
	update_preview();


func disconnect_popup():
	msg_popup.exit();


func _on_export_file():
	file_dialog.export_file(finalize.get_filename(), text_preview.get_text());


func _on_import_file():
	file_dialog.import_file();


func _on_import_image():
	file_dialog.import_image();


func _on_collected_img(img_data, img_name: String):
	images.save_img(img_data, img_name);






func _on_connect_startup(component: String):
	match component:
		"menu_options":
			menu_options.get_devlogs.connect(post_list._on_get_devlogs);
			menu_options.post_curr_text.connect(_on_post_curr_text);
			menu_options.clear_text.connect(_on_clear_text);
			menu_options.import_image_file.connect(_on_import_image);
			menu_options.import_file.connect(_on_import_file);
			menu_options.export_file.connect(_on_export_file);
		"file_dialog":
			file_dialog.clear_post.connect(clear_post);
			file_dialog.fill_in_details.connect(fill_in_details);
			file_dialog.create_notif_popup.connect(create_notif_popup);
			file_dialog.collected_img.connect(_on_collected_img);
		"verify_user":
			verify_user.enable_buttons.connect(_on_enable_buttons);
			verify_user.refresh_token_expired.connect(_on_token_expired.bind(true));
			verify_user.user_token_expired.connect(_on_token_expired.bind(false));
		"settings":
			settings.create_error_popup.connect(create_error_popup);
			settings.create_notif_popup.connect(create_notif_popup);
