
win32 :: #import "Windows";
kernel32 :: #foreign_system_library "kernel32";


ReadConsoleA :: (hConsoleHandle: win32.HANDLE, buff : *u8, chars_to_read : s32, chars_read : *s32, lpInputControl := *void) -> win32.BOOL #foreign kernel32;

LOGGING_FILE_PATH :: "D:\\jai-lsp.log";

file_read_line :: (f : File, buffer : [] u8) -> s32 {
    total_read: s32;

    single_len : win32.DWORD;
    while true {
        win32.ReadFile(f.handle, buffer.data + total_read, 1, *single_len);
        if single_len <= 0 continue;

        total_read += 1;
        if (buffer[total_read - 1] == #char "\n") break;
    }
    return total_read;
}

wait_for_message :: () -> string, success : bool {
    stdin : File = ---;
    stdin.handle = win32.GetStdHandle(win32.STD_INPUT_HANDLE);

    // Header
    header_buffer : [1024] u8;
    bytes_read := file_read_line(stdin, header_buffer);
    header := to_string(header_buffer.data, bytes_read);
    body_size, success := parse_header(header);
    if !success {
        return "", false;
    }
    log_verbose("Header: %\n", header);

    // On Windows we get the \r\n before the body. So add 2 to the len.
    body_size += 2;

    // Body
    body_buffer : []u8 = ---;
    body_buffer.data = talloc(body_size);
    body_buffer.count = body_size;

    body_read : s64 = ---;
    success, body_read = file_read(stdin, body_buffer.data, body_buffer.count);
    if !success {
        log_error("while reading from stdin\n", body_size, body_read);
        return "", false;
    }
    if body_read != body_size {
        log_error("Expected % bytes, got %.\n", body_size, body_read);
        return "", false;
    }
    // Skip the \r\n
    body := to_string(body_buffer.data + 2, body_buffer.count - 2);
    
    log_verbose("Body: %\n", body);
    return body, true;
}

// Allocates a temporary string
translate_uri :: (uri : string) -> string {
    file_path := replace(uri, "%3A", ":");
    defer free(file_path);

    sliced := slice(file_path, 8, file_path.count - 8);
    return copy_temporary_string(sliced);
}

start_compilation :: (request : string) -> string {
    // @Hardcoded
    build_file := "D:/Guigui/Work/Prog/jai-lsp-vscode/test_project/build.jai";
    command := tprint("jai -plug lsp_plugin % % --- import_dir %", request, build_file, PLUGIN_SEARCH_PATH);
    log("Starting compilation : %\n", command);
    args := split(command, " ");
    successfully_launched, exit_code, output_string := os_run_command(..args, capture_and_return_output = true);
    defer free(output_string);
    log("%", output_string);
    return copy_temporary_string(output_string);
}