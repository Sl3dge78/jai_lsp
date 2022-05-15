# JAI_LSP

A basic LSP server for jai. 

Checkout the clients:
- [VSCode](https://github.com/Sl3dge78/jai-lsp-vscode)

## USAGE
- Tell your client to start the binary (```jai_lsp``` or ```jai_lsp.exe```)
- You need to tell jai_lsp which file you are building with : 
- If you are using a metaprogram, you need to call a function during your message loop. There will be a function pointer to it in the build options in user_data_u64. This metaprogram is a copy paste of Default_Metaprogram.jai but with a few additions to hook into your build.
Here's its definition :
```lsp_message :: (message : *Message)```

Here's a full example:
``` 
#run build();

build :: () {
    set_build_options_dc( .{do_output = false} );
    w := compiler_create_workspace("test program");
    
    options := get_build_options();
    options.output_type = .EXECUTABLE;
    
    lsp_message : (message : *Message);
    is_lsp := false;
    if options.user_data_u64 {
        lsp_message = << cast(*(*Message)) options.user_data_u64;  
        is_lsp = true;
    }

    set_build_options(options, w);
    compiler_begin_intercept(w);
    add_build_file("main.jai", w);
    while true {
        msg := compiler_wait_for_message();
        if !msg continue;
        if msg.kind == .COMPLETE break;
        
        if is_lsp {
            lsp_message(msg);
        }
        
    }
    compiler_end_intercept(w);
}
``` 

### Status

- [ ] Go to definition. 
    - [x] Variables, Types, Procedures.
    - [ ] #import
- [ ] Hover support.
- [ ] Autocomplete.
    - [ ] Structs members.
    - [ ] Top level procedures.
