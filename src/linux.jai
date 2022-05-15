posix :: #import "POSIX";
LOGGING_FILE_PATH :: "/tmp/jai-lsp.log";

get_temp_path :: () -> string {
    return "/tmp/"; 
}

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
