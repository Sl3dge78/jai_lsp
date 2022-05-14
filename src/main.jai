#import "Basic";
#import "jason";
#import "String";
#import "System";
#import "Process";
#import "File_Utilities";

#if (OS == .LINUX) {
    #load "linux.jai";    
}

#if (OS == .WINDOWS) {
    #load "windows.jai";  
}

#load "request_types.jai";
#load "messages.jai";

#load "logging.jai";

VERSION :: "0.0.1";
PLUGIN_SEARCH_PATH : string;
HAS_METAPROGRAM := true;

INNER_INIT_FUNC :: #string JAI
#import \"Metaprogram_Plugins\";
init_lsp :: (workspace : Workspace) -> *Metaprogram_Plugin {
    plugin_names := string.[\"lsp_plugin\"];
    plugins : [..] *Metaprogram_Plugin;
    init_plugins(plugin_names, *plugins, workspace);
    lsp := plugins[0];
    lsp.before_intercept(lsp);

    options := get_build_options();
    args := options.compile_time_command_line;
    for args {
        if it == \"lsp_plugin\" {
            lsp.handle_one_option(lsp, args, it_index + 1);
            break;
        }
    }

    return lsp;
}
JAI;

// --------
// Logging

init_logger :: () {
    file := file_open(LOGGING_FILE_PATH, true, keep_existing_content = false); // Create or empty logging file
    file_close(*file);
    context.logger = file_logger;
}


// --------
// Communication

send_message :: (message: string) {
    write_string(message);
    log_verbose("Message sent: %\n", message);
}

handle_message :: (body : string) -> success : bool #must {
    request, success := json_parse_string(body, LSP_Request);
    if !success {
        log_error("Unable to parse as json:\n%\n\n", body);
        return false;
    }
    log("Method : \"%\"\n", request.method);
    if request.method == {
        case "initialize";
            return on_initialize(body);
        case "initialized";
            return on_initialized(body);
        case "shutdown";
            return on_shutdown(body);
        case "textDocument/definition";
            return on_definition_request(body);
        case;
            log("Unhandled method: %\n", request.method, body, flags = .WARNING);
            return true;
    }    
}

parse_header :: (header : string) -> s32, success : bool{
    split_header := split(header, ": ");
    if split_header[0] != "Content-Length" {
        log_error("Expected length message, got:\n%\n", split_header[0]);
        return 0, false;
    }

    nb_bytes, success := parse_int(*split_header[1], s32);
    return nb_bytes, success;
}

shutdown_received := false;

main :: () {
    context.log_level = .VERBOSE;
    init_logger();
    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    defer free(PLUGIN_SEARCH_PATH);
    HAS_METAPROGRAM = true;

    log("Jai lsp starting up\n");

    should_quit := false;
    while !should_quit {
        reset_temporary_storage();
        
        log_verbose("====\n");
        body, success := wait_for_message();

        if !success {
            log_error("Error while reading message\n");
            break;
        }

        success = handle_message(body);
        if !success {
            log_error("Error while handling message\n");
            break;
        }
    }
    log("Shutting down\n");
}

main1 :: () {
    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    compile := start_compilation("-locate /home/sl3dge/work/prog/jai-lsp-vscode/test_project/main.jai 8 12");
}