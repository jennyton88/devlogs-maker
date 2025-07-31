extends MarginContainer

@onready var text_edit = $EditText;


func startup(connect_method: Callable):
	text_edit.text_changed.connect(connect_method);


func text_is_empty():
	return text_edit.text == "";


func set_text(new_text: String):
	text_edit.text = new_text;


func get_text():
	return text_edit.text;


func clear_text():
	text_edit.text = "";
