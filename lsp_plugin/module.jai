// @Todo: find a way to add a search path for metaprogram plugins

#import "Compiler";
#import "Basic";
String :: #import "String";

file : string;
line : int;
col : int;
found : bool = false;

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Metaprogram_Plugin);  

    p.before_intercept  = before_intercept;
    p.message           = message;
    p.shutdown          = shutdown;
    p.handle_one_option = handle_one_option;
    return p;
}

before_intercept :: (p: *Metaprogram_Plugin) {
    options := get_build_options(p.workspace);
    options.output_type = .NO_OUTPUT;
    //options.text_output_flags = 0;
    set_build_options(options, p.workspace);
}

check_location :: (file: string, line : int, char : int, location : Code_Node.Location) -> bool {
    if !location.enclosing_load {
        return false;
    }

    loc_file := location.enclosing_load.fully_pathed_filename;
    // print("%\n", loc_file);
    if(file == loc_file) {
        // print("%:%:%\n", loc_file, location.l0, location.c0);
        if line >= location.l0 && line <= location.l1 {
            if col >= location.c0 && col <= location.c1 {
                // print("%:%:%\n", loc_file, location.l0, location.c0);
                return true;
            }
        }
    }
    return false;
}

message :: (p: *Metaprogram_Plugin, message: *Message) {
    if message.kind == .TYPECHECKED {
        if found return;
        tc := cast(*Message_Typechecked) message;
        
        for tc.all {
            // print("EXPR: % - %\n", it.expression.kind, it.expression.location.enclosing_load.fully_pathed_filename);
            for sub_expr : it.subexpressions {
                if check_location(file, line, col, sub_expr.location) {
                    // print("Found match.\nKind:%\n", sub_expr.kind);
                    if sub_expr.kind == {
                        // @Todo: #import and #load should open the corresponding file.
                        case .IDENT;
                            ident := cast(*Code_Ident)sub_expr;
                            decl := ident.resolved_declaration;
                            print("OK:%:%:%\n", decl.location.enclosing_load.fully_pathed_filename, decl.location.l0, decl.location.c0);
                            found = true;
                            return;
                    };
                    break;
                }
            }
        }
    }

    if message.kind == .COMPLETE {
        complete := cast(*Message_Complete) message;
        if complete.error_code == {
            case .NONE;
                print("COMPILE_OK\n");
            case;
                print("COMPILE_NOK\n");
        };
    }
} 

handle_one_option :: (p: *Metaprogram_Plugin, options : []string, cursor: int) -> new_cursort: int {
    s := options[cursor];
    if s == {
        case "-locate";
            ok : bool;
            file = String.replace(options[cursor + 1], "\\", "/");            
            line, ok = String.parse_int(*options[cursor + 2]);
            if !ok {
                print("ERROR:Couldn't parse line.");
                return cursor;
            }
            col, ok = String.parse_int(*options[cursor + 3]);
            if !ok {
                print("ERROR:Couldn't parse column.");
                return cursor;
            }
            // print("SEARCHING: %:%:%\n", file, line, col);
            return cursor + 4;
    };

    return cursor;
}

shutdown :: (p: *Metaprogram_Plugin) {
    free(file);
    free(p);
}