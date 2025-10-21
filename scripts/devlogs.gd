extends MarginContainer

signal create_error_popup(error, error_type);
signal create_notif_popup(msg);
signal create_action_popup(msg, button_info, action);

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
var branch_ref: String = "";
var file_shas: Array[String] = [];
var tree_sha: String = "";
var commit_sha: String = "";

# Called when the node enters the scene tree for the first time.
func _ready():
	menu_options.connect_startup.connect(_on_connect_startup);
	menu_options.startup();
	
	file_dialog.connect_startup.connect(_on_connect_startup);
	file_dialog.startup();
	
	images.connect_startup.connect(_on_connect_startup);
	images.startup();
	
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
	
	var request = Requests.new();
	var config = request.load_config();
	
	if (!config is ConfigFile):
		workspace_container.create_error_popup(config["error"], config["error_type"]);
	
	# Start preparing the data for post/editing
	var data = {
		"action_type": "post_devlog",
		"commit_msg": "Posted devlog.",
		"files": [],
	};
	
	# Replace messages if editing a devlog
	var edit_ref = post_list.get_edit_ref();
	if (edit_ref):
		data["action_type"] = "edit_devlog";
		data["sha"] = edit_ref.get_meta("sha");
		data["commit_msg"] = "Edited devlog.";
	
	# The plain text content
	data["files"].append({
		"content": Marshalls.utf8_to_base64(text_preview.get_text()),
		"path": config.get_value("repo_info", "content_path") + finalize.get_filename(),
		"mode": "100644", # file blob
		"type": "blob",
	});
	
	# Image(s) data encoded in base64
	var imgs: Array[String] = text_preview.process_post_for_imgs(images.img_list);
	for img_path in imgs:
		var img_data = Image.new();
		img_data.load("user://assets/%s" % img_path);
		var encoded_bytes = Marshalls.raw_to_base64(img_data.save_png_to_buffer());
		data["files"].append({
			"content": encoded_bytes,
			"path": img_path, # location of file in repository
			"mode": "100644", # file blob
			"type": "blob"
		});
	
	# Get the reference to the branch the changes will be committed to
	var result = request.get_ref(self);
	if (result.has("error")):
		workspace_container.create_error_popup(result["error"], result["error_type"]);
		return;
	else:
		await result["request_signal"]; # make sure ref is collected
	
	var head_ref_sha = branch_ref;
	branch_ref = "";
	
	# Create blobs
	for file in data["files"]:
		result = await request.create_blob(self, file["content"]);
		if (result.has("error")):
			workspace_container.create_error_popup(result["error"], result["error_type"]);
			return;
		else:
			await result["request_signal"]; # wait for response to arrive
			await get_tree().create_timer(1.0).timeout; # for secondary rate limit
	
	# Add collected shas to the file data as ordered, and erase "content" entry used in blob
	for i in range(data["files"].size()):
		data["files"][i].erase("content");
		data["files"][i]["sha"] = file_shas[i];
	
	file_shas = [];
	
	result = await request.create_tree(self, head_ref_sha, data["files"]);
	if (result.has("error")):
		workspace_container.create_error_popup(result["error"], result["error_type"]);
		return;
	else:
		await result["request_signal"];
		await get_tree().create_timer(1.0).timeout; # for secondary rate limit
	
	var new_tree_sha = tree_sha;
	tree_sha = "";
	
	result = await request.create_commit(self, data["commit_msg"], [head_ref_sha], new_tree_sha);
	if (result.has("error")):
		workspace_container.create_error_popup(result["error"], result["error_type"]);
		return;
	else:
		await result["request_signal"];
		await get_tree().create_timer(1.0).timeout;
	
	var new_commit_sha = commit_sha;
	commit_sha = "";
	
	result = await request.update_ref(self, new_commit_sha);
	if (result.has("error")):
		workspace_container.create_error_popup(result["error"], result["error_type"]);
		return;


func _on_text_changed_preview(_new_text: String) -> void:
	update_preview();


func _on_http_request_completed(result, response_code, _headers, body, action):
	var request = Requests.new();
	
	var error = request.process_results(result, response_code);
	
	if (error.has("error")):
		workspace_container.create_notif_popup(error["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	match response_code:
		HTTPClient.RESPONSE_OK: # update post
			if (action == "edit_devlog"):
				var info = response["content"];
				var edit_ref = post_list.get_edit_ref();
				if (edit_ref != null):
					edit_ref.set_meta("sha", info["sha"]);
					post_list.set_edit_ref(null);
					clear_post();
			elif (action == "get_ref"):
				branch_ref = response["object"]["sha"];
			elif (action == "update_ref"):
				pass;
		HTTPClient.RESPONSE_CREATED: # new post
			if (action == "post_devlog"):
				var info = response["content"];
				post_list.create_post_info(info["name"], info["download_url"], info["sha"]);
				post_list.update_directory_file(info["name"], "add");
				clear_post();
			elif (action == "create_blob"):
				file_shas.append(response["sha"]); # only need sha of blob
			elif (action == "create_tree"):
				tree_sha = response["sha"];
			elif (action == "create_commit"):
				commit_sha = response["sha"];
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
	if (finalize.get_filename() == ""):
		workspace_container.create_notif_popup("You haven't named your file yet!");
		return;
	
	file_dialog.export_file(
		finalize.get_filename(), 
		text_preview.get_text(), 
		text_preview.process_post_for_imgs(images.img_list)
	);


func _on_import_file():
	file_dialog.import_file();


func _on_import_image():
	file_dialog.import_image();


func _on_collected_img(img_data, img_name: String, img_path: String):
	images.save_img(img_data, img_name, img_path);


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
			file_dialog.create_action_popup.connect(workspace_container.create_action_popup);
		"images":
			images.create_notif_popup.connect(workspace_container.create_notif_popup);
			images.create_action_popup.connect(workspace_container.create_action_popup);
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
