#import "Basic";
posix :: #import "POSIX";
#import "File";
#import "jason";
#import "Window_Creation";
#import "Hash_Table";
#import "String";
#import "Compiler";
// #import "Runtime_Support";

#load "request_types.jai";


VERSION :: "0.0.1";

client_log :: (message : string, data : *void, info : Log_Info) {
    log := tprint("{\"jsonrpc\":\"2.0\",\"method\":\"window/logMessage\",\"params\":{\"type\":3,\"message\":\"%\"}}", message);
    write := tprint("Content-Length: %\r\n\r\n%", log.count, log);
    write_string(write);
}

file_log :: (message : string, data :*void, info :Log_Info) {
    file := file_open("/tmp/jai-lsp.log", true, true);
    file_write(*file, message);
    file_close(*file);
}

send_message :: (message: string) {
    write := tprint("Content-Length: %\r\n\r\n%", message.count, message);
    write_string(write);
    log("Reply sent : %\n", write);
}

message_received :: (message_str : string) {
    message_json, success := json_parse_string(message_str);
    if !success {
        log("Unable to parse as json:\n%\n\n", message_str);
        return;
    }

    value, ok := table_find(message_json.object, "method"); 
    if (!ok) {
        log("'method' wasn't in the message\n%\n\n", message_str);
        return;
    }

    if(value.type == .STRING) {
        log("Method received : \"%\"\n", value.str);
        if value.str == {
            case "initialize";
                on_initialize(message_json);
            case "initialized";
                on_initialized(message_str);
                
            case "shutdown";
                on_shutdown(message_json);
            
            case "textDocument/definition";
                on_definition_request(message_str);
            case;
                log("Unhandled message: %\n%s\n", value.str, message_str);
        }
    }
}

on_initialize :: (json : JSON_Value) {
    // Parse message received for the id
    // @Incomplete: read the capabilities?
    id_obj, ok := table_find(json.object, "id");
    if !ok {
        log("Unable to find key id in request\n");
        return;
    }
    id : string;
    if id_obj.type == {
        case .NUMBER;
            id = tprint("%", id_obj.number);
        case .STRING;
            id = tprint("%", id_obj.str);
    }
   
    // Now write our reply
    // @Cleanup: this is messy
    part_1 :: #string JSON
{"jsonrpc":"2.0","id":
JSON;

    part_2 :: #string JSON
,"result":{"capabilities": {"definitionProvider":true},"serverInfo":{"name":"jai_lsp","version":"
JSON;

    part_3 :: #string JSON
"}}}
JSON;

    builder : String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    append(*builder, part_1);
    append(*builder, id);
    append(*builder, part_2);
    append(*builder, VERSION);
    append(*builder, part_3);

    result := builder_to_string(*builder);
    defer free(result);

    send_message(result);
}

on_initialized :: (message : string) {
    //context.logger = client_log;
    log("jai-lsp - v%\n", VERSION);    
}

on_shutdown :: (json : JSON_Value) {
    shutdown_received = true;
}

shutdown_received := false;

main :: () {
    file := file_open("/tmp/jai-lsp.log", true, false); // Create / empty logging file
    file_close(*file);

    context.logger = file_log;
    log("Jai lsp starting up\n");

    should_quit := false;
    while !should_quit {
        reset_temporary_storage();

        // Read length
        buffer : [1024] u8;
        bytes_read := posix.read(posix.STDIN_FILENO, buffer.data, buffer.count - 1);
        str := to_string(buffer.data, bytes_read);
        split_msg := split(str, ":");
        log("Msg received : %\new_flags", str);
        if split_msg[0] != "Content-Length" {
            log("Expected length message, got:\n%\n", split_msg[0]);
            break;
        }

        nb_bytes, success := parse_int(*split_msg[1], u32);
        if !success {
            log("Unable to parse string as int: %\n", split_msg[1]);
            break;
        }

        req_buffer := talloc(nb_bytes);
        bytes_read = posix.read(posix.STDIN_FILENO, req_buffer, nb_bytes);
        assert(bytes_read == nb_bytes);

        req_str := to_string(req_buffer, bytes_read);
        log("Msg received : %\n", req_str);

        message_received(req_str);
    }
}


