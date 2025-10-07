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


func get_image_texture(img_line: String, img_list):
	var img_path = img_line.get_slice("(", 1);
	var link_end = img_path.find(")");
	img_path = img_path.substr(0, link_end); # if there are additional chars at the end
	
	var imgs = img_list.get_children();
	for x in range(1, imgs.size(), 1): #ignoring title
			var img_name = imgs[x].get_meta("file_path");
			if (img_name.replace("public", "") == img_path):
				var components = imgs[x].get_child(0).get_children(); # hbox holds all
				for component in components:
					if (component is TextureRect):
						return component.texture;
	
	return null;


func clear_text():
	plain_text_post = "";
	post_preview.text = "";


# =====================
# ====== Getters ======
# =====================

func get_text():
	return post_preview.text;
