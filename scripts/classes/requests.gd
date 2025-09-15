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
			if (msg_type == "get_devlogs"):
				msg = "";
			if (msg_type == "get_file"):
				msg = "Successfully downloaded file!";
		HTTPClient.RESPONSE_CREATED:
			if (msg_type == "post"):
				msg += "Successfully created devlog!";
		HTTPClient.RESPONSE_FOUND:
			msg += "Found, but temporarily redirected\n%s" % body;
		HTTPClient.RESPONSE_NOT_MODIFIED:
			msg += "Nothing changed\n%s" % body;
		HTTPClient.RESPONSE_NOT_FOUND:
			msg += "Not Found!\n%s" % body;
		HTTPClient.RESPONSE_CONFLICT:
			msg += "Conflict!\n%s" % body;
		HTTPClient.RESPONSE_FORBIDDEN:
			msg += "You don't have access to that!\n%s" % body;
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


func create_get_devlogs_headers(config: ConfigFile):
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	return [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
	];


func create_get_devlogs_queries(config: ConfigFile):
	return HTTPClient.new().query_string_from_dict({ 
		"ref": config.get_value("repo_info", "repo_branch_update"),
	});


func make_get_devlogs_request(scene: Node, headers: Array, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_get_posts_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_get_devlogs_request(scene: Node):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var headers = create_get_devlogs_headers(config);
	var queries = create_get_devlogs_queries(config);
	
	var url = config.get_value("urls", "base_repo");
	# TODO url stripping depending on type of content path
	url = url.rstrip("/") + "?"; # [/text_files/ vs /text_files] redirected to main branch
	url += queries;
	
	return make_get_devlogs_request(scene, headers, url);


func create_get_file_headers(config: ConfigFile):
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	return [
		"User-Agent: " + app_name,
		"Accept: text/plain",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
	];


func make_download_file_request(scene: Node, headers: Array, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_download_text_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_edit_download_request(scene: Node, button: Button):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var headers = create_get_file_headers(config);
	var url = button.get_meta("url");
	
	return make_download_file_request(scene, headers, url);


func create_edit_directory_body(config: ConfigFile, directory):
	var body = {
		"message": "Edited directory.",
		"content": Marshalls.utf8_to_base64(directory.data),
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update"),
		"sha": directory.sha
	};
	
	return JSON.stringify(body);


func create_edit_directory_headers(config: ConfigFile, body_length: String):
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	return [
		"User-Agent: " + app_name,
		"Accept: application/vnd.github+json",
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
		"Content-Type: application/json", 
		"Content-Length: " + body_length,
	];


func make_edit_directory_file_request(scene: Node, headers: Array, body: String, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_edit_directory_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_PUT, body);

	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_edit_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var body_str = create_edit_directory_body(config, directory);
	var headers = create_edit_directory_headers(config, str(body_str.length()));
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name;
	
	return make_edit_directory_file_request(scene, headers, body_str, url);
