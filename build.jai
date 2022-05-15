#import "Compiler";
#import "Basic";
#import "File_Utilities";

#run build();

build :: () {
    set_build_options_dc( .{do_output = false} );
    w := compiler_create_workspace();

    opt := get_build_options(); 
    opt.output_type = .EXECUTABLE;
    opt.output_path = "";
    opt.output_executable_name = "jai_lsp";

    file_path := parse_path(#filepath);
    path_string := path_to_string(file_path, file_path.words.count);
    defer free(path_string);

    import_path : [..] string;
    array_add(*import_path, ..opt.import_path);
    array_add(*import_path, path_string);
    opt.import_path = import_path;

    lsp_message : (message : *Message);
    is_lsp := false;
    if opt.user_data_u64 {
        lsp_message = << cast(*(*Message)) opt.user_data_u64;  
        is_lsp = true;
    }

    set_build_options(opt, w);

    compiler_begin_intercept(w);
    add_build_file("src/main.jai", w);

    while true {
    msg := compiler_wait_for_message();
        if !msg continue;
        if msg.kind == .COMPLETE break;
        
        if is_lsp {
            lsp_message(msg);
        }
    }
    compiler_end_intercept(w);
}
