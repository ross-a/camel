package bindgen

import "core:os"
import "core:fmt"
import "core:strings"

export_defines :: proc(data : ^GeneratorData) {
    for node in data.nodes.defines {
        defineName := clean_define_name(node.name, data.options);

        // @fixme fprint of float numbers are pretty badly handled,
        // just has a 10^-3 precision.
        fmt.fprint(fd=data.handle, args={defineName, " :: ", node.value, ";\n"}, sep="");
    }
    fmt.fprint(data.handle, "\n");
}

export_typedefs :: proc(data : ^GeneratorData) {
    for node in data.nodes.typedefs {
      name := clean_pseudo_type_name(node.name, data.options);
      type := clean_type(node.type, data.options);
      if name == type do continue;
      fmt.fprint(fd=data.handle, args={name, " :: ", type, ";\n"}, sep="");

			for edef in data.nodes.enumDefinitions {
				if (strings.compare(strings.to_lower(type), strings.to_lower(edef.name)) == 0) {
					// output all these enum members for ease of use
					for mem in edef.members {
						if (strings.compare(mem.name, "true") != 0 && strings.compare(mem.name, "false") != 0) {
							fmt.fprint(fd=data.handle, args={mem.name, " :: cast(i32) ", type, ".", mem.name, ";\n"}, sep="");
						}
					}
				}
			}
    }
    fmt.fprint(data.handle, "\n");
}

export_enums :: proc(data : ^GeneratorData) {
    for node in data.nodes.enumDefinitions {
        enumName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(fd=data.handle, args={enumName, " :: enum i32 {"}, sep="");

        postfixes : [dynamic]string;
        enumName, postfixes = clean_enum_name_for_prefix_removal(enumName, data.options);

        // Changing the case of postfixes to the enum value one,
        // so that they can be removed.
        enumValueCase := find_case(node.members[0].name);
        for postfix, i in postfixes {
            postfixes[i] = change_case(postfix, enumValueCase);
        }

        // Merging enum value postfixes with postfixes that have been removed from the enum name.
        for postfix in data.options.enumValuePostfixes {
            append(&postfixes, postfix);
        }

        export_enum_members(data, node.members, enumName, postfixes[:]);
        fmt.fprint(data.handle, "};\n");
        fmt.fprint(data.handle, "\n");
    }
}

export_structs :: proc(data : ^GeneratorData) {
  for node in data.nodes.structDefinitions {
    structName := clean_pseudo_type_name(node.name, data.options);

    replacement, found := data.options.typeReplacements[structName];
    if found {
      fmt.fprint(data.handle, structName, " :: ", replacement, ";\n");
    } else {
      fmt.fprint(fd=data.handle, args={structName, " :: struct {"}, sep="");
      export_struct_or_union_members(data, node.members);
      fmt.fprint(data.handle, "};\n");
      fmt.fprint(data.handle, "\n");
    }
	}
}

export_unions :: proc(data : ^GeneratorData) {
    for node in data.nodes.unionDefinitions {
        unionName := clean_pseudo_type_name(node.name, data.options);
        fmt.fprint(fd=data.handle, args={unionName, " :: struct #raw_union {"}, sep="");
        export_struct_or_union_members(data, node.members);
        fmt.fprint(data.handle, "};\n");
        fmt.fprint(data.handle, "\n");
    }
}

export_functions :: proc(data : ^GeneratorData) {
    for node in data.nodes.functionDeclarations {
        functionName := clean_function_name(node.name, data.options);
        fmt.fprint(fd=data.handle, args={"    @(link_name=\"", node.name, "\")\n"}, sep="");
        fmt.fprint(fd=data.handle, args={"    ", functionName, " :: proc("}, sep="");
        parameters := clean_function_parameters(node.parameters, data.options, "    ");
        fmt.fprint(fd=data.handle, args={parameters, ")"}, sep="");
        returnType := clean_type(node.returnType, data.options);
        if len(returnType) > 0 {
          fmt.fprint(fd=data.handle, args={" -> ", returnType}, sep="");
        }
        fmt.fprint(data.handle, " ---;\n");
        fmt.fprint(data.handle, "\n");
    }
}


export_enum_members :: proc(data : ^GeneratorData, members : [dynamic]EnumMember, enumName : string, postfixes : []string) {
    if (len(members) > 0) {
        fmt.fprint(data.handle, "\n");
    }
    for member in members {
        name := clean_enum_value_name(member.name, enumName, postfixes, data.options);
        if len(name) == 0 do continue;
        fmt.fprint(fd=data.handle, args={"    ", name}, sep="");
        if member.hasValue {
          fmt.fprint(fd=data.handle, args={" = ", member.value}, sep="");
        }
        fmt.fprint(data.handle, ",\n");
    }
}

export_struct_or_union_members :: proc(data : ^GeneratorData, members : [dynamic]StructOrUnionMember) {
    if (len(members) > 0) {
        fmt.fprint(data.handle, "\n");
    }
    for member in members {
        type := clean_type(member.type, data.options, "    ");
        name := clean_variable_name(member.name, data.options);
        fmt.fprint(fd=data.handle, args={"    ", name, " : ", type, ",\n"}, sep="");
    }
}
