#import "Compiler";
String :: #import "String";
#import "Basic";
#import "Metaprogram_Plugins";

// --------
// Lsp and stuff

Lsp_Mode :: enum {
    LOCATE;
};

mode : Lsp_Mode;
file : string;
line : int;
col : int;
found : bool = false;

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

parse_code_node :: (node : *Code_Node) {
    if node.kind == {
        // @Todo: #import and #load should open the corresponding file.
        case .IDENT;
            ident := cast(*Code_Ident)node;
            decl := ident.resolved_declaration;
            l0 := decl.location.l0;
            c0 := decl.location.c0;

            l1 := decl.location.l1;
            c1 := decl.location.c1;
            
            if decl.expression.kind == .PROCEDURE_HEADER {
                proc := cast(*Code_Procedure_Header) decl.expression;
                for proc.returns {
                    if it.location.l1 >= l1 {
                        l1 = it.location.l1;
                        c1 = it.location.c1;
                    }
                }
            }
            if decl.expression.kind == .STRUCT {
                structure := cast(*Code_Struct) decl.expression;
                if structure.block.location.l1 >= l1 {
                    l1 = structure.block.location.l1;
                    c1 = structure.block.location.c1;
                }
                l1 += 1; // Closing brace @Hack
            }
            // For some weird reason we can't call print with integers here.
            // It causes an assertion, that hangs the program. 
            // We build the string manually instead.
            builder : String_Builder;
            append(*builder, "OK|");
            append(*builder, decl.location.enclosing_load.fully_pathed_filename);
            append(*builder, "|");
            print_integer(*builder, formatInt(l0));
            append(*builder, "|");
            print_integer(*builder, formatInt(c0));
            append(*builder, "|");
            print_integer(*builder, formatInt(l1));
            append(*builder, "|");
            print_integer(*builder, formatInt(c1));
            append(*builder, "\n");
            str := builder_to_string(*builder);
            write_string(str);
            
            found = true;
    };
}


get_plugin :: () -> *Metaprogram_Plugin {
  p := New(Metaprogram_Plugin);

  p.handle_one_option = lsp_handle_one_option;
  p.message = lsp_message;

  return p;
}

lsp_parse_args :: (options : []string, cursor: int) -> new_cursor: int {
    s := options[cursor];
    if s == {
        case "-locate";
            mode = .LOCATE;
            ok : bool;
            file = options[cursor + 1];
            line, ok = String.parse_int(*options[cursor + 2]);
            if !ok {
                print("ERROR|Couldn't parse line.");
            }
            col, ok = String.parse_int(*options[cursor + 3]);
            if !ok {
                print("ERROR|Couldn't parse column.");
            }
            if ok {
              cursor += 3;
            }
            //log("SEARCHING%:%:%\n", file, line, col);
    };

    return cursor;
}

lsp_handle_one_option :: (p: *Metaprogram_Plugin,
                          options: []string,
                          cursor: int) -> new_cursor : int {


    if options[cursor] == "-lsp_plugin" {
      print( "Foo\n" );
      cursor += 1;
      cursor += lsp_parse_args(options, cursor);
    }

    return cursor;
}

lsp_message :: (p: *Metaprogram_Plugin, message : *Message) {
    if message.kind == .TYPECHECKED {
        if found return;
        tc := cast(*Message_Typechecked) message;

        for tc.all {
            for sub_expr : it.subexpressions {
                if check_location(file, line, col, sub_expr.location) {
                    parse_code_node(sub_expr);
                    if found return;
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
