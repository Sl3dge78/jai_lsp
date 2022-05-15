#import "Compiler";
String :: #import "String";
#import "Basic";
#import "Metaprogram_Plugins";

#run default_metaprogram();

// --------
// Lsp and stuff

Lsp_Mode :: enum {
    LOCATE;
};

mode : Lsp_Mode;
file : string;
line : int;
col : int;
found : bool = false;

lsp_parse_args :: (options : []string, cursor: int) {
    s := options[cursor];
    if s == {
        case "-locate";
            mode = .LOCATE;
            ok : bool;
            file = options[cursor + 1];
            line, ok = String.parse_int(*options[cursor + 2]);
            if !ok {
                print("ERROR|Couldn't parse line.");
            }
            col, ok = String.parse_int(*options[cursor + 3]);
            if !ok {
                print("ERROR|Couldn't parse column.");
            }
            //log("SEARCHING%:%:%\n", file, line, col);
    };
}

check_location :: (file: string, line : int, char : int, location : Code_Node.Location) -> bool {
    if !location.enclosing_load {
        return false;
    }

    loc_file := location.enclosing_load.fully_pathed_filename;
    // print("%\n", loc_file);
    if(file == loc_file) {
        // print("%:%:%\n", loc_file, location.l0, location.c0);
        if line >= location.l0 && line <= location.l1 {
            if col >= location.c0 && col <= location.c1 {
                // print("%:%:%\n", loc_file, location.l0, location.c0);
                return true;
            }
        }
    }
    return false;
}

// -------
// DEFAULT_METAPROGRAM.JAI

