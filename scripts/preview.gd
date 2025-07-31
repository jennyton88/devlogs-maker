extends MarginContainer

## Description: This module is for displaying what the post will be sent/exported as.

# =====================
# ======= Nodes =======
# =====================

@onready var post_preview = $PostPreview;


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
	text += post_data["post_body"];
	
	post_preview.text = text;


func clear_text():
	post_preview.text = "";


# =====================
# ====== Getters ======
# =====================

func get_text():
	return post_preview.text;
