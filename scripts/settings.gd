extends MarginContainer

## Description: This module is for modifying general settings, specifically
## the owner, repo name, branch, and path where the text files are stored.
## Also what name and email you will commit as.

# =====================
# ====== Signals ======
# =====================

signal connect_startup(component: String);

signal create_error_popup(error, error_type);
signal create_notif_popup(msg);

# =====================
# ====== Methods ======
# =====================

func startup() -> void: 
	get_node("VB/HB/Apply").pressed.connect(_on_save_settings_pressed.bind(true));
	get_node("VB/HB/Cancel").pressed.connect(_on_save_settings_pressed.bind(false));
	
	connect_startup.emit("settings");
	
	var user_set = get_user_input_areas();
	
	setup_settings(user_set);


func setup_settings(user_set: Dictionary) -> void:
	var config = load_config_file();
	
	if (config == null): return;
	 
	user_set.author.text = config.get_value("user_info", "user_name");
	user_set.email.text = config.get_value("user_info", "user_email");
	
	user_set.repo_owner.text = config.get_value("repo_info", "repo_owner");
	user_set.repo_name.text = config.get_value("repo_info", "repo_name");
	user_set.repo_branch.text = config.get_value("repo_info", "repo_branch_update");
	user_set.content_path.text = config.get_value("repo_info", "content_path");
	user_set.image_path.text = config.get_value("repo_info", "image_path");


func save_settings(user_set: Dictionary) -> void:
	var config = load_config_file();
	
	if (config == null): return;
	
	config.set_value("repo_info", "repo_owner", user_set.repo_owner.text);
	config.set_value("repo_info", "repo_name", user_set.repo_name.text);
	config.set_value("repo_info", "repo_branch_update", user_set.repo_branch.text);
	config.set_value("repo_info", "content_path", user_set.content_path.text);
	config.set_value("repo_info", "image_path", user_set.image_path.text);
	
	var build_file_url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		user_set.repo_owner.text, 
		user_set.repo_name.text, 
		user_set.content_path.text
	];
	
	var build_image_url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		user_set.repo_owner.text, 
		user_set.repo_name.text, 
		user_set.image_path.text
	];
	
	config.set_value("urls", "base_repo", build_file_url);
	config.set_value("urls", "base_image_repo", build_image_url);
	
	config.set_value("user_info", "user_name", get_node("VB/Author").text);
	config.set_value("user_info", "user_email", get_node("VB/Email").text);
	
	config.save("user://config.cfg");
	
	create_notif_popup.emit("Saved!");


# ============================
# ====== Signal Methods ======
# ============================

func _on_save_settings_pressed(apply_changes: bool) -> void:
	var user_set = get_user_input_areas();
	
	if (apply_changes):
		save_settings(user_set);
	else: # cancel
		setup_settings(user_set);


# =====================
# ====== Helpers ======
# =====================

func get_user_input_areas():
	return {
		"repo_owner": get_node("VB/HB1/VB/RepoOwner"),
		"repo_name": get_node("VB/HB1/VB2/RepoName"),
		"repo_branch": get_node("VB/RepoBranch"),
		"content_path": get_node("VB/HB2/VB/ContentPath"),
		"image_path": get_node("VB/HB2/VB2/ImagePath"),
		"author": get_node("VB/Author"),
		"email": get_node("VB/Email"),
	};


func load_config_file() -> ConfigFile:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup.emit(error, AppInfo.ErrorType.ConfigError);
		return null;
	
	return config;
