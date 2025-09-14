extends MarginContainer

# Msg Popup
var popup_ref = "res://scenes/components/popup_msg.tscn";

func create_popup(msg: String, button_info: Dictionary, msg_type: AppInfo.MsgType):
	var popup = load(popup_ref).instantiate();
	add_child(popup);
	
	popup.create_popup(
		msg,
		button_info,
		msg_type
	);


func create_action_popup(msg: String, button_txt: Dictionary, action: Callable):
	var popup = load(popup_ref).instantiate();
	add_child(popup);
	
	popup.create_popup(
		msg,
		{
			'yes': { "text": button_txt.yes, "action":  action },
			'no': { "text": button_txt.no }
		},
		AppInfo.MsgType.RequireAction
	);


func create_notif_popup(msg: String):
	var popup = load(popup_ref).instantiate();
	add_child(popup);
	
	popup.create_popup(
		msg,
		{ 'yes': { "text": "Ok" } },
		AppInfo.MsgType.Notification
	);


func create_error_popup(error_code: Error, error_type: AppInfo.ErrorType):
	var error_msg = "%d\n" % error_code;
	
	match error_type:
		AppInfo.ErrorType.ConfigError:
			error_msg += "Failed to load config file.";
		AppInfo.ErrorType.HTTPError:
			error_msg += "Couldn't perform HTTP request.";
	
	create_notif_popup(error_msg);
