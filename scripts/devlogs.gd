extends MarginContainer


@onready var menu_options = $HB/MenuOptions;

# Locations
@onready var workspace_container = $HB/VB/Workspace;

# Workspace Modules
@onready var finalize = $HB/VB/Workspace/Modules/Finalize;
@onready var editor = $HB/VB/Workspace/Modules/Editor;
@onready var text_preview = $HB/VB/Workspace/Modules/Preview;
@onready var verify_user = $"HB/VB/Workspace/Modules/Verify User";
@onready var post_list = $"HB/VB/Workspace/Modules/Devlogs List";
@onready var settings = $HB/VB/Workspace/Modules/Settings;
@onready var images = $HB/VB/Workspace/Modules/Images;

# Import / Export
@onready var file_dialog = $HB/VB/Workspace/FileDialog;


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
	
	post_list.connect_startup.connect(_on_connect_startup);
	post_list.startup();
	
	settings.connect_startup.connect(_on_connect_startup);
	settings.startup();
	
	verify_user.connect_startup.connect(_on_connect_startup);
	verify_user.startup();


# ==========================
# ===== Signal Methods =====
# ==========================

func _on_post_curr_text():
	if (finalize.text_is_empty() || editor.text_is_empty()):
		workspace_container.create_notif_popup("You haven't completed all parts of your post yet!");
		return;
	
	var post_request = Requests.new();
	
	var error = post_request.create_post_request(
		self, 
		post_list.get_edit_ref(), 
		text_preview.get_text(),
		finalize.get_filename()
	);
	
	if (error.has("error")):
		workspace_container.create_error_popup(error["error"], error["error_type"]);


func _on_text_changed_preview(_new_text: String) -> void:
	update_preview();


func _on_http_request_completed(result, response_code, _headers, body, _action):
	var request = Requests.new();
	
	var error = request.process_results(result, response_code);
	
	if (error.has("error")):
		workspace_container.create_notif_popup(error["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			var info = response["content"];
			var edit_ref = post_list.get_edit_ref();
			if (edit_ref != null):
				edit_ref.set_meta("sha", info["sha"]);
				post_list.set_edit_ref(null);
				clear_post();
		HTTPClient.RESPONSE_CREATED: # new post
			var info = response["content"];
			post_list.create_post_info(info["name"], info["download_url"], info["sha"]);
			post_list.update_directory_file(info["name"], "add");
			clear_post();
		_:
			pass;
		
	var msg = request.build_notif_msg("post", response_code, body_str);
	workspace_container.create_notif_popup(msg);


func _on_enable_buttons():
	menu_options.post.disabled = false;
	menu_options.get_posts.disabled = false;


func _on_token_expired(refresh_token: bool):
	menu_options.post.disabled = true;
	menu_options.get_posts.disabled = true;
	
	if (refresh_token):
		workspace_container.create_notif_popup("Update your refresh token please! (Steps 1,2,3)");
	else:
		workspace_container.create_notif_popup("Update your user token please! (Step 4)");


func _on_clear_text():
	workspace_container.create_action_popup(
		"Are you sure you want to clear EVERYTHING in this post?\n(Text, title, summary, post, file name, etc.)",
		{ 'yes': "Clear All", 'no': 'Cancel' },
		clear_post,
	);


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


func fill_in_details(post_info: Dictionary):
	creation_date = post_info["creation_date"];
	finalize.set_post_title(post_info["post_title"]);
	finalize.set_post_summary(post_info["post_summary"]);
	editor.set_text(post_info["post_body"]);
	finalize.set_filename(post_info["filename"]);
	
	update_preview();


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
			file_dialog.collected_img.connect(_on_collected_img);
			file_dialog.create_notif_popup.connect(workspace_container.create_notif_popup);
		"verify_user":
			verify_user.enable_buttons.connect(_on_enable_buttons);
			verify_user.refresh_token_expired.connect(_on_token_expired.bind(true));
			verify_user.user_token_expired.connect(_on_token_expired.bind(false));
			verify_user.create_error_popup.connect(workspace_container.create_error_popup);
			verify_user.create_notif_popup.connect(workspace_container.create_notif_popup);
		"settings":
			settings.create_error_popup.connect(workspace_container.create_error_popup);
			settings.create_notif_popup.connect(workspace_container.create_notif_popup);
		"devlogs_list":
			post_list.clear_post.connect(clear_post);
			post_list.fill_in_details.connect(fill_in_details);
			post_list.create_error_popup.connect(workspace_container.create_error_popup);
			post_list.create_notif_popup.connect(workspace_container.create_notif_popup);
			post_list.create_action_popup.connect(workspace_container.create_action_popup);