is_absolute_path :: (path: string) -> bool { // This routine is probably not as correct as we'd like. We'd like to put in a better one! But maybe we will stop doing the cwd thing, or do it differently; hard to say.
    if !path return false;

    if path[0] == #char "/" return true;   // Backslashes have not been converted to forward slashes by this point.
    if path[0] == #char "\\" return true;  // Backslashes have not been converted to forward slashes by this point.
    if (path.count > 2) && (path[1] == #char ":") && (OS == .WINDOWS) return true;  // Drive letter stuff. Probably incomplete.
    
    if path.count >= 3 {
        // @Robustness: Check for a drive letter in character 0?  Anything else?
        if path[1] == #char ":" return true;
    }

    return false;
}

// This is just a copy pasted Default_Metaprogram, with 2 calls added.
// 1. lsp_init    : before compiler_begin_intercept.
// 2. lsp_message : during the message loop. 
default_metaprogram :: () {
    lsp_message :: (message : *Message) {
        if message.kind == .TYPECHECKED {
            if found return;
            tc := cast(*Message_Typechecked) message;

            for tc.all {
                // print("EXPR: % - %\n", it.expression.kind, it.expression.location.enclosing_load.fully_pathed_filename);
                for sub_expr : it.subexpressions {
                    if check_location(file, line, col, sub_expr.location) {
                        // print("Found match.\nKind:%\n", sub_expr.kind);
                        if sub_expr.kind == {
                            // @Todo: #import and #load should open the corresponding file.
                            case .IDENT;
                                ident := cast(*Code_Ident)sub_expr;
                                decl := ident.resolved_declaration;
                                l1 := decl.location.l1;
                                c1 := decl.location.c1;
                                log("Kind:%\n", decl.expression.kind);
                                if decl.expression.kind == .PROCEDURE_HEADER {
                                    proc := cast(*Code_Procedure_Header) decl.expression;
                                    for proc.returns {
                                        if it.location.l1 >= l1 {
                                            l1 = it.location.l1;
                                            c1 = it.location.c1;
                                        }
                                    }
                                }
                                if decl.expression.kind == .STRUCT {
                                    structure := cast(*Code_Struct) decl.expression;
                                    if structure.block.location.l1 >= l1 {
                                        l1 = structure.block.location.l1;
                                        c1 = structure.block.location.c1;
                                    }
                                    l1 += 1; // Closing brace @Hack
                                }
                                print("OK|%|%|%|%|%\n", decl.location.enclosing_load.fully_pathed_filename, decl.location.l0, decl.location.c0, l1, c1);
                                
                                found = true;
                                return;
                        };
                        break;
                    }
                }
            }
        }

        if message.kind == .COMPLETE {
            complete := cast(*Message_Complete) message;
            if complete.error_code == {
                case .NONE;
                    log("COMPILE_OK\n");
                case;
                    log("COMPILE_NOK\n");
            };
        }   
    }

    
    w := compiler_create_workspace("Target Program");
    if !w {
        log_error("Workspace creation failed.\n");
        return;
    }

    options := get_build_options(w);

    do_initial_cwd   := true;
    check_bindings   := true;
    do_check         := true;  // Import modules/Check if true.

    args := options.compile_time_command_line;

    if verbose  print("Arguments:   %\n", args);

    printed_help := false;

    files:         [..] string;
    add_strings:   [..] string;
    run_strings:   [..] string;
    modules_paths: [..] string;

    plugin_names:  [..] string;
    plugin_names2: [..] string;
    
    user_arguments: [..] string;
    
    index := 0;

    while index < args.count {
        defer index += 1;

        it := args[index];
        if it == {
          case "-plugin"; #through;
          case "-plug";
            if index >= args.count-1 {
                break;  // Silent. We'll catch this the second time around.
            }
            
            index += 1;
            array_add(*plugin_names, args[index]);

          // We need to know about no_check bindings in pass 1 because that is now we determine if that plugin is in the set! Argh.
          case "-no_check";           do_check = false;
          case "-no_check_bindings";  check_bindings = false;
          case "-check_bindings";     check_bindings = true; // Not necessary anymore since we changed the default. I just left it in for backwards compatibility. -rluba, 2022-03-23
          case "--";  // Do not process anything after --!
            break;
        }
    }

    if do_check {
        if check_bindings array_add(*plugin_names, "Check");
        else              array_add(*plugin_names, "Check(CHECK_BINDINGS=false)");
    }
        
    // Now that we know what the plugins are, init them.
    init_plugins(plugin_names, *plugins, w);

    //
    // Pass 2: Handle all the various options, or delegate them to plugins
    // if we do not handle them.
    //
    index = 0;  // Starting over!
    got_double_dash := false;
    
    while index < args.count {
        defer index += 1;

        it := args[index];
        
        if got_double_dash {
            array_add(*user_arguments, it);
            continue;
        }
        
        if !it continue;  // @Temporary?

        if it[0] == #char "-" {
            if it == {
              case "--";
                // Everything after this is user arguments.
                got_double_dash = true;
                
              case "-release";
                set_optimization_level(*options, 2, 0);
                options.stack_trace = false;
                
              case "-quiet";
                options.text_output_flags = 0;

              case "-x64";
                options.backend = .X64;
              case "-llvm";
                options.backend = .LLVM;

              case "-no_cwd";
                do_initial_cwd = false;
               
              case "-no_dce";
                options.dead_code_elimination = .NONE;

              case "-msvc_format";
                options.use_visual_studio_message_format = true;
                
              case "-no_check";           // nop; we handled this in pass 1.
              case "-no_check_bindings";  // nop; we handled this in pass 1.
              case "-check_bindings";     // nop; we handled this in pass 1.

              case "-version";
                s := compiler_get_version_info(null);
                print("Version: %.\n", s);
                printed_help = true;

              case "-add";
                
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to -add.\n");
                    printed_help = true;
                    break;
                }

                index += 1;
                array_add(*add_strings, args[index]);

              case "-run";
                
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to -run.\n");
                    printed_help = true;
                    break;
                }

                index += 1;
                array_add(*run_strings, args[index]);

              case "-plugin"; #through;
              case "-plug";
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to %.\n", it);
                    printed_help = true;
                    break;
                }

                index += 1;
                array_add(*plugin_names2, args[index]);  // So we can check this later.

              case "-help"; #through;
              case "-?";
                log("%", HELP_STRING);

                printed_help = true;

              case "-debugger";
                options.interactive_bytecode_debugger = true;

              case "-import_dir";
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to -import_dir.\n");
                    printed_help = true;
                    break;
                }

                index += 1;
                array_add(*modules_paths, args[index]);
        
              case "-no_color";
                options.use_ansi_color = false;

              case "-verbose";
                verbose = true;
                
              case;
                handled := false;
                for p, plugin_index: plugins {
                    if !p.handle_one_option continue;

                    new_index := p.handle_one_option(p, args, index);
                    if new_index > index {
                        index = new_index - 1;  // -1 Because it will be incremented at the bottom of the loop.
                        handled = true;
                        break;
                    } else if new_index < index { 
                        log_error("Plugin % decreased argument index. That is illegal!\n", plugin_names[plugin_index]);
                        exit(1);
                    }
                }

                if handled continue;
                
                log_error("Unkown argument '%'.\nExiting.\n", it);
                exit(1);
            }
            
            continue;
        }
        
        // If we got here, it's a pain file. Add it to the array.
        array_add(*files, it);
    }

    if !(files || add_strings || run_strings || printed_help) {
        if !printed_help  log("You need to provide an argument telling the compiler what to compile!  Sorry.\n");
        exit(1);
    }

    if do_check { // @Copypasta, just to make the plugin name arrays come out the same. This is getting silly!
        if check_bindings array_add(*plugin_names2, "Check");
        else              array_add(*plugin_names2, "Check(CHECK_BINDINGS=false)");
    }
        
    plugins_match := true;
    if plugin_names.count != plugin_names2.count  plugins_match = false;
    else {
        for plugin_names if it != plugin_names2[it_index] plugins_match = false;
    }

    if !plugins_match {
        log_error("Plugins in pass 1 and pass 2 do not match, meaning that -plug was used as an argument to another option. This is an error.\n");
        exit(1);
    }
    
    if files {
        basename, path := get_basename_and_path(files[0]);

        old_wd := get_working_directory();

        if basename || path {
            if path {
                // We need to set an absolute output_path or it will no longer be correct if any metaprogram (including us) changes the working directory but doesn't touch the output_path.
                if !is_absolute_path(path) {
                    path = sprint("%/%", old_wd, path);
                }

                options.output_path = path;
            }
            
            if basename  options.output_executable_name = basename;
        }

        if verbose {
            print("Basename: %\n", basename);
            print("Path:     %\n", path);
        }

        // We set the working directory, because relative paths specified in things
        // like #import should not have their meaning depend on where you were when
        // you started the compiler. @Cleanup: Maybe this becomes unnecessary if
        // import works a little differently.
        if do_initial_cwd && path {
            if verbose  print("Changing working directory to '%'.\n", path); 
            set_working_directory(path);
            
            // To set the working directory, we need to change the filenames of all the arguments,
            // if they are relative, otherwise they will now be wrong ... sigh!!
            // The whole reason we are setting directory is, the meaning of the program should not
            // be dependent on where the compiler is when it starts. It should be invariant.
            for * files {
                old_filename := <<it;
                if is_absolute_path(old_filename) continue;
                <<it = sprint("%/%", old_wd, old_filename);
                if verbose  print("... Remapping '%' to '%'.\n", old_filename, <<it);
            }
        }
    }

    if printed_help {
        log("\n\n");
        
        for plugins {
            name := plugin_names[it_index];
            
            if it.log_help {
                log("---- Help for plugin '%': ----\n\n", name);
                it.log_help(it);
                log("\n");
            } else {
                log("---- Plugin '%' provides no help.\n", name);
            }
        }

        if !(files || run_strings) exit(0);
    }
    
    if modules_paths {
        for options.import_path array_add(*modules_paths, it);  // Put these behind whatever the user specified.
        options.import_path = modules_paths;
    }

    options.compile_time_command_line = user_arguments;

    // -- LSP OPTIONS SETUP
    options.output_type = .NO_OUTPUT;
    options.text_output_flags = 0;
    args = options.compile_time_command_line;
    for args {
        if it == "lsp_plugin" {
            lsp_parse_args(args, it_index + 1);
            break;
        }
    }

    func := lsp_message;
    // options.user_data_pointer = xx *func; // For some weird reason user_data_pointer gets overriden but not u64.
    options.user_data_u64 = xx *func;
    
    
    set_build_options(options, w);

    for plugins if it.before_intercept it.before_intercept(it);
    
    compiler_begin_intercept(w);
    

    if verbose {
        print("Input files: %\n", files);
        print("Add strings: %\n", add_strings);
        print("Run strings: %\n", run_strings);
        print("Plugins:     %\n", plugins);
    }
    
    for plugins      if it.add_source it.add_source(it);
    
    for files        add_build_file  (it, w);
    for add_strings  add_build_string(tprint("%;", it), w);
    for run_strings  add_build_string(tprint("#run %;\n", it), w); // run_strings is kind of redundant now! We could remove it.
    
    while true {
        message := compiler_wait_for_message();
        if !message break;
        for plugins if it.message it.message(it, message);       
        lsp_message(message);
        if message.kind == .COMPLETE break;
    }
    compiler_end_intercept(w);

    for plugins if it.finish   it.finish  (it);
    for plugins if it.shutdown it.shutdown(it);
    
    {
        set_build_options_dc(.{do_output=false, write_added_strings=false});
    }

    
}

