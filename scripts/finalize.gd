extends MarginContainer

@onready var filename = $VB/FileName;
@onready var post_title = $VB/Title;
@onready var post_summary = $VB/Summary;
@onready var curr_date = $VB/Date;
@onready var add_file_name_button = $VB/AddFileName;


# =====================
# ====== Methods ======
# =====================

func startup(text_changed, update_preview):
	post_title.text_changed.connect(text_changed);
	post_summary.text_changed.connect(update_preview);
	add_file_name_button.pressed.connect(_on_add_file_name);
	
	get_curr_date();


func get_curr_date():
	var curr_time = Time.get_datetime_dict_from_system();
	curr_date.text = "Today is (%d) %s %d, %d" % [curr_time["month"], AppInfo.Month.keys()[(curr_time["month"] % 12) - 1], curr_time["day"], curr_time["year"]];


func clear_text():
	filename.text = "";
	post_title.text = "";
	post_summary.text = "";


func text_is_empty():
	return (filename.text == "" || post_title.text == "" || post_summary.text == "");

# =====================
# ====== Signals ======
# =====================

func _on_add_file_name():
	var curr_time = Time.get_datetime_dict_from_system();
	
	var named_file = "%d_" % curr_time["year"];
	if (curr_time["month"] < 10):
		named_file += "0";
		
	named_file += "%d_" % curr_time["month"];
	
	if (curr_time["day"] < 10):
		named_file += "0";
	
	named_file += "%d_" % curr_time["day"];
	
	set_filename(named_file + ".txt");


# =====================
# ====== Getters ======
# =====================

func get_filename():
	return filename.text;


func get_post_title():
	return post_title.text;


func get_post_summary():
	return post_summary.text;


# =====================
# ====== Setters ======
# =====================

func set_filename(new_text: String):
	filename.text = new_text;


func set_post_title(new_text: String):
	post_title.text = new_text;


func set_post_summary(new_text: String):
	post_summary.text = new_text;
