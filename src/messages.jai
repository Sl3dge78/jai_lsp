
send_lsp_result :: (id : u32, object : $T) -> success : bool {
    Full_Reply :: struct {
        using request : LSP_Answer;
        result : T;
    };

    built : Full_Reply;
    built.id = id;
    built.result = object;

    body := json_write_string(built, indent_char = "", line_ending = "");
    log_verbose("Reply: %\n", body);
    print("Content-Length: %\r\n\r\n%", body.count, body);
    return true;
}

on_initialize :: (body_str : string) -> bool {
    body, success := json_parse_string(body_str, LSP_Request_Initialize);
    if !success return false;

    to_send : LSP_Result_Initialize;
    success = send_lsp_result(body.id, to_send);
    return true;
}

on_initialized :: (body : string) -> bool {
    //context.logger = client_log;
    log("jai-lsp - v%\n", VERSION);    
    return true;
}

on_shutdown :: (body : string) -> bool {
    shutdown_received = true;
    return true;
}

on_definition_request :: (str : string) -> bool {
    definition_req, success := json_parse_string(str, LSP_Request_Definition);
    if !success {
        log_error("Unable to parse the message as a definition request\n");
    }
    
    file_path := translate_uri(definition_req.params.textDocument.uri);
    position := definition_req.params.position;
    
    // Now we need to compile the project with our metaprogram plugin so that we can fetch the definition through its stdout.
    // jai -plug lsp_plugin -locate D:/_Guigui/__bordel/__/jai-lsp-vscode/test_project/main.jai 10 20 D:/_Guigui/__bordel/__/jai-lsp-vscode/test_project/main.jai --- import_dir ./

    // Let's return a bogus value for now
    result_location : LSP_Location;
    result_location.uri = definition_req.params.textDocument.uri;
    result_location.range.start.line = 10;
    result_location.range.start.character = 0;
    result_location.range.end.line = 10;
    result_location.range.end.character = 2;
    send_lsp_result(definition_req.id, result_location);

    return true;
}
