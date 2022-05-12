posix :: #import "POSIX";
TMP_FILE_PATH :: "/tmp/jai-lsp.log";

stdin_read :: (buffer : []u8) -> s32 {
    return posix.read(posix.STDIN_FILENO, buffer.data, buffer.count);
}

// Allocates a temporary string
translate_uri :: (uri : string) -> string {
    sliced := slice(definition_req.params.textDocument.uri, 7, definition_req.params.textDocument.uri.count - 7);
    return copy_temporary_string(sliced);
}
