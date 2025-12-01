#import "Basic";
#import "File";
#import "File_Utilities";
String :: #import "String";
using String;

//
// Globals
//

verbose_mode := false;
watch_mode   := false;
template_file_path : string;
value_file_path    : string;

main :: () {
    // Process arguments
    {
        cli_args := get_command_line_arguments();
        for cli_args {
            if ends_with(it, ".buckley.template") {
                template_file_path = it;
            }
            else if ends_with(it, ".buckley.value") {
                value_file_path = it;
            }
            // Help text
            else if equal(it, "-h") || equal(it, "--help") {
                print("Usage: % [flags]\n", cli_args[0]);
                print("Flags:\n");
                print("  -h, --help     Display this help message\n");
                print("  -v, --verbose  Enable verbose output\n");
                print("  -w, --watch    Enable watch mode, so tailpipe runs on every input html modification\n");
                exit(0);
            }
            else if equal(it, "-v") || equal(it, "--verbose") {
                verbose_mode = true;
            }
            else if equal(it, "-w") || equal(it, "--watch") {
                watch_mode = true;
            }
        }
    }

    // TODO: Find all template files recursively
    if !file_exists(template_file_path) {
        if verbose_mode {
            print("ERROR: unable to find template file at \"%\". Are you sure the pathing is correct?", template_file_path);
            cwd := get_working_directory();
            print("Current working directory of buckley executable: %\n", cwd);
        }
        exit(1);
    }

    template_file_string := read_entire_file(template_file_path);
    template_file_lines  := split(template_file_string, "\n");

    // The main idea here is to iterate over each line in the template file and
    // simply copy over each line into a string builder of the final html. However, if we find
    // the character combo {{ then we save all of the characters until we find a
    // corresponding }}. We do this by passing a rolling window of 2 characters
    // over each line as we process. This parsed string will then be used to find
    // an equivalent .buckley.value file. For example, if we encounter {{head}},
    // we will look for a head.buckley.value file. We will then copy the lines over
    // in place from the value file to the output file instead of the template line.
    for template_file_lines {
        // This line has a template delimeter.
        if contains(it, "{{") {
            print("Encountered template delimeter on line %!\n", it_index + 1);
        }
        // This line does not have a template delimiter.
        else {
            print("Did not encounter a template delimeter on line %. Copying...\n", it_index + 1);
        }
    }
}