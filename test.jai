#import "Basic";
#import "jason";
#import "String";
#import "Compiler";
#load "src/request_types.jai";

#run test();

test :: () {
    print("Start\n");

    test_str :: #string JSON
{"jsonrpc":"2.0","id":1,"method":"textDocument/definition","params":{"textDocument":{"uri":"file:///home/sl3dge/work/prog/jai_sandbox/build.jai"},"position":{"line":11,"character":4}}}
JSON;

    print("Requesting\n");
    on_definition_request(test_str);
}

print_to_file :: (str : string) {
    print("%\n", str);
}
