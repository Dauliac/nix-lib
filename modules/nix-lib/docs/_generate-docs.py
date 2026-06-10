#!/usr/bin/env python3
"""Generate markdown documentation from lib metadata and source files.

Usage: generate-docs.py <grammar.so> <metadata.json> <source-dir> <output.md>

Reads metadata JSON, extracts fn bodies from source files using tree-sitter,
and generates complete markdown documentation.
"""

import ctypes
import json
import sys
import os
import textwrap
import re


def load_nix_language(so_path):
    """Load the tree-sitter nix language from a shared library."""
    import tree_sitter

    lib = ctypes.cdll.LoadLibrary(so_path)
    lib.tree_sitter_nix.restype = ctypes.c_void_p
    lang_ptr = lib.tree_sitter_nix()
    return tree_sitter.Language(lang_ptr)


def find_all_fn_bindings(node, source_bytes):
    """Find ALL `fn = ...` and named bindings anywhere in the file."""
    results = []
    _find_all_fn(node, source_bytes, [], results)
    return results


def _find_all_fn(node, source_bytes, context, results):
    """Recursively find fn bindings and named bindings, tracking context path."""
    if node.type == "binding":
        named = [c for c in node.children if c.is_named]
        if len(named) >= 2:
            attrpath_node = named[0]
            value_node = named[1]
            attr_text = source_bytes[
                attrpath_node.start_byte : attrpath_node.end_byte
            ].decode()

            if attr_text == "fn":
                # nix-lib style: fn = <body>;
                body = source_bytes[
                    value_node.start_byte : value_node.end_byte
                ].decode()
                results.append((".".join(context), body))
            else:
                new_context = context + attr_text.split(".")
                # Also record this binding's value as a body
                # (for plain attrset libs like nix/lib/oci.nix)
                body = source_bytes[
                    value_node.start_byte : value_node.end_byte
                ].decode()
                results.append((".".join(new_context), body))
                # Recurse into nested attrsets
                for child in value_node.children:
                    _find_all_fn(child, source_bytes, new_context, results)
                return

    for child in node.children:
        _find_all_fn(child, source_bytes, context, results)


def extract_all_bodies(grammar_path, metadata, source_dir):
    """Extract fn bodies for all libs that have file paths."""
    nix_lang = load_nix_language(grammar_path)
    import tree_sitter

    parser = tree_sitter.Parser(nix_lang)

    file_to_libs = {}
    for lib_name, meta in metadata.items():
        file_path = meta.get("file")
        if file_path:
            file_to_libs.setdefault(file_path, []).append(lib_name)

    bodies = {}

    for file_path, lib_names in file_to_libs.items():
        full_path = os.path.join(source_dir, file_path)
        if not os.path.exists(full_path):
            continue

        with open(full_path, "rb") as f:
            source = f.read()

        tree = parser.parse(source)
        all_fns = find_all_fn_bindings(tree.root_node, source)

        fn_map = {}
        for context_path, body in all_fns:
            fn_map[context_path] = body

        for lib_name in lib_names:
            # Last segment of dotted name (e.g., "oci.mkAutoLabels" -> "mkAutoLabels")
            short_name = lib_name.rsplit(".", 1)[-1]
            candidates = [
                f"nix-lib.lib.{lib_name}",
                lib_name,
                short_name,
            ]
            for candidate in candidates:
                if candidate in fn_map:
                    bodies[lib_name] = fn_map[candidate]
                    break
            else:
                for ctx, body in all_fns:
                    if ctx.endswith(short_name) or ctx.endswith(f".{short_name}"):
                        bodies[lib_name] = body
                        break

    return bodies


# --- Markdown generation ---


def name_to_anchor(name):
    return name.replace(".", "-")


def value_to_nix(v):
    """Pretty-print a JSON value as Nix syntax."""
    if v is None:
        return "null"
    elif isinstance(v, bool):
        return "true" if v else "false"
    elif isinstance(v, int):
        return str(v)
    elif isinstance(v, str):
        return f'"{v}"'
    elif isinstance(v, list):
        inner = " ".join(value_to_nix(x) for x in v)
        return f"[ {inner} ]"
    elif isinstance(v, dict):
        inner = " ".join(f"{k} = {value_to_nix(val)};" for k, val in v.items())
        return f"{{ {inner} }}"
    else:
        return str(v)


