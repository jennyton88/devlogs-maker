extends MarginContainer


func create_popup(display_text: String, button_info: Dictionary, type: AppInfo.MsgType):
	set_msg(display_text);
	setup_popup(type, button_info);


func set_msg(display_text: String) -> void:
	var msg = get_node("Space/VB/Message");
	msg.text = display_text;


func setup_popup(type: AppInfo.MsgType, button_info: Dictionary) -> void:
	var yes_action = get_node('Space/VB/HB/Yes');
	var no_action = get_node('Space/VB/HB/No');
	
	
	match type:
		AppInfo.MsgType.Notification:
			yes_action.text = button_info['yes']['text'];
			yes_action.pressed.connect(exit);
			#yes_action.pressed.connect(_on_yes_action.bind(button_info['yes']['action']));
			
			no_action.hide();
		AppInfo.MsgType.RequireAction:
			yes_action.text = button_info['yes']['text'];
			no_action.text = button_info['no']['text'];
			
			yes_action.pressed.connect(_on_yes_action.bind(button_info['yes']['action']));
			no_action.pressed.connect(exit);
			
			no_action.show();
	
	show();


func _on_yes_action(action: Callable):
	action.call();
	exit();


func exit() -> void:
	hide();
	queue_free();