verbose  := false;
plugins: [..] *Metaprogram_Plugin;

HELP_STRING :: #string DONE
Available Command-Line Arguments:

-x64             Use the x64 backend by default (unless overridden by a metaprogram).
-llvm            Use the LLVM backend by default (unless overridden by a metaprogram).
                     The LLVM backend is the default normally, so this isn't too useful.
-add arg         Add the string 'arg' to the target program as code.
                     Example: -add "MY_VARIABLE :: 42";
-run arg         Start a #run directive that parses and runs 'arg' as code.
                     Example: -run write_string(\"Hello!\n\")
                     (The extra backslashes are the shell's fault.)
-import_dir arg  Add this directory to the list of directories searched by #import. Can be
                     used multiple times.
-debugger        If there is a crash in compile-time execution, drop into the interactive debugger.
-msvc_format     Use Visual Studio's message format for error messages.
-no_color        Disable ANSI terminal coloring in output messages.
-no_dce          Turn off dead code elimination. This is a temporary option,
                     provided because dead code elimination is a new and potentially
                     unstable feature. This will eventually be removed; the preferred way
                     to turn off dead code elimination is via Build_Options.
-no_cwd          Turn off the compiler's initial change of working directory. This is a temporary option,
                     provided because the policy around working directories is new and is still 
                     being worked out. 
-no_check        Do not import modules/Check and run it on the code. The result will be that you won't get
                     augmented error checking for stuff like print() calls. Use this if you want to substitute
                     your own error checking plugin, or for higher speeds in builds known to be good.
-no_check_bindings Disable checking of module bindings when running modules/Check. If modules/Check is not run
                     due to -no_check, this does nothing.
-release         Build a release build, i.e., tell the default metaprogram to disable stack traces and enable optimizations.
-plug name       Import module 'name' into the metaprogram and use it as a plugin.
-verbose         Output some extra information about what this metaprogram is doing.    
-version         Print the version of the compiler.
--               Every argument after -- is ignored by the compiler itself, 
                     and is passed to the metaprogram for its own use.

Any argument not starting with a -, and before --, is the name of a file to compile.

Example:    jai -x64 program.jai -- info for -the compile_time execution

There are also a few very tweaky compiler-front-end options that almost nobody
will ever care about. To see these, do:

            jai --- help

And that's all.
Unlike most contemporary compilers, we don't have a huge number of arcane arguments
to control all kinds of minute things, that you have to spend a long time learning about.
Our philosophy is, it's much more effective to do configuration from code, where
you have a great deal of precise control over what's happening, options can be expressed
as easy-to-understand data structures, and so forth. To get started, look into Build_Options
in modules/Compiler/Compiler.jai, or look at the how_to program that isn't written yet but
will be eventually.)
DONE