def args_to_string(meta, fn_body):
    """Extract function arguments display string.

    Priority:
    1. fnSignature (computed at Nix eval time from builtins.functionArgs)
    2. fn body source (tree-sitter extraction)
    3. test args (fallback)
    """
    # Use pre-computed signature from Nix eval if available
    fn_sig = meta.get("fnSignature")
    if fn_sig:
        return fn_sig

    if fn_body:
        # Check if body starts with a set pattern { ... }:
        stripped = fn_body.lstrip()
        if stripped.startswith("{"):
            # Extract the formals part: { a, b, ... }
            end_idx = _find_matching_colon(stripped)
            if end_idx is not None:
                formals = stripped[:end_idx].strip()
                return dedent_body(formals)
        else:
            # Curried: extract arg name before ':'
            colon_idx = stripped.find(":")
            if colon_idx > 0:
                arg = stripped[:colon_idx].strip()
                if re.match(r"^[a-zA-Z_][a-zA-Z0-9_'-]*$", arg):
                    return arg

    # Fallback: infer from test args
    tests = meta.get("tests", {})
    if tests:
        first_test = next(iter(tests.values()))
        args = first_test.get("args", {})
        if args and isinstance(args, dict):
            arg_names = list(args.keys())
            if len(arg_names) == 1 and not isinstance(args[arg_names[0]], dict):
                return " -> ".join(arg_names)
            else:
                return " -> ".join(arg_names)

    return None


def _find_matching_colon(s):
    """Find the position just BEFORE ':' that ends a set-pattern formals.

    Returns the index up to and including '}', so the ':' is excluded.
    """
    depth = 0
    for i, c in enumerate(s):
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    return None


def dedent_body(body):
    """Dedent a multiline function body for clean display."""
    lines = body.split("\n")
    if len(lines) <= 1:
        return body
    # Dedent all lines relative to minimum indentation
    return textwrap.dedent(body).strip()


def tests_to_markdown(tests):
    """Render test cases as a collapsible markdown table."""
    if not tests:
        return ""

    test_names = sorted(tests.keys())
    rows = []
    for name in test_names:
        t = tests[name]
        args_str = value_to_nix(t.get("args", {}))
        expected = t.get("expected")
        expected_str = value_to_nix(expected) if expected is not None else "*(assertions)*"
        rows.append(f"| {name} | `{args_str}` | `{expected_str}` |")

    return f"""
<details><summary><strong>Tests ({len(test_names)})</strong></summary>

| Name | Input | Expected |
|---|---|---|
{chr(10).join(rows)}

</details>
"""


def lib_to_markdown(heading_level, name, meta, body):
    """Generate markdown for a single lib function."""
    anchor = name_to_anchor(name)
    heading = "#" * heading_level

    visible_str = "" if meta.get("visible", True) else " *(private)*"
    desc = meta.get("description", "No description")

    sections = []
    sections.append(f"{heading} `{name}` {{#{anchor}}}{visible_str}\n")

    # Arguments
    args_str = args_to_string(meta, body)
    if args_str:
        sections.append(f"**Arguments:**\n```nix\n{args_str}\n```\n")

    # Type
    type_val = meta.get("type")
    if type_val:
        sections.append(f"**Type:** `{type_val}`\n")

    # Description
    sections.append(f"{desc}\n")

    # Source
    file_path = meta.get("file")
    if file_path:
        sections.append(f"**Source:** [{file_path}]({file_path})\n")

    # Example
    example = meta.get("example")
    if example:
        sections.append(f"**Example:**\n```nix\n{example}\n```\n")

    # Implementation body
    if body:
        dedented = dedent_body(body)
        sections.append(
            f"<details><summary><strong>Implementation</strong></summary>\n\n"
            f"```nix\n{dedented}\n```\n\n</details>\n"
        )

    # Tests
    tests_md = tests_to_markdown(meta.get("tests", {}))
    if tests_md:
        sections.append(tests_md)

    return "\n".join(sections) + "\n"


