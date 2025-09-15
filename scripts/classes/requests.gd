class_name Requests


func create_post_request(scene: Node, edit_ref: Node, content: String, filename: String):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var body = create_post_body(config, edit_ref, content);
	body = JSON.stringify(body);
	
	var headers = create_post_headers(config, str(body.length()));
	
	var url = config.get_value("urls", "base_repo");
	url += filename;
	
	return make_post_request(scene, headers, body, url);


func create_post_body(config: ConfigFile, edit_ref: Node, content: String):
	var msg = "Edited" if edit_ref != null else "Posted";
	
	var body = {
		"message": "%s devlog." % msg,
		"content": Marshalls.utf8_to_base64(content),
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	if (edit_ref != null):
		body["sha"] = edit_ref.get_meta("sha");
	
	return body;


func create_post_headers(config: ConfigFile, content_length: String):
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	return [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
		"Content-Type: application/json", 
		"Content-Length: " + content_length,
	];


func make_post_request(scene: Node, headers: Array, body: String, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_post_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_PUT, body);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};

# Helpers

func build_notif_msg(msg_type: String, response_code: int, body: String):
	var msg = "%d\n" % response_code;
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			if (msg_type == "post"):
				msg += "Successfully edited devlog!";
		HTTPClient.RESPONSE_CREATED:
			if (msg_type == "post"):
				msg += "Successfully created devlog!";
		HTTPClient.RESPONSE_NOT_FOUND:
			msg += "Not Found!\n%s" % body;
		HTTPClient.RESPONSE_CONFLICT:
			msg += "Conflict!\n%s" % body;
		HTTPClient.RESPONSE_UNPROCESSABLE_ENTITY:
			msg += "Validation failed / Spam\n%s" % body;
		_:
			msg += "Not implemented!\n%s" % body;
	
	return msg;


func process_results(result: int, response_code: int):
	if (result != OK):
		return { "error": "%d\nHTTP request response error.\nResult %d" % [response_code, result] };
	
	return {};


func convert_to_json(body: String):
	var json = JSON.new();
	json.parse(body);
	
	return json.data;


func load_config():
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		return { "error": error, "error_type": AppInfo.ErrorType.ConfigError };
	
	return { "config": config };
