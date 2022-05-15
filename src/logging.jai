#import "Basic";
#import "File";

client_log :: (message : string, data : *void, info : Log_Info) {
    if (info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE) return;
    if (info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE) return;

    sent_log : LSP_LogMessage = .{};
    sent_log.params.message = message;

    if message.data[message.count - 1] == #char "\n" then sent_log.params.message.count -= 1;

    if info.common_flags == { 
        case .ERROR;
            sent_log.params.type = 1;
        case .WARNING;
            sent_log.params.type = 2;
        case .VERBOSE_ONLY;
            sent_log.params.type = 4;
        case;
            sent_log.params.type = 3;
    } 
    //file_logger(message, data, info);    
    lsp_send_object(sent_log);
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