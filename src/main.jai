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

VERSION :: "0.2.0";

// --------
// Compiling target program

PLUGIN_SEARCH_PATH : string;
BUILD_FILE : string;
LOGGING_FILE_PATH : string;

start_compilation :: (request : string) -> string {
    command := tprint("jai % -plug lsp_plugin % --- import_dir % meta lsp_metaprogram", BUILD_FILE, request, PLUGIN_SEARCH_PATH);
    log_verbose("Starting compilation : %\n", command);
    args := split(command, " ");

    process_result, output_string:= run_command(..args, capture_and_return_output = true, timeout_ms = 5000);
    defer free(output_string);
    return copy_temporary_string(output_string);
}

get_definition_location :: (file_path : string, line : int, character : int) -> success : bool, loc : LSP_Location = .{} {
    // Now we need to compile the project with our metaprogram so that we can fetch the definition through its stdout.
    command := tprint("-locate % % %", file_path, line, character);
    log_verbose("%\n", command);
    compile_result := start_compilation(command);
    log_verbose("COMPILE:%\n", compile_result);
    

    lines := split(compile_result, "\n");
    index : int;
    for lines {
        loc := split(it, "|");
        if loc[0] == {
            case "COMPILE_OK"; 
                log_verbose("compile ok found");
                log("Compilation completed without finding symbol.\n");
                return false;
            case "COMPILE_NOK";
                log("Compilation failed. Couldn't find symbol.\n");
                return false;
        
            case "ERROR"; 
                log_error("Compilation encountered an error %\n", it);
                return false;
            
            case "OK";
                log_verbose("Ok found\n");
                if loc.count < 6 {
                    log_error("Not enough arguments!");
                    return false;
                }

                uri := loc[1];
                #if OS == .WINDOWS {
                    temp := replace(uri, ":/","%3A/");
                    defer free(temp);
                    uri = join("/", temp);
                    defer free(uri);
                }
                
                if(loc[2] == "0" && loc[3] == "0" && loc[4] == "0" && loc[5] == "0") { // Basic types redirect to Preload.jai 0,0,0,0
                log_verbose("Basic type\n");
                    return false, .{};
                }
                result_location : LSP_Location;
                result_location.uri = tprint("file://%", uri);
                result_location.range.start.line = xx (parse_int(*loc[2])  - 1);
                result_location.range.start.character = xx (parse_int(*loc[3]) - 1);
                result_location.range.end.line = xx (parse_int(*loc[4]) - 1);
                result_location.range.end.character = xx (parse_int(*loc[5]) - 1);
                log_verbose("Returning\n");
                return true, result_location;
            case;
                continue;
        }
    }

    log("Couldn't properly parse compilation result:\n%\n", compile_result);
    return false;
} 

// --------
// Logging

init_logger :: ( log_file: string, log_level: Log_Level ) {
    LOGGING_FILE_PATH = log_file;
    //file := file_open(LOGGING_FILE_PATH, true, keep_existing_content = false); // Create or empty logging file
    //file_close(*file);
    context.logger = file_logger;
    context.log_level = log_level;

    log( "Logging initialised at level % to %\n", log_level, log_file );
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
    log("Request : \"%\"\n", request.method);
    if request.method == {
        case "initialize";
            return on_initialize(body);
        case "initialized";
            return on_initialized(body);
        case "shutdown";
            return on_shutdown(body);
        case "textDocument/definition";
            return on_definition_request(body);
        case "textDocument/hover";
            return on_hover(body);
        case "$/cancelRequest";
            return true;
        case;
            log("Unhandled method: %\n", request.method, body, flags = .WARNING);
            return true;
    }    
}

parse_header :: (header : string) -> s32, s32, success : bool{
    split_header := split(header, ": ");
    if split_header[0] != "Content-Length" {
        log_error("Expected length message, got:\n%\n", split_header[0]);
        return 0, 0, false;
    }

    // According to spec, two \r\n precede the content of the message.
    header_length : s32 = 0;
    returns_left := 2;
    while returns_left != 0 {
        if header[header_length] == #char "\n" {
            returns_left -= 1;
        }
        header_length += 1;
        if header_length >= header.count {
            return 0, 0, false;
        }
    }

    nb_bytes, success := parse_int(*split_header[1], s32);
    return nb_bytes, header_length, success;
}

shutdown_received := false;

Arguments :: struct {
    build_file : string;
    log_file   : string;
    log_level  : string;
}

main :: () {
    success, args, is_set := Command_Line.parse_arguments(Arguments);
    if !success || !is_set.build_file {
        print("Please provide a build file as argument\n");
        return;
    }

    if !is_set.log_file {
      args.log_file = join( get_temp_path(), "jai_lsp.log" );
    }

    log_level : Log_Level = .NORMAL;
    if is_set.log_level {
      if args.log_level == {
        case "NORMAL"; log_level = .NORMAL;
        case "VERBOSE"; log_level = .VERBOSE;
        case "VERY_VERBOSE"; log_level = .VERY_VERBOSE;
      }
    }
    
    init_logger(args.log_file, log_level);

    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    defer free(PLUGIN_SEARCH_PATH);
    
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
            continue;
        }

        success = handle_message(body);
        if !success {
            log_error("Error while handling message\n");
            continue;
        }
        if(shutdown_received) break;
    }
    log("Shutting down\n");
}

main2 :: () {
    context.log_level = .VERBOSE;
    BUILD_FILE = "build.jai";
    our_path := parse_path(get_path_of_running_executable());
    PLUGIN_SEARCH_PATH = path_to_string(our_path, our_path.words.count - 1);
    ok, loc := get_definition_location("/home/sl3dge/work/jai_lsp/src/main.jai", 239, 24);
}
