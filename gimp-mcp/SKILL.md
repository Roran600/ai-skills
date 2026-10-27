---
name: GIMP MCP Editor
description: Safely inspect, edit, and export GIMP images through the configured gimp-mcp server.
---

Use this skill for requests to inspect, create, edit, transform, export, or verify images in the user's open GIMP session.

## MCP server

This skill uses the configured local MCP server named `gimp-mcp`.

- Repository: <https://github.com/maorcc/gimp-mcp>
- Transport: OpenCode starts `gimp_mcp_server.py` over stdio; it connects to the GIMP plugin on `localhost:9877`.

## Connection and scope

1. Call `gimp-mcp.check_server` before the first GIMP operation in a task.
2. If it is unavailable, tell the user to open GIMP and choose **Tools → MCP → Start MCP Server**. Do not start or restart GIMP yourself unless the user explicitly asks.
3. Work only with the image, layer, and output path the user specifies. If a target is ambiguous, inspect with `gimp-mcp.list_images` and ask a concise question.
4. Prefer the dedicated, typed GIMP MCP tools. Use `call_api` only when no dedicated tool exists and the user has explicitly requested that operation.

## Safe editing workflow

1. Inspect the target with `list_images`, `get_image_metadata`, and, when visual assessment is needed, `get_state_snapshot`.
2. Before a destructive edit, duplicate the target layer when that preserves the user's intended result. Explain when duplication is not practical.
3. Make the smallest requested change.
4. Call `get_state_snapshot` or `get_image_metadata` to verify the result.
5. State exactly what was changed and whether verification succeeded.

## Confirmation requirements

Ask for explicit confirmation immediately before:

- overwriting or saving an existing file;
- exporting outside a user-specified output directory;
- closing an image, flattening or merging layers, deleting a layer, or applying an irreversible edit without a safe duplicate;
- invoking `call_api` with arbitrary Python code.

Normal non-destructive edits, snapshots, metadata inspection, and exports to a newly named file under a path explicitly requested by the user do not require extra confirmation.

## Limits and privacy

- Do not expose image pixels, local paths, or metadata outside the active task.
- Request scaled snapshots first; use full-resolution bitmap retrieval only when needed.
- Do not use GIMP MCP as a general shell, file browser, or network client.
- Never change the MCP server configuration while editing an image.
