extends MarginContainer;

signal user_token_expired;
signal refresh_token_expired;
signal enable_buttons;


# Buttons =====
@onready var request_code = $HBC1/VBC1/ReqCode;
@onready var refresh_token = $HBC1/VBC1/RefreshToken;
@onready var refresh_app = $HBC1/VBC1/RefreshApp;
@onready var override = $HBC1/VBC1/Override;

# Labels =====
@onready var code_label = $HBC1/VBC1/Code;
@onready var expire_label = $HBC1/VBC1/Expiration;

# Error Label ==
@onready var error_popup = $ErrorPopup;
@onready var error_message = $ErrorPopup/S7/VBC2/Message;
@onready var error_button = $ErrorPopup/S7/VBC2/Ok;

# Link ======
@onready var verify_link = $HBC1/VBC1/SendToVerify;
@onready var check_access = $HBC1/VBC1/CheckAccess;

# Timer =====
@onready var expire_timer = $ExpireTimer;
var show_expire_timer = false;


# =====================
# ===== Variables =====
# =====================


var device_code = -1;


# ===================
# ===== READY =======
# ===================


# Called when the node enters the scene tree for the first time.
func _ready():
	# ===== Button signals =====
	
	refresh_token.pressed.connect(_on_refresh_token_pressed);
	refresh_app.pressed.connect(_on_refresh_app_pressed);
	error_button.pressed.connect(_on_error_button_pressed);
	override.pressed.connect(_on_override_pressed);
	
	request_code.disabled = true;
	request_code.pressed.connect(_on_request_code_pressed);
	
	# ===== Timer signals =====
	expire_timer.timeout.connect(_on_expire_timeout);


# ===================
# ===== Methods =====
# ===================


## Check for tokens and confirm their validity. Otherwise, allow new requests.
func setup_tokens():
	# load the file
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	# allow user to restart setup_tokens
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	check_access.uri = "https://github.com/settings/connections/applications/%s" % config.get_value("app_info", "app_client_id");
	
	var user_setup = config.get_value("user_setup", "does_user_need_code");
	
	# first time user / refresh token expired
	if (!user_setup):
		request_code.disabled = false;
		refresh_token.disabled = true;
	else:
		var user_token_date = config.get_value("user_info", "user_token_expiration");
		var refresh_token_date = config.get_value("user_info", "refresh_token_expiration");
		
		if (check_expiration(refresh_token_date)):
			request_code.disabled = false;
			refresh_token.disabled = true;
			refresh_token_expired.emit();
		elif (check_expiration(user_token_date)):
			refresh_token.disabled = false;
			request_code.disabled = true;
			user_token_expired.emit();
		else:
			refresh_token.disabled = true;
			request_code.disabled = true;
		
		var expiration_time = Time.get_datetime_string_from_datetime_dict(user_token_date, false);
		expire_label.text = expiration_time;


## user code to verify device, NOT user token for api requests
func generate_user_code_request():
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	var app_name = config.get_value("app_info", "app_name");
	var queries = create_query_string_from_dict({ 
		"client_id": config.get_value("app_info", "app_client_id") 
	});
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Content-Type: application/x-www-form-urlencoded", 
		"Content-Length: " + str(queries.length()),
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_req_completed);
	
	var url = config.get_value("urls", "ask_for_user_code");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_POST, queries);
	
	if (error != OK):
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);
		request_code.disabled = false;


func allow_user_to_verify(response) -> void:
	# first time setup / refresh token expired
	device_code = response["device_code"];
	code_label.text = response["user_code"];
	verify_link.uri = response["verification_uri"];
	
	expire_timer.start(response["expires_in"]);
	
	refresh_app.disabled = false;
	
	#curr_interval = response["interval"];


func poll_verification(refresh_code: bool):
	var config = ConfigFile.new();
	var error = config.load('user://config.cfg');
	
	if error != OK:
		set_error("%d ERROR\nFailed to load config file." % error);
		return;
	
	# client secret not needed since using device flow
	var fields = { 
		"client_id": config.get_value("app_info", "app_client_id"),
	};
	
	if (refresh_code):
		fields["grant_type"] = "refresh_token";
		fields["refresh_token"] = config.get_value("user_info", "refresh_token");
	else:
		fields["grant_type"] = "urn:ietf:params:oauth:grant-type:device_code";
		fields["device_code"] = device_code;
	
	var queries = create_query_string_from_dict(fields);
	
	var app_name = config.get_value("app_info", "app_name");
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Content-Type: application/x-www-form-urlencoded", 
		"Content-Length: " + str(queries.length()),
	];
	
	var h_client = HTTPRequest.new();
	add_child(h_client);
	h_client.request_completed.connect(_on_http_poll_completed);
	
	var url = config.get_value("urls", "poll_for_user_verify");
	
	error = h_client.request(url, headers, HTTPClient.METHOD_POST, queries);
	
	if (error != OK):
		set_error("%d ERROR\nCouldn't perform HTTP request." % error);
		request_code.disabled = false;


