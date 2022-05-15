# JAI LSP

A basic LSP server for jai. 

## Usage
- Extract the released zip in a folder.
- Tell your client to call the jai_lsp binary. If the binary is not in your path, you will need to provide the full path to the binary. You also nee to provide the file you build as an argument with `-build_file`. This path can be absolute or relative to the caller's working directory.
Here's an example call : `jai_lsp -build_file ~/program/build.jai`. 
- If you are using a metaprogram, you need to call a function during your message loop. There will be a function pointer to it in the build options in `user_data_u64`. Here's the function's definition : ```lsp_message :: (message : *Message)```
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

### VSCode
Please use the [accompanying extension](https://github.com/Sl3dge78/jai-lsp-vscode)  

### VIM COC :
Here's an example config file `:CocConfig`:
```
{
    "languageserver": {
        "jai": {
            "command" : "/bin/jai_lsp",
                "args": [
                    "-build_file",
                    "build.jai"
                ],
            "filetypes":["jai"]
        }
    }
}
```

### Other IDEs


### Status

- [ ] Go to definition. 
    - [x] Variables, Types, Procedures.
    - [ ] #import
- [ ] Hover support.
- [ ] Autocomplete.
    - [ ] Structs members.
    - [ ] Top level procedures.


### Images

![goto](https://github.com/Sl3dge78/jai_lsp/blob/main/images/goto.gif?raw=true)

Feel free to ping me on the secret beta discord: @Sl3dge
