from __future__ import annotations

import argparse
from pathlib import Path
from typing import Literal

from mcp.server.fastmcp import FastMCP

PROJECT_ROOT = Path(__file__).resolve().parents[1]
USER_DOC_PATH = PROJECT_ROOT / "README-UTILISATEUR.md"
DEFAULT_MAX_CHARS = 20000

server = FastMCP(
    name="ami-mcp",
    instructions=(
        "Expose the Ami Flutter workspace so MCP clients can read files and update the user guide."
    ),
)


def _resolve_workspace_file(path: str) -> Path:
    if not path:
        raise ValueError("path is required")
    candidate = Path(path)
    candidate = (candidate if candidate.is_absolute() else PROJECT_ROOT / candidate).resolve()
    try:
        candidate.relative_to(PROJECT_ROOT)
    except ValueError as exc:
        raise ValueError("path must stay inside the repository root") from exc
    if not candidate.exists():
        raise FileNotFoundError(f"no such file: {candidate}")
    if candidate.is_dir():
        raise IsADirectoryError(f"expected a file, got directory: {candidate}")
    return candidate


def _slice_text(text: str, start_line: int | None, end_line: int | None) -> str:
    if start_line is None and end_line is None:
        return text
    lines = text.splitlines()
    start = max((start_line or 1) - 1, 0)
    finish = end_line if end_line is not None else len(lines)
    if finish < start:
        raise ValueError("end_line must be greater than start_line")
    return "\n".join(lines[start:finish])


def _truncate(text: str, max_chars: int | None) -> str:
    if max_chars is None or max_chars <= 0:
        return text
    if len(text) <= max_chars:
        return text
    trimmed = text[:max_chars]
    notice = f"\n\n---\nOutput truncated to {max_chars} characters (original length {len(text)})."
    return trimmed + notice


@server.tool(
    name="read_workspace_file",
    description="Read UTF-8 text from any file that lives under the repository root.",
)
def read_workspace_file(
    path: str,
    start_line: int | None = None,
    end_line: int | None = None,
    max_chars: int = DEFAULT_MAX_CHARS,
) -> str:
    file_path = _resolve_workspace_file(path)
    text = file_path.read_text(encoding="utf-8", errors="replace")
    sliced = _slice_text(text, start_line, end_line)
    limited = _truncate(sliced, max_chars)
    relative = file_path.relative_to(PROJECT_ROOT)
    header = f"FILE: {relative}" if relative else "FILE: ."
    return f"{header}\n---\n{limited}"


@server.tool(
    name="write_user_document",
    description="Append to or replace README-UTILISATEUR.md so end users stay up to date.",
)
def write_user_document(
    content: str,
    mode: Literal["append", "replace"] = "append",
    heading: str | None = None,
) -> str:
    if not content.strip():
        raise ValueError("content must not be empty")
    payload = content.strip()
    if heading:
        payload = f"## {heading.strip()}\n\n{payload}"
    USER_DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    if mode == "replace" or not USER_DOC_PATH.exists():
        USER_DOC_PATH.write_text(payload + "\n", encoding="utf-8")
        action = "replaced"
    else:
        with USER_DOC_PATH.open("a", encoding="utf-8") as handle:
            handle.write("\n\n" + payload + "\n")
        action = "appended"
    relative = USER_DOC_PATH.relative_to(PROJECT_ROOT)
    return f"{action} {relative} with {len(payload)} characters"


def run_server(transport: Literal["stdio", "sse", "streamable-http"], mount_path: str | None) -> None:
    if transport == "sse":
        server.run(transport="sse", mount_path=mount_path or "/mcp")
    else:
        server.run(transport=transport)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the Ami MCP helper server.")
    parser.add_argument(
        "--transport",
        choices=["stdio", "sse", "streamable-http"],
        default="stdio",
        help="Transport to expose (default: stdio)",
    )
    parser.add_argument(
        "--mount-path",
        default="/mcp",
        help="Mount path when using SSE transport",
    )
    args = parser.parse_args()
    run_server(args.transport, args.mount_path)


if __name__ == "__main__":
    main()
