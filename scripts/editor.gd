extends MarginContainer

# =====================
# ======= Nodes =======
# =====================

@onready var text_edit = $EditText;


# =====================
# ====== Methods ======
# =====================

func startup(connect_method: Callable):
	text_edit.text_changed.connect(connect_method);


func clear_text():
	text_edit.text = "";


func text_is_empty():
	return text_edit.text == "";


# =====================
# ====== Getters ======
# =====================

func get_text():
	return text_edit.text;


# =====================
# ====== Setters ======
# =====================


func set_text(new_text: String):
	text_edit.text = new_text;