# ==========================
# ===== Signal Methods =====
# ==========================


func _on_error_button_pressed():
	error_popup.hide();


func _on_request_code_pressed():
	generate_user_code_request();


func _on_refresh_token_pressed():
	poll_verification(true);


func _on_refresh_app_pressed():
	poll_verification(false);


func _on_override_pressed():
	request_code.disabled = false;
	refresh_token.disabled = false;
	refresh_app.disabled = false;


func _on_expire_timeout() -> void:
	set_error("Code Expired!\nRequest User Code Again!");
	request_code.disabled = false;


func _on_http_req_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			allow_user_to_verify(response);
		_:
			set_error("%d Error\n Result %d" % [response_code, result]);


func _on_http_poll_completed(result, response_code, _headers, body):
	if (failed_checks(result, response_code)):
		return;
	
	var response = convert_to_json(body);
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			if (response.has("error")):
				set_error("%d Error\n %d" % [response_code, response["error"]]);
				match response["error"]:
					"slow_down":
						set_error("Don't spam, wait 5 extra seconds");
						#curr_interval += response["interval"]; # not considering closing app reseting curr_interval
					"authorization_pending":
						set_error("You haven't entered the user code yet!");
					"expired_token":
						set_error("Token expired! Request a new one!");
					"unsupported_grant_type":
						set_error("Wrong grant type!");
					"incorrect_client_credentials":
						set_error("Check your client credentials again!");
					"access_denied":
						set_error("You canceled the process! Request a new one");
					"device_flow_disabled":
						set_error("Device flow was not set up!");
					_:
						set_error("Error!" + response["error"]);
				
				#poll_timer.start(curr_interval);
				return;
			
			var config = ConfigFile.new();
			var error = config.load('user://config.cfg');
			
			if error != OK:
				set_error("%d ERROR\nFailed to load config file. Token: %s, Refresh: %s" % [error, response["access_token"], response["refresh_token"]]);
				return;
			
			config.set_value("user_info", "user_token", response["access_token"]);
			config.set_value("user_info", "user_token_expiration", create_expiration_time(get_curr_time(), response["expires_in"]));
			config.set_value("user_info", "user_token_type", response["token_type"]);
			config.set_value("user_info", "user_scope", response["scope"]);
			config.set_value("user_info", "refresh_token", response["refresh_token"]);
			config.set_value("user_info", "refresh_token_expiration", create_expiration_time(get_curr_time(), response["refresh_token_expires_in"]));
			
			config.set_value("user_setup", "does_user_need_code", 1);
			
			config.save("user://config.cfg");
			
			expire_label.text = Time.get_datetime_string_from_datetime_dict(config.get_value("user_info", "user_token_expiration"), false);
			refresh_token.disabled = true;
			
			set_error("Completed Poll Verification!");
			
			enable_buttons.emit();
		_:
			set_error("%d Error\n Result %d" % [response_code, result]);


# ============================
# ===== Helper Functions =====
# ============================


## For error popup
func set_error(error_text: String) -> void:
	error_message.text = error_text;
	error_popup.show();


func check_expiration(deadline: Dictionary) -> bool:
	var curr_time = Time.get_datetime_dict_from_system();
	
	if (curr_time["year"] > deadline["year"]): # expired
		return true;
	
	if (curr_time["year"] == deadline["year"]):
		if (curr_time["month"] > deadline["month"]): # expired
			return true;
		
		if (curr_time["month"] == deadline["month"]):
			if (curr_time["day"] > deadline["day"]): # expired
				return true;
			
			if (curr_time["day"] == deadline["day"]):
				if (curr_time["hour"] > deadline["hour"]): # expired
					return true;
				
				if (curr_time["hour"] == deadline["hour"]):
					if (curr_time["minute"] > deadline["minute"]): # expired
						return true;
					
					if (curr_time["minute"] == deadline["minute"]):
						if (curr_time["second"] >= deadline["second"]): # expired
							return true;
	
	return false;


