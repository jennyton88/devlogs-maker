extends MarginContainer

# Text fields
@onready var repo_owner = $VB/RepoOwner;
@onready var repo_name = $VB/Repo;
@onready var repo_branch = $VB/RepoBranch;

@onready var content_path = $VB/ContentPath;

@onready var author = $VB/Author;
@onready var email = $VB/Email;


func startup() -> void: 
	get_node("VB/HB/Apply").pressed.connect(_on_save_settings_pressed.bind(true));
	get_node("VB/HB/Cancel").pressed.connect(_on_save_settings_pressed.bind(false));
	
	setup_settings();


func setup_settings() -> void:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	# allow user to restart setup_tokens
	if error != OK:
		create_notif_popup("%d ERROR\nFailed to load config file." % error);
		return;
	
	repo_owner.text = config.get_value("repo_info", "repo_owner");
	repo_name.text = config.get_value("repo_info", "repo_name");
	repo_branch.text = config.get_value("repo_info", "repo_branch_update");
	
	content_path.text = config.get_value("repo_info", "content_path");
	
	author.text = config.get_value("user_info", "user_name");
	email.text = config.get_value("user_info", "user_email");


func save_settings():
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
		
		# allow user to restart setup_tokens
	if error != OK:
		create_notif_popup("%d ERROR\nFailed to load config file." % error);
		return;
	
	config.set_value("repo_info", "repo_owner", repo_owner.text);
	config.set_value("repo_info", "repo_name", repo_name.text);
	config.set_value("repo_info", "repo_branch_update", repo_branch.text);
	
	config.set_value("repo_info", "content_path", content_path.text);
	
	var build_url = "https://api.github.com/repos/%s/%s/contents/%s" % [repo_owner.text, repo_name.text, content_path.text];
	config.set_value("urls", "base_repo", build_url);
	
	config.set_value("user_info", "user_name", author.text);
	config.set_value("user_info", "user_email", email.text);
	
	config.save("user://config.cfg");
	
	create_notif_popup("Saved!");


func _on_save_settings_pressed(apply_changes: bool) -> void:
	if (apply_changes):
		save_settings();
	else: # cancel
		setup_settings();


# Popup

func create_notif_popup(code_text: String):
	get_node("PopUpMsg").create_popup(
		code_text,
		{'yes': ["Ok", _on_hide_popup]},
		AppInfo.MsgType.Notification
	);


func _on_hide_popup(button: Button) -> void:
	get_node("PopUpMsg").exit(button, _on_hide_popup);
