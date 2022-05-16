posix :: #import "POSIX";

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
    buffer : [0xFFFF] u8;
    header_read := stdin_read(buffer);
    header := to_string(buffer.data, header_read);
    body_size, header_size, success := parse_header(header);
    if !success {
        return "", false;
    }
    log_verbose("Header: %\n", header);

    // Body
    body_buffer : []u8 = buffer;
    body_buffer.data += header_size;
    body_buffer.count -= header_size;

    // Sometimes, the first read will catch both the header and the content.
    // We don't re-read in that case.
    body_read := 0;
    if header_size == header_read {
        body_read = stdin_read(body_buffer);
    }

    if !success {
        log_error("while reading from stdin\n", body_size, body_read);
        return "", false;
    }
    if body_size != header_read + body_read - header_size {
        log_error("Expected % bytes, got %.\n", body_size, body_read);
        return "", false;
    }

    body := to_string(body_buffer.data, body_size);
    log_verbose("Body: %\n", body);
    return body, true;
}
