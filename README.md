# ami

A new Flutter project.

## MCP helper server

- Script: [scripts/mcp_server.py](scripts/mcp_server.py)
- Install dependency inside the virtual environment once: `c:/wamp64/www/gesplanet_01/ami/.venv/Scripts/pip.exe install modelcontextprotocol`
- Start the server (stdio transport, suitable for most Copilot integrations):
	- `c:/wamp64/www/gesplanet_01/ami/.venv/Scripts/python.exe scripts/mcp_server.py`
- Optional transports: `--transport sse --mount-path /mcp` or `--transport streamable-http` if you prefer HTTP-based integrations.
- Tools available through the server:
	- `read_workspace_file` — read any UTF-8 file under the repo, optionally slicing by line range and truncating long outputs.
	- `write_user_document` — append to or replace [README-UTILISATEUR.md](README-UTILISATEUR.md) so you can capture new user-facing notes without leaving the MCP client.
