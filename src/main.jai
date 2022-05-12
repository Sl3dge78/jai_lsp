#import "Basic";
#import "File";
#import "jason";
#import "Window_Creation";
#import "Hash_Table";
#import "String";
#import "Compiler";

/*
#if (OS == .LINUX) {
    #load "linux.jai";    
}
*/

#if (OS == .WINDOWS) {
    #load "windows.jai";  
}

#load "request_types.jai";
#load "messages.jai";

VERSION :: "0.0.1";

// --------
// Logging

client_log :: (message : string, data : *void, info : Log_Info) {
    log := tprint("{\"jsonrpc\":\"2.0\",\"method\":\"window/logMessage\",\"params\":{\"type\":3,\"message\":\"%\"}}", message);
    write := tprint("Content-Length: %\r\n\r\n%", log.count, log);
    write_string(write);
}

file_logger :: (message : string, data :*void, info : Log_Info) {
    if (info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE) return;
    if (info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE) return;

    file := file_open(TMP_FILE_PATH, true, keep_existing_content = true);
    file_set_position(file, file_length(file));

    if info.common_flags == { 
        case .ERROR;
            file_write(*file, "ERROR: ");
        case .WARNING;
            file_write(*file, "WARNING: ");
        case;
            file_write(*file, "INFO: ");
    } 

    file_write(*file, message);
    file_close(*file);
}

init_logger :: () {
    file := file_open(TMP_FILE_PATH, true, keep_existing_content = false); // Create or empty logging file
    file_close(*file);
    context.logger = file_logger;
}

log_verbose :: (format_string: string, args : ..Any) {
    log(format_string, ..args, flags = .VERBOSE_ONLY);
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

server_main :: () {
    context.log_level = .VERBOSE;
    init_logger();
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

repl_main :: () {
    
}

main :: () {
    server_main();
}