extends MarginContainer

# Text fields
@onready var repo_owner = $VB/RepoOwner;
@onready var repo_name = $VB/Repo;
@onready var repo_branch = $VB/RepoBranch;

@onready var content_path = $VB/ContentPath;

@onready var author = $VB/Author;
@onready var email = $VB/Email;


# Buttons
@onready var apply = $VB/HB/Apply;
@onready var cancel = $VB/HB/Cancel;

# Error
@onready var error_popup = $ErrorPopup;
@onready var error_message = $ErrorPopup/S7/VBC2/Message;


func _ready():
	pass


func setup_settings() -> void:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	# allow user to restart setup_tokens
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	repo_owner.text = config.get_value("repo_info", "repo_owner");
	repo_name.text = config.get_value("repo_info", "repo_name");
	repo_branch.text = config.get_value("repo_info", "repo_branch_update");
	
	content_path.text = config.get_value("repo_info", "content_path");
	
	author.text = config.get_value("user_info", "user_name");
	email.text = config.get_value("user_info", "user_email");


func _on_save_settings_pressed(save_settings: bool) -> void:
	if (save_settings):
		var config = ConfigFile.new();
		var error = config.load("user://config.cfg");
		
			# allow user to restart setup_tokens
		if error != OK:
			set_error("%d ERROR\nFailed to load config file." % error);
			return;
		
		config.set_value("repo_info", "repo_owner", repo_owner.text);
		config.set_value("repo_info", "repo_name", repo_name.text);
		config.set_value("repo_info", "repo_branch_update", repo_branch.text);
		
		config.set_value("repo_info", "content_path", content_path.text);
		
		config.set_value("user_info", "user_name", author.text);
		config.set_value("user_info", "user_email", email.text);
		
		config.save("user://config.cfg");
	else:
		setup_settings();


# Helper Methods

## For error popup
func set_error(error_text: String) -> void:
	error_message.text = error_text;
	error_popup.show();
