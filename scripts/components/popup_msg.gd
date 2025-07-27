extends MarginContainer

signal send_buttons(type: String, buttons: Dictionary);

var yes_callable = null;
var no_callable = null;

func create_popup(
	display_text: String, 
	button_info: Dictionary,
	type: AppInfo.MsgType,
) -> void:
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
			send_buttons.emit(type, {'yes': yes_action});
			
			yes_action.text = button_info['yes'][0];
			
			yes_action.pressed.connect(button_info['yes'][1].bind(yes_action));
			no_action.hide();
		AppInfo.MsgType.RequireAction:
			send_buttons.emit(type, {'yes': yes_action, 'no': no_action});
			
			yes_action.text = button_info['yes'][0];
			no_action.text = button_info['no'][0];
			
			yes_action.pressed.connect(button_info['yes'][1].bind(yes_action, no_action));
			no_action.pressed.connect(button_info['no'][1].bind(no_action));
			
			no_action.show();
	
	show();


func exit(button: Button, callable: Callable) -> void:
	button.disconnect("pressed", callable);
	hide();
