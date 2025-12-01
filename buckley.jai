#import "Basic";
#import "File";
#import "File_Utilities";
#import "Print_Vars";
String :: #import "String";
using String;

//
// Globals
//

verbose_mode := false;
watch_mode   := false;

main :: () {
    // Process arguments
    {
        cli_args := get_command_line_arguments();
        for cli_args {
            // Help text
            if equal(it, "-h") || equal(it, "--help") {
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

    visitor :: (info : *File_Visit_Info, template_file_paths : *[..] string) {
		path, basename, ext := path_decomp (info.full_name);

		if equal(ext, "buckley-template") {
            array_add(template_file_paths, info.full_name);
		}
        // TODO: probably aggregate all of the value files into a table here.
	}

    template_file_paths : [..] string;
    visit_files(".", true, *template_file_paths, visitor);
    
    print_vars(template_file_paths);

    for template_file_path: template_file_paths {
        if !file_exists(template_file_path) {
            if verbose_mode {
                print("ERROR: unable to find template file at \"%\". Are you sure the pathing is correct?", template_file_path);
                cwd := get_working_directory();
                print("Current working directory of buckley executable: %\n", cwd);
            }
            exit(1);
        }

        final_output_builder : String_Builder;
        init_string_builder(*final_output_builder);

        template_file_string := read_entire_file(template_file_path);
        template_file_lines  := split(template_file_string, "\n");

        // The main idea here is to iterate over each line in the template file and
        // simply copy over each line into a string builder of the final html. However, if we find
        // the character combo {{ then we save all of the characters until we find a
        // corresponding }}. We do this by passing a rolling window of 2 characters
        // over each line as we process. This parsed string will then be used to find
        // an equivalent .buckley-value file. For example, if we encounter {{head}},
        // we will look for a head.buckley-value file. We will then copy the lines over
        // in place from the value file to the output file instead of the template line.
        for line: template_file_lines {
            line_number := it_index + 1;
            line_has_delimiter := false;
            delimiter_name : string;
            
            // Pass a rolling window of two characters over the line to see if it has {{
            i: int = 0;
            while i < line.count - 2 {
                defer i += 1;

                window := slice(line, i, 2);

                // This line has a template delimeter.
                if equal(window, "{{") {
                    line_has_delimiter = true;
                    print("Encountered template delimeter on line %!\n", line_number);

                    // Jump the window 2 characters forward so now we're looking at the actual name inside the curlies.
                    // {{head}}    {{head}}
                    // ^        ->   ^
                    // i             i
                    i += 2;

                    // Iterate over the name until you hit the ending curlies.
                    j := i;
                    window = slice(line, j, 2);
                    while !equal(window, "}}") {
                        j += 1;
                        window = slice(line, j, 2);
                    }

                    delimiter_name = trim(slice(line, i, j - i));
                }
            }

            if line_has_delimiter {
                value_file_path := tprint("%.buckley-value", delimiter_name);

                // First find the file that contains the value to add to the output.
                // TODO: Preloading all of these into a table or something is probably better?
                if !file_exists(value_file_path) {
                    if verbose_mode {
                        print("ERROR: unable to find value file at \"%\". Are you sure the pathing is correct?", value_file_path);
                        cwd := get_working_directory();
                        print("Current working directory of buckley executable: %\n", cwd);
                    }
                    exit(1);
                }

                value_file_string := read_entire_file(value_file_path);
                value_file_lines  := split(value_file_string, "\n");

                // Then simply add the lines of the value file to the final output.
                for value_line: value_file_lines {
                    append(*final_output_builder, value_line);
                    append(*final_output_builder, "\n");
                }
            } else {
                // print("Didn't find a delimiter on line %, so just adding this line into the output...\n", line_number);
                append(*final_output_builder, line);
                append(*final_output_builder, "\n");
            }
        }

        // Finally, write the output builder to the output file.
        _path, basename := path_decomp(template_file_path);
        print_vars(basename);
        output_path := tprint("%.html", basename);
        write_succeeded := write_entire_file(output_path, *final_output_builder);
    }
}