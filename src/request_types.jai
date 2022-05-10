

LSP_Message :: struct {
    jsonrpc : string;
}

LSP_Notification :: struct {
    using LSP_Message;
}

LSP_Request :: struct {
    using LSP_Message;
    id : u32;
}

Position :: struct {
    line : s32;
    character : s32;
}

DefinitionRequest :: struct {
    using LSP_Request;
    params : struct {
        textDocument : struct {
            uri : string;
        };
        position : Position; 
    };
}

on_definition_request :: (str : string) {
    definition_req, success := json_parse_string(str, DefinitionRequest);
    if !success {
        print_to_file("Error: Unable to parse the message as a definition request\n");
    }
    
    print_to_file(tprint("Requesting token at in file %:%,%\n", definition_req.params.textDocument.uri, definition_req.params.position.line, definition_req.params.position.character));
    file_path := slice(definition_req.params.textDocument.uri, 7, definition_req.params.textDocument.uri.count - 7);
    position := definition_req.params.position;
    print_to_file(file_path);
    print("file : %, pos : %\n", file_path, position);

    // Let's try building the file!
    w := compiler_create_workspace();
    options := get_build_options();
    options.output_type = .NO_OUTPUT;
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file(file_path, w);
    while true {
        msg := compiler_wait_for_message();

        if !msg continue;
        if msg.kind == .COMPLETE {
            print_to_file("Compilation ended");
            break;
        }

        if msg.kind == .TYPECHECKED {
            tc := cast(*Message_Typechecked) msg;
            for tc.all {
                if position.line + 1 >= it.expression.location.l0 && position.line + 1 <= it.expression.location.l1 {
                    if position.character + 1>= it.expression.location.c0 && position.character + 1<= it.expression.location.c1 {
                        print_to_file(tprint("Found definition matching : %", it.expression.kind));
                        if it.expression.kind == {
                            case .IDENT;
                                ident := cast(*Code_Ident) it.expression;
                                decl := ident.resolved_declaration;
                                loc := decl.expression.location;
                                print_to_file(tprint("decl is at %:%:%", loc.enclosing_load.fully_pathed_filename, loc.l0, loc.c0));
                        };

                    }   
                }
            }
        }
    }
    compiler_end_intercept(w);
}
