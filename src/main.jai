#import "Basic";
#import "POSIX";
#import "File";
#import "jason";
#import "Window_Creation";
#import "Hash_Table";
#import "String";
#import "Compiler";

#load "request_types.jai";

message_received :: (message_str : string) {
    message_json, success := json_parse_string(message_str);
    if !success {
        print_to_file("Unable to parse as json:\n");
        print_to_file(message_str);
        print_to_file("\n\n");
        return;
    }

    value, ok := table_find(message_json.object, "method"); 
    if (!ok) {
        print_to_file("'method' wasn't in the message\n");
        print_to_file(message_str);
        print_to_file("\n\n");
        return;
    }

    if(value.type == .STRING) {
        print_to_file(tprint("Method received : \"%\"\n", value.str));
        if value.str == {
            case "initialize";
                on_initialize(message_json);
            case "shutdown";
                on_shutdown(message_json);
            case "initialized";
            case "textDocument/definition";
                on_definition_request(message_str);
            case;
                print_to_file(tprint("Unhandled message: %\n", value.str));
                print_to_file(message_str);
        }
    }
}

on_initialize :: (json : JSON_Value) {
    id_obj, ok := table_find(json.object, "id");
    if !ok {
        print_to_file("Unable to find key id in request");
        return;
    }
    id : string;
    if id_obj.type == {
        case .NUMBER;
            id = tprint("%", id_obj.number);
        case .STRING;
            id = tprint("%", id_obj.str);
    }
    
    
    part_1 :: #string JSON
{"jsonrpc":"2.0","id":
JSON;

    reply :: #string JSON
,"result":{"capabilities": {"definitionProvider":true},"serverInfo":{"name":"jai_lsp","version":"0.0.1"}}}
JSON;

    builder : String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    append(*builder, part_1);
    append(*builder, id);
    append(*builder, reply);

    result := builder_to_string(*builder);
    defer free(result);

    answer(result);
}

on_shutdown :: (json : JSON_Value) {
    shutdown_received = true;
}


answer :: (reply: string) {
    write := tprint("Content-Length: %\r\n\r\n%", reply.count, reply);
    // print_to_file(write);
    print("%", write);
}

print_to_file :: (str: string) {
    file := file_open("log.log", true, true);
    file_write(*file, str);
    file_close(*file);
}

shutdown_received := false;

main :: () {
    log_list: [..]string;

    should_quit := false;

    file := file_open("log.log", true, false);
    file_close(*file);

    while !should_quit {
        reset_temporary_storage();

        // Read length
        buffer : [1024] u8;
        bytes_read := read(STDIN_FILENO, buffer.data, buffer.count - 1);
        str := to_string(buffer.data, bytes_read);
        // print_to_file(str);
        split_msg := split(str, ":");
        if split_msg[0] != "Content-Length" {
            print_to_file("Expected length message, got:\n");
            print_to_file(split_msg[0]);
            break;
        }

        nb_bytes, success := parse_int(*split_msg[1], u32);
        // print_to_file(tprint("Reading notification of length %\n", nb_bytes));
        if !success {
            print_to_file("Unable to parse string as int: ");
            print_to_file(split_msg[1]);
            break;
        }

        req_buffer := talloc(nb_bytes);
        bytes_read = read(STDIN_FILENO, req_buffer, nb_bytes);
        assert(bytes_read == nb_bytes);

        req_str := to_string(req_buffer, bytes_read);
        // print_to_file(req_str);
        // print_to_file("\n");

        message_received(req_str);
    }
}


