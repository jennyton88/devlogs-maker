extends MarginContainer


func startup() -> void: 
	get_node("VB/HB/Apply").pressed.connect(_on_save_settings_pressed.bind(true));
	get_node("VB/HB/Cancel").pressed.connect(_on_save_settings_pressed.bind(false));
	
	var user_set = {
		"repo_owner": get_node("VB/HB1/VB/RepoOwner"),
		"repo_name": get_node("VB/HB1/VB2/RepoName"),
		"repo_branch": get_node("VB/RepoBranch"),
		"content_path": get_node("VB/ContentPath"),
		"author": get_node("VB/Author"),
		"email": get_node("VB/Email"),
	};
	
	setup_settings(user_set);


func setup_settings(user_set: Dictionary) -> void:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	# allow user to restart setup_tokens
	if error != OK:
		create_notif_popup("%d ERROR\nFailed to load config file." % error);
		return;
	
	user_set.repo_owner.text = config.get_value("repo_info", "repo_owner");
	user_set.repo_name.text = config.get_value("repo_info", "repo_name");
	user_set.repo_branch.text = config.get_value("repo_info", "repo_branch_update");
	
	user_set.content_path.text = config.get_value("repo_info", "content_path");
	
	user_set.author.text = config.get_value("user_info", "user_name");
	user_set.email.text = config.get_value("user_info", "user_email");


func save_settings(user_set: Dictionary) -> void:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
		
		# allow user to restart setup_tokens
	if error != OK:
		create_notif_popup("%d ERROR\nFailed to load config file." % error);
		return;
	
	config.set_value("repo_info", "repo_owner", user_set.repo_owner.text);
	config.set_value("repo_info", "repo_name", user_set.repo_name.text);
	config.set_value("repo_info", "repo_branch_update", user_set.repo_branch.text);
	
	config.set_value("repo_info", "content_path", user_set.content_path.text);
	
	var build_url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		user_set.repo_owner.text, 
		user_set.repo_name.text, 
		user_set.content_path.text
	];
	
	config.set_value("urls", "base_repo", build_url);
	
	config.set_value("user_info", "user_name", get_node("VB/Author").text);
	config.set_value("user_info", "user_email", get_node("VB/Email").text);
	
	config.save("user://config.cfg");
	
	create_notif_popup("Saved!");


func _on_save_settings_pressed(apply_changes: bool) -> void:
	var user_set = {
		"repo_owner": get_node("VB/HB1/VB/RepoOwner"),
		"repo_name": get_node("VB/HB1/VB2/RepoName"),
		"repo_branch": get_node("VB/RepoBranch"),
		"content_path": get_node("VB/ContentPath"),
		"author": get_node("VB/Author"),
		"email": get_node("VB/Email"),
	};
	
	if (apply_changes):
		save_settings(user_set);
	else: # cancel
		setup_settings(user_set);


# Popup

func create_notif_popup(code_text: String):
	get_node("PopUpMsg").create_popup(
		code_text,
		{'yes': ["Ok", _on_hide_popup]},
		AppInfo.MsgType.Notification
	);


func _on_hide_popup(button: Button) -> void:
	get_node("PopUpMsg").exit(button, _on_hide_popup);
