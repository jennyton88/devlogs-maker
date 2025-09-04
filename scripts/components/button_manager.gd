extends VBoxContainer;


## Signals =====

signal get_devlogs;
signal post_curr_text;

signal import_image_file;
signal import_file;
signal export_file;

signal clear_text;
#signal add_template;

## Visuals =====

## Reset =====

@onready var clear_post = $ClearText;
@onready var add_post_template = $AddPostTemplate;

## Functional ======

@onready var import_image = $ImportImage;
@onready var import_text = $ImportText;
@onready var export_text = $ExportText;

## Send it ======

@onready var get_posts = $GetPosts;
@onready var post = $Post;


# Called when the node enters the scene tree for the first time.
func _ready():
	clear_post.pressed.connect(_on_clear_text_pressed);
	
	get_posts.pressed.connect(_on_get_posts_pressed);
	post.pressed.connect(_on_post_pressed);
	
	import_text.pressed.connect(_on_import_pressed);
	export_text.pressed.connect(_on_export_pressed);
	
	import_image.pressed.connect(_on_import_image_pressed);


func _on_get_posts_pressed():
	get_devlogs.emit();


func _on_post_pressed():
	post_curr_text.emit();


func _on_import_image_pressed():
	import_image_file.emit();
	

func _on_import_pressed():
	import_file.emit();


func _on_export_pressed():
	export_file.emit();


func _on_clear_text_pressed():
	clear_text.emit();
