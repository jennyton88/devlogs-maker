class_name Requests


enum RequestType {
	SendData,
	GetData,
	SendURLData
}

enum AcceptType {
	Text,
	GitJSON
}


# =====================
# === Main Methods ====
# =====================

func make_http_request(
	scene: Node, callable: Callable, method: HTTPClient.Method, 
	url: String, headers: Array, request_data: String = ""
) -> Dictionary:
	var h_client = HTTPRequest.new();
	scene.add_child(h_client);
	h_client.request_completed.connect(callable);
	
	var error = h_client.request(url, headers, method, request_data);
	
	if (error != OK):
		return { "error": error, "error_type": AppInfo.ErrorType.HTTPError };
	
	return {};


# addt_data: Dictionary {
# content: String /  OPTIONAL
# sha: String / OPTIONAL
# }
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
	if (addt_data.has("sha")):
		body["sha"] = addt_data["sha"];
	
	if (addt_data.has("content")):
		body["content"] = Marshalls.utf8_to_base64(addt_data["content"]);
	
	return JSON.stringify(body);


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
	];
	
	match request_type:
		RequestType.SendData:
			headers.append_array([
				"Content-Type: application/json",
				"Content-Length: " + addt_data["body_length"]
			]);
		RequestType.SendURLData:
			headers.append_array([
				"Content-Type: application/x-www-form-urlencoded", 
				"Content-Length: " + addt_data["body_length"]
			]);
		_:
			pass;
	
	if (request_type != RequestType.SendURLData):
		headers.append("Authorization: " + auth_type + " " + user_token);
	
	return headers;


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
					msg = "Successfully deleted devlog!";
				"get_verify_code":
					msg = "";
				"get_token_code":
					msg = "";
				"fetch_directory":
					msg = "";
				"get_directory":
					msg = "";
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


func create_queries(fields: Dictionary):
	return HTTPClient.new().query_string_from_dict(fields);


func get_files(scene: Node, action: String, 
	url: String, headers: Array, request_data: String = ""
):
	return make_http_request(
		scene, scene._on_http_request_completed.bind(action), 
		HTTPClient.METHOD_GET, url, headers, request_data
	);


func send_files(scene: Node, action: String,
	url: String, headers: Array, request_data: String
):
	return make_http_request(
		scene, scene._on_http_request_completed.bind(action), 
		HTTPClient.METHOD_PUT, url, headers, request_data
	);

# =====================
# ====== Helpers ======
# =====================

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
	
	return config;

# =====================
# == Custom Requests == # deals with unique urls, queries, actions
# =====================

func create_get_devlogs_request(scene: Node):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.GetData, {}
	);
	var fields = { "ref": config.get_value("repo_info", "repo_branch_update") };
	var queries = create_queries(fields);
	
	var url = config.get_value("urls", "base_repo");
	# TODO url stripping depending on type of content path
	url = url.rstrip("/") + "?"; # [/text_files/ vs /text_files] redirected to main branch
	url += queries;
	
	return get_files(scene, "get_devlogs", url, headers);


func create_post_request(scene: Node, edit_ref: Node, content: String, filename: String):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var action_type = "post_devlog";
	var addt_data = { "content": content };
	var msg = "Posted";
	
	if (edit_ref != null):
		addt_data["sha"] = edit_ref.get_meta("sha");
		msg = "Edited";
		action_type = "edit_devlog";
	
	msg += " devlog.";
	
	var body_str = create_body(config, msg, addt_data);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += filename;
	
	return send_files(scene, action_type, url, headers, body_str);


## Get the reference (branch) commit sha
func get_ref(scene: Node):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY): # change to ( ! is ConfigFile)
		return config;
	
	var headers = create_headers(config, AcceptType.GitJSON, RequestType.GetData, {});
	
	var url = "https://api.github.com/repos/%s/%s/git/ref/heads/%s" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
		config.get_value("repo_info", "repo_branch_update")
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("get_ref"), HTTPClient.METHOD_GET, 
		url, headers
	);


## Upload file to the repo as a blob. This can be used as a part of a tree.
## File must be encoded already to base64
func create_blob(scene: Node, content: String):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY): # change to ( ! is ConfigFile)
		return config;
	
	var body_str = JSON.stringify({
		"content": content,
		"encoding": "base64"
	});
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/git/blobs" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("create_blob"), HTTPClient.METHOD_POST, 
		url, headers, body_str
	);

func create_edit_download_request(scene: Node, button: Button):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var headers = create_headers(
		config, AcceptType.Text, RequestType.GetData, {}
	);
	var url = button.get_meta("url");
	
	return get_files(scene, "get_file", url, headers);


func create_edit_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var addt_data = { "content": directory["data"], "sha": directory["sha"] };
	var body_str = create_body(config, "Edited directory.", addt_data);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData,
		{ "body_length": str(body_str.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name;
	
	return send_files(scene, "edit_dir", url, headers, body_str);


func create_fetch_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.GetData, {}
	);
	
	var url = config.get_value("urls", "base_repo");
	url += directory.name + "?ref=" + config.get_value("repo_info", "repo_branch_update");
	
	return get_files(scene, "fetch_directory", url, headers);


func create_get_directory_file_request(scene: Node, directory):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var headers = create_headers(
		config, AcceptType.Text, RequestType.GetData, {}
	);
	
	var url = directory.download_url;
	
	return get_files(scene, "get_directory", url, headers);


func create_delete_file_request(scene: Node, entry_delete_button: Button):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var button_ref = entry_delete_button;
	
	var body_str = create_body(config, "Deleted devlog.", { "sha": button_ref.get_meta("sha") });
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = config.get_value("urls", "base_repo");
	url += button_ref.get_meta("name");
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("delete_devlog"), HTTPClient.METHOD_DELETE,
		url, headers, body_str
	);


## user code to verify device, NOT user token for api requests
func create_generate_user_code_request(scene: Node):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
	var queries = create_queries({ "client_id": config.get_value("app_info", "app_client_id") });
	var headers = create_headers(config, AcceptType.GitJSON, RequestType.SendURLData, 
		{ "body_length": str(queries.length()) }
	);
	
	var url = config.get_value("urls", "ask_for_user_code");
	
	return make_http_request(
		scene, scene._on_http_req_completed, HTTPClient.METHOD_POST, 
		url, headers, queries
	);


func create_poll_verification_request(scene: Node, refresh_code: bool, device_code):
	var config = load_config();
	
	if (typeof(config) == TYPE_DICTIONARY):
		return config;
	
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
	
	var queries = create_queries(fields);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendURLData,
		{ "body_length": str(queries.length()) }
	);
	
	var url = config.get_value("urls", "poll_for_user_verify");
	
	return make_http_request(
		scene, scene._on_http_poll_completed, HTTPClient.METHOD_POST,
		url, headers, queries
	);
