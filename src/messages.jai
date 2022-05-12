
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
    
    // Let's try building the file!
    log_verbose("Preparing workspace.\n");
    w := compiler_create_workspace();
    log_verbose("Workspace % created.\n", w);
    options := get_build_options();
    options.text_output_flags = 0;
    options.output_type = .NO_OUTPUT;
    options.backend = .X64;
    set_build_options(options, w);
    log_verbose("Build options set.\n");

    compiler_begin_intercept(w);
    add_build_file(file_path, w);
    log("Compiling: %\n");
    while true {
        msg := compiler_wait_for_message();

        if !msg continue;
        if msg.kind == .COMPLETE {
            complete_msg := cast(*Message_Complete) msg;
            log("Compilation ended with result %", complete_msg.error_code);
            break;
        }

        if msg.kind == .TYPECHECKED {
            tc := cast(*Message_Typechecked) msg;
            for tc.all {
                if position.line + 1 >= it.expression.location.l0 && position.line + 1 <= it.expression.location.l1 {
                    if position.character + 1 >= it.expression.location.c0 && position.character + 1 <= it.expression.location.c1 {
                        log("Found definition matching : %", it.expression.kind);
                        if it.expression.kind == {
                            case .IDENT;
                                ident := cast(*Code_Ident) it.expression;
                                decl := ident.resolved_declaration;
                                loc := decl.expression.location;
                                log("decl is at %:%:%", loc.enclosing_load.fully_pathed_filename, loc.l0, loc.c0);
                        };

                    }   
                }
            }
        }
    }
    compiler_end_intercept(w);

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
