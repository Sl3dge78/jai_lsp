#import "Basic";
#import "jason";
#import "String";
#import "System";
#import "Process";
#import "File_Utilities";
Command_Line :: #import "Command_Line";

#if (OS == .LINUX) {
    #load "linux.jai";    
}

#if (OS == .WINDOWS) {
    #load "windows.jai";  
}

#load "request_types.jai";
#load "messages.jai";

#load "logging.jai";

VERSION :: "0.1.0";

// --------
// Compiling target program

PLUGIN_SEARCH_PATH : string;
BUILD_FILE : string;
LOGGING_FILE_PATH : string;

start_compilation :: (request : string) -> string {
    command := tprint("jai % -- lsp_plugin % --- import_dir % meta lsp_metaprogram", BUILD_FILE, request, PLUGIN_SEARCH_PATH);
    log_verbose("Starting compilation : %\n", command);
    args := split(command, " ");
    successfully_launched, exit_code, output_string := os_run_command(..args, capture_and_return_output = true);
    defer free(output_string);
    return copy_temporary_string(output_string);
}

// --------
// Logging

init_logger :: () {
    LOGGING_FILE_PATH = join(get_temp_path(), "jai_lsp.log");
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

Arguments :: struct {
    build_file : string; 
}

main :: () {
    
    // context.log_level = .VERBOSE;
    init_logger();
    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    defer free(PLUGIN_SEARCH_PATH);
    
    success, args, is_set := Command_Line.parse_arguments(Arguments);
    if !success || !is_set.build_file {
        print("Please provide a build file as argument");
    }
    
    if is_absolute_path(args.build_file) {
        BUILD_FILE = args.build_file;
    } else {
        BUILD_FILE = sprint("%/%", get_working_directory(), args.build_file);
    }

    log("Jai lsp starting up in %\n", get_working_directory());

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

main2 :: () {
    LOGGING_FILE_PATH = get_temp_path();
    log("%", LOGGING_FILE_PATH);

    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    compile := start_compilation("-locate /home/sl3dge/work/prog/jai-lsp-vscode/test_project/main.jai 8 12");
}