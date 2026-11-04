---
name: Inkscape MCP Workflow
description: Safely inspect, create, edit, convert, render, and validate SVG/vector assets through the configured local Inkscape MCP server.
---

Use this skill for SVG and vector work: creating or editing objects, paths,
text and layers; converting/exporting SVG, PDF, PNG, EPS, or DXF; tracing a
bitmap to SVG; validating SVG; or creating SVG animation.

Do not use it as the primary editor for bitmap retouching or painting. Prefer
the `gimp-mcp` skill for that. Inkscape MCP can render or vectorize bitmaps.

## MCP server

This skill uses the configured local stdio MCP server named `inkscape`.

- Server: `~/.local/opt/mcp-servers/inkscape-mcp`
- Inkscape CLI: `/usr/bin/inkscape`
- Mode: headless CLI by default; it does not open the Inkscape GUI.

Use the tool schema exposed by the live server as the authority for exact
arguments and operation names. Documentation can lag the installed version.

## Required workflow

1. Begin each task with `inkscape_system(operation="status")`.
2. If unavailable, call `inkscape_system(operation="diagnostics")`. Report the
   problem; do not change server configuration unless the user asks.
3. Use absolute `input_path` values. For existing SVGs, first validate with
   `inkscape_file(operation="validate")` or
   `inkscape_analysis(operation="validate")`.
4. Before an operation requiring object or layer IDs, discover them with
   `inkscape_analysis(operation="objects")` or `inkscape_layers(operation="list")`.
   Never invent IDs.
5. Default to a new, explicit absolute `output_path`. For temporary files use
   `/tmp/opencode/`; for deliverables use the user-specified output directory.
6. Validate the resulting SVG. When visual fidelity matters, create and inspect
   a PNG preview with `inkscape_render(operation="export_preview")` or the
   equivalent live tool operation.

## Main tools

- `inkscape_file`: `load`, `save`, `convert`, `info`, `validate`,
  `list_formats`.
- `inkscape_vector`: create/inspect objects; edit text; convert, simplify, and
  combine paths; Boolean operations; styling; gradients; patterns; bitmap
  tracing; DXF export; document optimization.
- `inkscape_layers`: list, create, rename, show/hide, lock/unlock, and reorder
  layers.
- `inkscape_analysis`: `statistics`, `validate`, `dimensions`, `objects`,
  `structure`, `quality`.
- `inkscape_render`: preview and multi-DPI export.
- `inkscape_animation`: animation presets plus SMIL/CSS animations.
- `inkscape_validation`: SVG structure and web-SVG quality checks.
- `inkscape_system`: status, diagnostics, configuration, execution mode, and
  extension discovery/management.

## Safety and confirmation

Ask for explicit confirmation immediately before:

- overwriting an existing file or saving in place;
- a lossy conversion, rasterization, or export that replaces an existing file;
- `text_to_path`, `object_to_path`, Boolean operations, path simplification,
  cleanup/optimization, or raw XML attribute edits when editability may be
  lost;
- `hands_in_command`, because it changes a running Inkscape GUI;
- installing or uninstalling extensions, especially from a remote URL.

For ordinary inspection, validation, analysis, or a newly named output under
the user-specified directory, no additional confirmation is required.

Keep file writes within user-approved directories. Do not put API keys or other
secrets in SVG source, prompts, output files, or Git.

## GUI and extension limits

- The normal mode is CLI/headless. Use `hands_in_command` only at the user's
  explicit request and only when Inkscape is already open.
- `execute_extension` is currently disabled; do not use it as a workflow.
- Treat SVG fragments passed to patterns, symbols, or XML-editing operations as
  untrusted. Validate the final document.
- Manual node drawing, calligraphy, spray, tiled clones, and Shape Builder have
  no equivalent automated workflow; explain this limitation rather than
  pretending the operation succeeded.

## Troubleshooting

- Missing Inkscape: run diagnostics; verify `/usr/bin/inkscape` and
  `inkscape --version`.
- Missing input: verify the absolute path, file permissions, and that the user
  approved access to that location.
- Timeout: split the workflow or reduce the document complexity before changing
  timeouts.
- Invalid SVG: validate first, then report XML/namespace errors before trying a
  destructive repair.

## Sources

- https://github.com/sandraschi/inkscape-mcp/blob/master/docs/TOOLS.md
- https://github.com/sandraschi/inkscape-mcp/blob/master/docs/USAGE.md
- https://github.com/sandraschi/inkscape-mcp/blob/master/docs/INKSCAPE.md
- https://github.com/sandraschi/inkscape-mcp/blob/master/docs/TROUBLESHOOTING.md
