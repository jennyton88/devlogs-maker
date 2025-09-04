extends MarginContainer

## Description: This module is for displaying what the post will be sent/exported as.

# =====================
# ======= Nodes =======
# =====================

@onready var post_preview = $PostPreview;

# =====================
# ===== Variables =====
# =====================

var plain_text_post = "";

# =====================
# ====== Methods ======
# =====================

func update_preview(post_data: Dictionary):
	clear_text();
	
	var text = "";
	text += post_data["edit_date"] + "\n";
	text += post_data["creation_date"] + "\n";
	text += post_data["post_title"] + "\n";
	text += post_data["post_summary"] + "\n";
	
	var processed_text = text;
	processed_text += process_post(post_data["post_body"], post_data["post_images"]);
	
	text += post_data["post_body"];
	
	plain_text_post = text; # TODO needs replacement real paths to the images
	post_preview.text = processed_text;
	#post_preview.text = text;


func process_post(post_body: String, img_list):
	var post_lines = post_body.split("\n", true);
	
	var combine_lines: String = "";
	
	for x in range(0, post_lines.size(), 1):
		if (post_lines[x].begins_with("![")):
			combine_lines += attach_img(post_lines[x], img_list) + "\n";
		else:
			combine_lines += post_lines[x] + "\n";
	
	return combine_lines;


func attach_img(img_line: String, img_list):
	var img_path = img_line.get_slice("(", 1);
	img_path = img_path.rstrip(")");
	
	var imgs = img_list.get_children();
	for x in range(1, imgs.size(), 1):
		var img_name = imgs[x].get_child(0).get_child(3).text; # panel > hbox > img # TODO make this better
		if (img_name == img_path):
			img_path = "res://assets/imported_imgs/%s" % img_name;
			
			return "[center][img=128]" + "%s[/img][/center]" % img_path;
	
	return img_line;


func clear_text():
	plain_text_post = "";
	post_preview.text = "";


# =====================
# ====== Getters ======
# =====================

func get_text():
	return post_preview.text;
