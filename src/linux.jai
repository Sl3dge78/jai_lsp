posix :: #import "POSIX";
LOGGING_FILE_PATH :: "/tmp/jai-lsp.log";

stdin_read :: (buffer : []u8) -> s32 {
    return xx posix.read(posix.STDIN_FILENO, buffer.data, cast(u64) buffer.count);
}

// Allocates a temporary string
translate_uri :: (uri : string) -> string {
    sliced := slice(uri, 7, uri.count - 7);
    return copy_temporary_string(sliced);
}

wait_for_message :: () -> string, success : bool {
    header_buffer : [1024] u8;
    bytes_read := stdin_read(header_buffer);
    header := to_string(header_buffer.data, bytes_read);
    body_size, success := parse_header(header);
    if !success {
        return "", false;
    }
    log_verbose("Header: %\n", header);

    // Body
    body_buffer : []u8 = ---;
    body_buffer.data = talloc(body_size);
    body_buffer.count = body_size;

    body_read : s64 = ---;
    body_read = stdin_read(body_buffer);
    if !success {
        log_error("while reading from stdin\n", body_size, body_read);
        return "", false;
    }
    if body_read != body_size {
        log_error("Expected % bytes, got %.\n", body_size, body_read);
        return "", false;
    }
    
    body := to_string(body_buffer.data, body_buffer.count);
    
    log_verbose("Body: %\n", body);
    return body, true;
}

start_command_and_get_output :: (command : string) -> string {
    c_str := to_c_string(command);
    defer free(c_str);

    handle := posix.popen(c_str, "r");
    buffer : [1024] u8;
    nb_read := posix.fread(buffer.data, 1, buffer.count, handle); // Read as much as we can until process closes
    output_string := to_string(buffer);
    output_string.count = xx nb_read;
    log_verbose("%\n", output_string);    
    posix.pclose(handle);
    return copy_temporary_string(output_string);
}