def build_namespace_tree(metadata):
    """Build a tree of namespaces from flat lib names."""
    tree = {}
    for name in sorted(metadata.keys()):
        parts = name.split(".")
        ns_parts = parts[:-1]  # All but the last segment

        node = tree
        for segment in ns_parts:
            if segment not in node:
                node[segment] = {}
            node = node[segment]

        if "__libs" not in node:
            node["__libs"] = []
        node["__libs"].append(name)

    return tree


def render_namespace_tree(tree, metadata, bodies, lib_level):
    """Render a namespace tree to markdown with hierarchical headings."""
    output = []

    # Render libs at this level
    for lib_name in tree.get("__libs", []):
        meta = metadata[lib_name]
        body = bodies.get(lib_name)
        output.append(lib_to_markdown(lib_level, lib_name, meta, body))

    # Render sub-namespaces
    sub_keys = sorted(k for k in tree.keys() if k != "__libs")
    ns_heading = "#" * lib_level
    for key in sub_keys:
        output.append(f"{ns_heading} {key}\n\n")
        output.append(render_namespace_tree(tree[key], metadata, bodies, lib_level + 1))

    return "".join(output)


def _render_index_tree(tree, metadata, depth):
    """Render a hierarchical index from the namespace tree."""
    indent = "  " * depth
    parts = []

    # Render libs at this level
    for lib_name in tree.get("__libs", []):
        anchor = name_to_anchor(lib_name)
        meta = metadata[lib_name]
        file_link = (
            f" ([source]({meta['file']}))" if meta.get("file") else ""
        )
        parts.append(f"{indent}- [`{lib_name}`](#{anchor}){file_link}\n")

    # Render sub-namespaces
    sub_keys = sorted(k for k in tree.keys() if k != "__libs")
    for key in sub_keys:
        parts.append(f"{indent}- **{key}**\n")
        parts.append(_render_index_tree(tree[key], metadata, depth + 1))

    return "".join(parts)


def generate_markdown(metadata, bodies, show_title=True, show_index=True, heading_level=3):
    """Generate the full markdown document."""
    all_names = sorted(metadata.keys())

    parts = []

    if show_title:
        parts.append(f"# nix-lib API Reference\n\n")
        parts.append(f"Generated documentation for all defined library functions.\n\n")
        parts.append(f"**Total libs:** {len(all_names)}\n\n")

    if show_index:
        parts.append("## Index\n\n")
        ns_tree = build_namespace_tree(metadata)
        parts.append(_render_index_tree(ns_tree, metadata, 0))
        parts.append("\n")

    # Build namespace tree and render
    ns_tree = build_namespace_tree(metadata)
    parts.append(render_namespace_tree(ns_tree, metadata, bodies, heading_level))

    return "".join(parts)


def main():
    if len(sys.argv) != 5:
        print(
            f"Usage: {sys.argv[0]} <grammar.so> <metadata.json> <source-dir> <output.md>",
            file=sys.stderr,
        )
        sys.exit(1)

    grammar_path = sys.argv[1]
    metadata_path = sys.argv[2]
    source_dir = sys.argv[3]
    output_path = sys.argv[4]

    with open(metadata_path) as f:
        data = json.load(f)

    # Separate options from metadata
    options = data.pop("__options", {})
    metadata = data

    show_title = options.get("showTitle", True)
    show_index = options.get("showIndex", True)
    heading_level = options.get("headingLevel", 3)

    # Extract fn bodies from source files
    bodies = extract_all_bodies(grammar_path, metadata, source_dir)

    # Generate markdown
    md = generate_markdown(metadata, bodies, show_title, show_index, heading_level)

    with open(output_path, "w") as f:
        f.write(md)

    print(f"Generated docs for {len(metadata)} libs ({len(bodies)} bodies extracted)")


if __name__ == "__main__":
    main()
