#import "Basic";
#import "File";

client_log :: (message : string, data : *void, info : Log_Info) {
    log := tprint("{\"jsonrpc\":\"2.0\",\"method\":\"window/logMessage\",\"params\":{\"type\":3,\"message\":\"%\"}}", message);
    write := tprint("Content-Length: %\r\n\r\n%", log.count, log);
    write_string(write);
}

file_logger :: (message : string, data :*void, info : Log_Info) {
    if (info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE) return;
    if (info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE) return;

    file := file_open(LOGGING_FILE_PATH, true, keep_existing_content = true);
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


log_verbose :: (format_string: string, args : ..Any) {
    log(format_string, ..args, flags = .VERBOSE_ONLY);
}