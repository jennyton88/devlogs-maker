class_name Requests


enum RequestType {
	SendData,
	GetData
}

enum AcceptType {
	Text,
	GitJSON
}


func create_post_request(scene: Node, edit_ref: Node, content: String, filename: String):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var addt_data = { "content": content };
	var msg = "Posted";
	
	if (edit_ref != null):
		addt_data["sha"] = edit_ref.get_meta("sha");
		msg = "Edited";
	
	msg += " devlog.";
	
	var body = create_body(config, msg, addt_data);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += filename;
	
	return make_post_request(scene, headers, body, url);


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
		HTTPClient.RESPONSE_OK: # 200
			match msg_type:
				"post":
					msg += "Successfully edited devlog!";
				"get_devlogs":
					msg = "";
				"get_file":
					msg = "Successfully downloaded file!";
				"edit_dir":
					msg = "";
				"delete_file":
					msg = "Successfully deleted!";
		HTTPClient.RESPONSE_CREATED: # 201
			if (msg_type == "post"):
				msg += "Successfully created devlog!";
		HTTPClient.RESPONSE_FOUND: # 302
			msg += "Found, but temporarily redirected\n%s" % body;
		HTTPClient.RESPONSE_NOT_MODIFIED:
			msg += "Nothing changed\n%s" % body;
		HTTPClient.RESPONSE_NOT_FOUND: # 404
			msg += "Not Found!\n%s" % body;
		HTTPClient.RESPONSE_CONFLICT: # 409
			msg += "Conflict!\n%s" % body;
		HTTPClient.RESPONSE_FORBIDDEN: # 403
			msg += "You don't have access to that!\n%s" % body;
		HTTPClient.RESPONSE_UNPROCESSABLE_ENTITY: # 422
			msg += "Validation failed / Spam\n%s" % body;
		HTTPClient.RESPONSE_SERVICE_UNAVAILABLE: # 503
			msg += "Service unavailable, try again later\n%s" % body;
		_:
			if (msg_type == "edit_dir"):
				msg += "Not implemented, failed to edit directory!\n%s" % body;
			else:
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
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.GetData, {}
	);
	var queries = create_get_devlogs_queries(config);
	
	var url = config.get_value("urls", "base_repo");
	# TODO url stripping depending on type of content path
	url = url.rstrip("/") + "?"; # [/text_files/ vs /text_files] redirected to main branch
	url += queries;
	
	return make_get_devlogs_request(scene, headers, url);


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
	
	var headers = create_headers(
		config, AcceptType.Text, RequestType.GetData, {}
	);
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
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData,
		{ "body_length": str(body_str.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name;
	
	return make_edit_directory_file_request(scene, headers, body_str, url);


func make_fetch_directory_file_request(scene: Node, headers: Array, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_download_json_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_fetch_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.GetData, {}
	);
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name + "?ref=" + config.get_value("repo_info", "repo_branch_update");
	
	return make_fetch_directory_file_request(scene, headers, url);


func create_headers(config: ConfigFile, accept_type: AcceptType, request_type: RequestType, addt_data: Dictionary):
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	var accept = "application/vnd.github+json"; # default
	if (accept_type == AcceptType.Text):
		accept = "text/plain";
	
	var headers = [
		"User-Agent: " + app_name,
		"Accept: %s" % accept,
		"Accept-Encoding: gzip, deflate",
		"Authorization: " + auth_type + " " + user_token,
	];
	
	match request_type:
		RequestType.SendData:
			headers.append_array([
				"Content-Type: application/json",
				"Content-Length: " + addt_data["body_length"]
			]);
		_:
			pass;
	
	return headers;


func create_body(config: ConfigFile, msg: String, addt_data: Dictionary) -> String:
	var body = { # required for commits
		"message": msg,
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"branch": config.get_value("repo_info", "repo_branch_update")
	};
	
	# addt. info to add if applicable
	if (addt_data.has["sha"]):
		body["sha"] = addt_data["sha"];
	
	if (addt_data.has["content"]):
		body["content"] = Marshalls.utf8_to_base64(addt_data["content"]);
	
	return JSON.stringify(body);


func create_get_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var headers = create_headers(
		config, AcceptType.Text, RequestType.GetData, {}
	);
	
	var url = directory.download_url;
	
	return make_get_directory_file_request(scene, headers, url);
	
	



func make_get_directory_file_request(scene: Node, headers: Array, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_download_text_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_GET);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_delete_file_body(config: ConfigFile, button_ref: Button):
	return JSON.stringify({
		"message": "Deleted devlog.",
		"committer": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		},
		"sha": button_ref.get_meta("sha"),
		"branch": config.get_value("repo_info", "repo_branch_update")
	});


func make_delete_file_request(scene: Node, headers: Array, body: String, url: String):
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(scene._on_http_delete_post_completed);
	
	var error = h_client.request(url, headers, HTTPClient.METHOD_DELETE, body);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


func create_delete_file_request(scene: Node, entry_delete_button: Button):
	var config = load_config();
	
	if (!config.has("config")):
		return config;
	
	var button_ref = entry_delete_button;
	
	var body_str = create_delete_file_body(config, button_ref);
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += button_ref.get_meta("name");
	
	return make_delete_file_request(scene, headers, body_str, url);
