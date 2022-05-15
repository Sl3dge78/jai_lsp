

LSP_Message :: struct {
    jsonrpc : string = "2.0";
}

LSP_Notification :: struct {
    using base : LSP_Message;
}

LSP_Request :: struct {
    using base : LSP_Message;
    id : u32;
    method : string;
}

LSP_Answer :: struct {
    using base : LSP_Message;
    id : u32;
}

LSP_LogMessage :: struct {
    using notif: LSP_Notification;
    method : string = "window/logMessage";
    params : struct {
        type : int;
        message: string;
    };
}

LSP_TextDocumentPosition :: struct {
    textDocument : struct {
        uri : string;
    };
    position : Position; 
}

Position :: struct {
    line : s32;
    character : s32;
}

LSP_Location :: struct {
    uri : string;
    range : struct {
        start : Position;
        end : Position;
    };
}

LSP_Request_Initialize :: struct {
    using request : LSP_Request;
    params : struct {
        clientInfo : struct {
            name : string;
            version : string;
        };
    }
}

LSP_Result_Initialize :: struct {
    capabilities : struct {
        definitionProvider : bool = true;
        hoverProvider : bool = true;
    };
    serverInfo : struct {
        name : string = "jai_lsp";
        version : string = VERSION;
    };
    
}

LSP_Request_Definition :: struct {
    using request : LSP_Request;
    params : LSP_TextDocumentPosition;
}

LSP_Request_Hover :: struct {
    using request : LSP_Request;
    params : LSP_TextDocumentPosition;
}

LSP_Hover :: struct {
    contents: string;
    contentFormat:= "markdown";
}