func get_curr_time():
	return Time.get_datetime_string_from_system();


## Created token success! Create an approx. deadline for requesting [token] again
func create_expiration_time(start_time: String, deadline_time: int) -> Dictionary:
	const MINUTE = 60;
	const HOUR = 60;
	const DAY = 24;
	
	var start = Time.get_datetime_dict_from_datetime_string(start_time, false);
	
	var deadline = { 
		"year": start["year"], 
		"month": start["month"], 
		"day": start["day"], 
		"hour": start["hour"], 
		"minute": start["minute"], 
		"second": start["second"], 
	};
	
	@warning_ignore("integer_division")
	var days = deadline_time / MINUTE / HOUR / DAY;
	var days_leftover = deadline_time - days * MINUTE * HOUR * DAY; # in seconds
	
	@warning_ignore("integer_division")
	var hours = days_leftover / MINUTE / HOUR;
	var hours_leftover = days_leftover - hours * MINUTE * HOUR; # in seconds
	
	@warning_ignore("integer_division")
	var minutes = hours_leftover / MINUTE;
	var seconds = hours_leftover - minutes * MINUTE; # in seconds
	
	var next_minute = false;
	var next_hour = false;
	var next_day = false;
	
	var added_seconds = deadline["second"] + seconds;
	
	if (added_seconds >= MINUTE):
		deadline["second"] = added_seconds - MINUTE;
		next_minute = true;
	else:
		deadline["second"] += seconds;
	
	var added_minutes = deadline["minute"] + minutes;
	if (next_minute):
		added_minutes += 1;
	
	if (added_minutes >= HOUR): # wrap to next hour
		deadline["minute"] = added_minutes - HOUR;
		next_hour = true;
	else:
		deadline["minute"] += minutes;
	
	var added_hours = deadline["hour"] + hours;
	if (next_hour):
		added_hours += 1;
	
	if (added_hours >= DAY):
		deadline["hour"] = added_hours - DAY;
		next_day = true;
	else:
		deadline["hour"] += hours;
	
	
	var curr_year= deadline["year"];
	var curr_month = deadline["month"];
	var curr_day = deadline["day"];
	
	if (next_day):
		curr_day += 1; # either or is fine
		#days += 1;
	
	while (days > 0):
		var month_limit = 0;
		if (curr_month % 2 == 0): # even month
			if (curr_month == 2): # feb.
				if (curr_year % 4 == 0): # leap year # TODO consider century
					month_limit = 29;
				else:
					month_limit = 28;
			elif (curr_month == 8):
				month_limit = 31;
			else:
				month_limit = 30; # even
		else:
			month_limit = 31; # odd
		# how many days left till end of month
		var remaining_days = month_limit - curr_day; 
		if (days <= remaining_days): # within month_limit, month doesn't change
			curr_day += days;
			days -= days;
		elif (days > remaining_days): # will go into the next month
			days -= remaining_days + 1; # remove and start at next month
			curr_day = 1; # change to start of month
			if (curr_month == 12): # end of year
				curr_month = 1; # new month
				curr_year += 1; # new year
			else:
				curr_month += 1; # change month
					
	deadline["day"] = curr_day;
	deadline["month"] = curr_month;
	deadline["year"] = curr_year;
	
	return deadline;


## Creating query strings is provided in HTTPClient, not HTTPRequest, so implemented here!
## Simplistic version
func create_query_string_from_dict(fields: Dictionary) -> String:
	var query_string = "";
	var field_counter = 0;
	for key in fields:
		var value = fields[key];
		
		if (value == null):
			query_string += str(key);
		elif (typeof(value) == TYPE_ARRAY):
			var counter = 0;
			for item in value:
				query_string += str(key) + "=" + str(item);
				if (counter != value.size() - 1):
					query_string += "&";
				counter += 1;
		else:
			query_string += str(key) + "=" + str(value);
		
		if (field_counter != fields.size() - 1):
			query_string += "&";
		field_counter += 1;
	
	return query_string;


func failed_checks(result: int, response_code: int):
	if (result != OK):
		var error_result = "%d ERROR\nHTTP request response error.\nResult %d" % [response_code, result];
		set_error(error_result);
		return true;


func convert_to_json(body):
	var json = JSON.new();
	json.parse(body.get_string_from_utf8());
	
	return json.get_data();
