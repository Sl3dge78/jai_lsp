
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

    return lsp_send_object(built);
}

lsp_send_object :: (object : $T) -> success : bool {
    body := json_write_string(object, indent_char = "", line_ending = "");
    //log_verbose("Reply: %\n", body);
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

    location_success, result_location := get_definition_location(file_path, position.line + 1, position.character + 1);
    
    if !location_success {
        send_empty_lsp_result(definition_req.id);
    } else {
        send_lsp_result(definition_req.id, result_location);
    }

    return true;
}

on_hover :: (body : string) -> bool {
    definition_req, success := json_parse_string(body, LSP_Request_Hover);

    file_path := translate_uri(definition_req.params.textDocument.uri);
    position := definition_req.params.position;

    location_success, result_location := get_definition_location(file_path, position.line + 1, position.character + 1);
    
    if !location_success {
        send_empty_lsp_result(definition_req.id);
    } else {
        l0 := result_location.range.start.line;
        c0 := result_location.range.start.character;
        l1 := result_location.range.end.line;
        c1 := result_location.range.end.character;
        path := translate_uri(result_location.uri);
        log_verbose("%\n", path);
        file := read_entire_file(path);
        defer free(file);
        lines := split(file, "\n");
        builder : String_Builder;
        defer free_buffers(*builder);
        append(*builder, "```jai\n");
        
        line := l0;
        while line <= l1 {           
            if line == l0 && line == l1 then append(*builder, lines[line].data + c0, c1-c0);
            else if line == l0          then append(*builder, lines[line].data + c0, lines[line].count - c0);
            else if line == l1          then append(*builder, lines[line].data, c1);
            else                             append(*builder, lines[line]);
            append(*builder, "\n");
            line += 1;
        }
        append(*builder, "```");
        hover_string : LSP_Hover;
        hover_string.contents = builder_to_string(*builder);
        defer free(hover_string.contents);
        send_lsp_result(definition_req.id, hover_string);
    }
    return true;
}
