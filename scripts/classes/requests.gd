class_name Requests


enum RequestType {
	SendData,
	GetData,
	SendURLData
}

enum AcceptType {
	GitText,
	GitJSON,
	Text,
	Raw,
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
	
	return { "request_signal": h_client.request_completed };


## addt_data: Dictionary {
## content: String / OPTIONAL
## sha: String / OPTIONAL
## }
func create_commit_body(config: ConfigFile, msg: String, addt_data: Dictionary) -> String:
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


func create_headers(
	config: ConfigFile, accept_type: AcceptType, request_type: RequestType, addt_data: Dictionary = {}
) -> Array:
	var app_name = config.get_value("app_info", "app_name");
	var auth_type = config.get_value("user_info", "user_token_type");
	var user_token = config.get_value("user_info", "user_token");
	
	var accept = "";
	match accept_type:
		AcceptType.GitJSON:
			accept = "application/vnd.github+json";
		AcceptType.Text:
			accept = "text/plain";
		AcceptType.GitText:
			accept = "application/vnd.github.text+json";
		AcceptType.Raw:
			accept = "application/vnd.github.raw+json";
		_:
			accept = "application/vnd.github+json"; # default
	
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
				"update_ref":
					msg = "Successfully uploaded devlog!"
				"delete_file":
					msg = "Successfully deleted devlog!";
				_:
					msg = "";
		HTTPClient.RESPONSE_CREATED: # 201
			msg = "";
		HTTPClient.RESPONSE_FOUND: # 302 # TODO UPDATE THIS
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
	
	if (!config is ConfigFile):
		return config;
	
	var url = config.get_value("repo_info", "content_path");
	
	return get_file(scene, "get_devlogs", url);


## Must have EITHER [path to file] OR [full download url]
## Can request for a single file or a list of files at a directory
func get_file(
	scene: Node, action: String, 
	path: String = "", download_url: String = "", accept_file_type: AcceptType = AcceptType.GitJSON
):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var headers = create_headers(config, accept_file_type, RequestType.GetData);
	
	var url = "";
	if (path != ""): # for files at repo only
		url = "https://api.github.com/repos/%s/%s/contents/%s" % [
			config.get_value("repo_info", "repo_owner"),
			config.get_value("repo_info", "repo_name"),
			path
		];
		
		var fields = { "ref": config.get_value("repo_info", "repo_branch_update") };
		var queries = create_queries(fields);
		# ex. '/' ends redirects to files in main dir instead of files in curr dir
		url = url.rstrip("/") + "?" + queries; 
	else: # for any file
		url = download_url;
	
	# TODO Add warning for giving no urls
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind(action), 
		HTTPClient.METHOD_GET, url, headers
	);


## Must have path to file, including filename
## commit_data: Dictionary { 
##  "content": String, 
##  "msg": String, 
##  "sha": String / optional, BUT REQUIRED for editing
## }
func create_update_file(
	scene: Node, action: String, path: String, commit_data: Dictionary
):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var body_data = { "content": commit_data["content"] };
	if (commit_data.has("sha")):
		body_data["sha"] = commit_data["sha"];
	
	var body_str = create_commit_body(config, commit_data["msg"], body_data);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData,
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
		path
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind(action), 
		HTTPClient.METHOD_PUT, url, headers, body_str
	);

## Must have path to file including filename
## file_data: Dictionary {
##   "sha": String, 
## }
func delete_file(scene: Node, action: String, path: String, file_sha: String):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var body_str = create_commit_body(config, "Deleted devlog!", 
		{ "sha": file_sha }
	);
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
		path
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind(action), HTTPClient.METHOD_DELETE,
		url, headers, body_str
	);


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


func create_tree(scene: Node, head_ref_sha: String, tree_data: Array):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var body_str = JSON.stringify({
		"tree": tree_data,
		"base_tree": head_ref_sha
	});
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/git/trees" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("create_tree"), HTTPClient.METHOD_POST,
		url, headers, body_str
	);


func create_commit(scene: Node, msg: String, parents: Array[String], tree_ref_sha: String):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var body_str = JSON.stringify({
		"message": msg,
		"tree": tree_ref_sha, # what you are adding
		"parents": parents, # what it will start from
		"author": {
			"name": config.get_value("user_info", "user_name"),
			"email": config.get_value("user_info", "user_email"),
		}
	});
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData,
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/git/commits" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name")
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("create_commit"), HTTPClient.METHOD_POST,
		url, headers, body_str
	);


func update_ref(scene: Node, commit_ref: String):
	var config = load_config();
	
	if (!config is ConfigFile):
		return config;
	
	var body_str = JSON.stringify({
		"sha": commit_ref,
		"force": false
	});
	
	var headers = create_headers(
		config, AcceptType.GitJSON, RequestType.SendData, 
		{ "body_length": str(body_str.length()) }
	);
	
	var url = "https://api.github.com/repos/%s/%s/git/refs/heads/%s" % [
		config.get_value("repo_info", "repo_owner"),
		config.get_value("repo_info", "repo_name"),
		config.get_value("repo_info", "repo_branch_update")
	];
	
	return make_http_request(
		scene, scene._on_http_request_completed.bind("update_ref"), HTTPClient.METHOD_PATCH,
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
