
send_empty_lsp_result :: (id : u32) -> success : bool {
    Full_Reply :: struct {
        using request : LSP_Answer;
        result : *void;
    };

    built : Full_Reply;
    built.id = id;
    built.result = null;

    body := json_write_string(built, indent_char = "", line_ending = "");
    log_verbose("Reply: %\n", body);
    print("Content-Length: %\r\n\r\n%", body.count, body);
    return true;
}

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
    // jai -plug lsp_plugin -locate file_to_search_in.jai 10 20 file_to_compile.jai --- import_dir ./
    command := tprint("-locate % % %", file_path, position.line + 1, position.character + 1);
    log("%\n", command);
    compile_result := start_compilation(command);

    result_location : LSP_Location;

    splitted := split(compile_result, "\n");
    if splitted[0] != "COMPILE_OK" {
        loc := split(splitted[0], ":");
        if loc[0] == "OK" {
            result_location.uri = tprint("file://%", loc[1]);
            result_location.range.start.line = xx (parse_int(*loc[2])  - 1);
            result_location.range.start.character = xx (parse_int(*loc[3]) - 1);
            result_location.range.end = result_location.range.start;
        } else {
            send_empty_lsp_result(definition_req.id);
            log("%\n", compile_result);
            return true;
        }
    } else {
        send_empty_lsp_result(definition_req.id);
        log("%\n", compile_result);
        return true;
    }

    send_lsp_result(definition_req.id, result_location);
    return true;
}
