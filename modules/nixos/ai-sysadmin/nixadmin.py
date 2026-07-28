#!/usr/bin/env python3
"""nixadmin — AI-powered NixOS system admin assistant"""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import httpx
from prompt_toolkit import PromptSession
from prompt_toolkit.history import FileHistory
from rich import print as rprint
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.syntax import Syntax

# ── Config ─────────────────────────────────────────────────────────────────────

CONFIG_PATH = Path(os.environ.get("NIXADMIN_CONFIG_PATH", "/home/steve/workspace/nixlap"))
MODEL = os.environ.get("NIXADMIN_MODEL", "gemma4:12b")
AUTO_SNAPSHOT = os.environ.get("NIXADMIN_AUTO_SNAPSHOT", "true").lower() == "true"
OLLAMA_URL = "http://localhost:11434/api/chat"
HISTORY_FILE = Path.home() / ".local" / "share" / "nixadmin" / "history"

console = Console()

# ── Safety ─────────────────────────────────────────────────────────────────────

# Files the agent may never edit
READ_ONLY_FILES = {"hardware-configuration.nix"}

# Content patterns that indicate a high-risk (Tier 3) change
TIER_3_PATTERNS = [
    "boot.",
    "kernelParams",
    "kernelPackages",
    "initrd",
    "luks",
    "fileSystems",
    "swapDevices",
    "security.pam",
    "users.users.root",
    "systemd-boot",
    "grub",
]

# Files where changes are always Tier 1 (low risk)
TIER_1_FILES = {
    "modules/home-manager/default.nix",
    "modules/nixos/flatpak.nix",
}


def classify_change() -> int:
    """Return safety tier 1/2/3 based on what changed in the git working tree."""
    diff_names = subprocess.run(
        ["git", "diff", "--name-only"],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    ).stdout.strip()

    if not diff_names:
        return 1

    changed = set(diff_names.splitlines())

    diff_content = subprocess.run(
        ["git", "diff"],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    ).stdout

    for pattern in TIER_3_PATTERNS:
        if pattern in diff_content:
            return 3

    if changed.issubset(TIER_1_FILES):
        return 1

    return 2


def show_diff() -> bool:
    """Print the current git diff. Returns True if there are changes."""
    diff = subprocess.run(
        ["git", "diff"],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    ).stdout
    if not diff:
        return False
    console.print(Panel(
        Syntax(diff, "diff", theme="monokai", word_wrap=True),
        title="[bold]Proposed changes[/bold]",
        border_style="cyan",
    ))
    return True


def confirm_change(tier: int) -> bool:
    """Get tier-appropriate user confirmation. Returns True if approved."""
    if tier == 1:
        return Confirm.ask("[green]Apply this change?[/green]")

    if tier == 2:
        console.print(Panel(
            "[yellow]This change affects system services or configuration.\n"
            "Review the diff above carefully before continuing.[/yellow]",
            title="[bold yellow]Moderate change[/bold yellow]",
            border_style="yellow",
        ))
        return Confirm.ask("[yellow]Apply this change?[/yellow]")

    # Tier 3
    console.print(Panel(
        "[red bold]WARNING: This change affects critical system configuration\n"
        "(boot loader, kernel, encryption, PAM, or root account).\n\n"
        "An incorrect change could make your system unbootable.\n"
        "NixOS keeps previous generations in the boot menu — you can\n"
        "roll back from there if something goes wrong.\n\n"
        "Consider saving a snapshot first (/snapshot).[/red bold]",
        title="[bold red]HIGH RISK CHANGE[/bold red]",
        border_style="red",
    ))
    answer = Prompt.ask('[red]Type "YES I UNDERSTAND" to proceed[/red]')
    return answer == "YES I UNDERSTAND"


def restore_changes():
    """Discard all uncommitted changes."""
    subprocess.run(["git", "restore", "."], cwd=CONFIG_PATH, check=True)


def has_uncommitted_changes() -> bool:
    result = subprocess.run(
        ["git", "diff", "--quiet"], cwd=CONFIG_PATH,
    )
    return result.returncode != 0


# ── Tools ──────────────────────────────────────────────────────────────────────

def _resolve_path(path: str) -> Path | None:
    """Resolve a relative-or-absolute path inside CONFIG_PATH. Returns None on traversal."""
    candidate = (CONFIG_PATH / path.lstrip("/")).resolve()
    try:
        candidate.relative_to(CONFIG_PATH.resolve())
        return candidate
    except ValueError:
        return None


def tool_read_file(path: str) -> str:
    target = _resolve_path(path)
    if target is None:
        return f"Error: path '{path}' is outside the config directory."
    if not target.exists():
        return f"Error: file not found: {path}"
    return target.read_text()


def tool_edit_file(path: str, old_string: str, new_string: str) -> str:
    if any(blocked in path for blocked in READ_ONLY_FILES):
        return f"Error: {path} is machine-generated and must not be edited."
    target = _resolve_path(path)
    if target is None:
        return f"Error: path '{path}' is outside the config directory."
    if not target.exists():
        return f"Error: file not found: {path}"
    content = target.read_text()
    if old_string not in content:
        return (
            f"Error: the specified text was not found in {path}. "
            "Read the file again and use the exact current text."
        )
    target.write_text(content.replace(old_string, new_string, 1))
    return f"Edited {path} successfully."


def tool_list_files(path: str = "") -> str:
    base = _resolve_path(path) if path else CONFIG_PATH.resolve()
    if base is None:
        return f"Error: path '{path}' is outside the config directory."
    if not base.is_dir():
        return f"Error: not a directory: {path}"
    files = sorted(str(f.relative_to(CONFIG_PATH)) for f in base.rglob("*.nix"))
    return "\n".join(files) if files else "No .nix files found."


def tool_nixos_rebuild_test() -> str:
    console.print("[dim]Running nixos-rebuild test…[/dim]")
    result = subprocess.run(
        ["sudo", "nixos-rebuild", "test", "--flake", ".#laptop"],
        cwd=CONFIG_PATH,
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return "nixos-rebuild test passed — configuration is valid."
    return f"nixos-rebuild test FAILED:\n{result.stderr}\n{result.stdout}".strip()


TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": (
                "Read a NixOS config file. Always read a file before editing it "
                "so you have the exact current content."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "File path relative to config root, e.g. 'modules/home-manager/default.nix'",
                    }
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "edit_file",
            "description": (
                "Edit a NixOS config file by replacing an exact string. "
                "You must read_file first to obtain the precise text to replace."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "File path relative to config root",
                    },
                    "old_string": {
                        "type": "string",
                        "description": "Exact text to replace (copy from read_file output)",
                    },
                    "new_string": {
                        "type": "string",
                        "description": "Replacement text",
                    },
                },
                "required": ["path", "old_string", "new_string"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "List all .nix files in the config repository.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Subdirectory to list (optional, defaults to repo root)",
                        "default": "",
                    }
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "nixos_rebuild_test",
            "description": (
                "Run 'nixos-rebuild test' to verify the configuration compiles and "
                "activates cleanly without making it permanent. "
                "Always call this after editing files, before telling the user you're ready to apply."
            ),
            "parameters": {"type": "object", "properties": {}},
        },
    },
]

TOOL_HANDLERS = {
    "read_file": lambda a: tool_read_file(a["path"]),
    "edit_file": lambda a: tool_edit_file(a["path"], a["old_string"], a["new_string"]),
    "list_files": lambda a: tool_list_files(a.get("path", "")),
    "nixos_rebuild_test": lambda _: tool_nixos_rebuild_test(),
}

# ── System prompt ──────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are nixadmin, a friendly NixOS system admin assistant. Your job is to help \
users manage their NixOS configuration safely, even if they have no Linux or NixOS experience.

## Personality
- Speak in plain, friendly English — avoid jargon; explain terms when you must use them
- Explain what you plan to do and why before doing it
- Flag risks or side effects proactively
- Ask clarifying questions when the request is ambiguous
- Be encouraging — NixOS can be intimidating

## The configuration you manage
- Config path: {config_path}
- Single host: laptop  |  Single user: steve
- Kernel: linuxPackages_zen (AMD-optimised)
- Desktop: KDE Plasma 6 on Wayland

### File layout
- modules/home-manager/default.nix  — user packages (home.packages), shell, git
- modules/nixos/common.nix          — boot, kernel, power, services
- modules/nixos/kde.nix             — KDE Plasma desktop
- modules/nixos/flatpak.nix         — declarative Flatpak apps
- modules/nixos/secrets.nix         — secrets (sops-nix)
- hosts/laptop/default.nix          — top-level host config, imports all modules

### Package placement — always follow this, never ask the user
- **Any application, tool, or utility the user asks to install** → add to `home.packages`
  in `modules/home-manager/default.nix`, inside the `with pkgs; [ ... ]` list.
  This is system-wide for the single user on this machine. Do NOT ask where to install it.
- **System services** (daemons, servers) → relevant `environment.systemPackages` or service option
- **Flatpak apps** → `services.flatpak.packages` list in `modules/nixos/flatpak.nix`
- Nix module pattern: `{{ pkgs, ... }}: {{ ... }}`

## Hard rules — never break these
1. NEVER edit hardware-configuration.nix — it is machine-generated
2. NEVER remove the steve user or their wheel group
3. NEVER disable sudo
4. ALWAYS read_file before edit_file — never guess file contents
5. ALWAYS call nixos_rebuild_test after making changes and before telling the user you're ready
6. Make the smallest targeted change — do not refactor surrounding code
7. One concern per turn — do not bundle unrelated changes
8. NEVER ask the user where to install a package — use the defaults above

## Workflow for every change
1. If the request is a package install: go directly to step 2 — no clarifying questions
2. Read the relevant file with read_file
3. Add or change the minimum needed with edit_file
4. Run nixos_rebuild_test — fix and re-test on failure (up to 3 attempts)
5. Tell the user what you did in one plain sentence
6. The system handles applying (nixos-rebuild switch) and git commit

## Available config files
Use read_file to read any of these before editing. Never guess file contents.

{file_listing}
"""


def build_system_prompt() -> str:
    files = sorted(
        str(f.relative_to(CONFIG_PATH))
        for f in CONFIG_PATH.rglob("*.nix")
    )
    return SYSTEM_PROMPT.format(
        config_path=CONFIG_PATH,
        file_listing="\n".join(f"- {f}" for f in files),
    )


# ── Ollama loop ────────────────────────────────────────────────────────────────

# Added to system prompt when the model doesn't support native tool calling.
# The LLM outputs TOOL_CALL lines that we parse and execute ourselves.
REACT_ADDENDUM = """
## How to use tools
When you need to perform an action, output a line in EXACTLY this format:
TOOL_CALL: {"tool": "<name>", "args": {<json args>}}

Wait for the result before continuing. Available tools:
- read_file     args: {"path": "relative/path.nix"}
- edit_file     args: {"path": "...", "old_string": "exact text", "new_string": "replacement"}
- list_files    args: {} or {"path": "subdir"}
- nixos_rebuild_test  args: {}

Example:
TOOL_CALL: {"tool": "read_file", "args": {"path": "modules/home-manager/default.nix"}}
"""

import re as _re

def _dispatch_tool(name: str, args: dict) -> str:
    arg_preview = ", ".join(f"{k}={repr(v)[:60]}" for k, v in args.items())
    console.print(f"[dim]  → {name}({arg_preview})[/dim]")
    handler = TOOL_HANDLERS.get(name)
    return handler(args) if handler else f"Unknown tool: {name}"


def _chat_with_tools(messages: list[dict], system_prompt: str) -> dict:
    """Native tool-calling path (Ollama tools API).

    Intermediate tool messages are kept in a local inner list so the outer
    messages list stays clean (user/assistant pairs only).
    """
    inner = list(messages)
    payload = {
        "model": MODEL,
        "messages": [{"role": "system", "content": system_prompt}] + inner,
        "tools": TOOL_DEFINITIONS,
        "stream": False,
        "options": {"num_ctx": 8192},
    }
    while True:
        with console.status("[dim]Thinking…[/dim]"):
            resp = httpx.post(OLLAMA_URL, json=payload, timeout=180.0)
            resp.raise_for_status()
            data = resp.json()

        msg = data["message"]
        tool_calls = msg.get("tool_calls") or []
        if not tool_calls:
            messages.append(msg)
            return msg

        inner.append(msg)
        for tc in tool_calls:
            fn = tc["function"]
            result = _dispatch_tool(fn["name"], fn.get("arguments") or {})
            inner.append({"role": "tool", "content": result})

        payload["messages"] = [{"role": "system", "content": system_prompt}] + inner


def _chat_react(messages: list[dict], system_prompt: str) -> dict:
    """ReAct text-parsing fallback for models that don't support tools API.

    Intermediate tool messages are kept in a local inner list so the outer
    messages list stays clean (user/assistant pairs only).
    """
    full_prompt = system_prompt + REACT_ADDENDUM
    inner = list(messages)
    payload = {
        "model": MODEL,
        "messages": [{"role": "system", "content": full_prompt}] + inner,
        "stream": False,
        "options": {"num_ctx": 8192},
    }
    while True:
        with console.status("[dim]Thinking…[/dim]"):
            resp = httpx.post(OLLAMA_URL, json=payload, timeout=180.0)
            resp.raise_for_status()
            data = resp.json()

        msg = data["message"]
        content = msg.get("content", "")

        match = _re.search(r"TOOL_CALL:\s*(\{.*\})", content)
        if not match:
            messages.append(msg)
            return msg

        try:
            tc = json.loads(match.group(1))
            result = _dispatch_tool(tc["tool"], tc.get("args") or {})
        except Exception as e:
            result = f"Error parsing tool call: {e}"

        inner.append(msg)
        inner.append({"role": "user", "content": f"Tool result:\n{result}"})
        payload["messages"] = [{"role": "system", "content": full_prompt}] + inner


# Probe once at startup whether this model supports native tools
_tools_supported: bool | None = None

def chat_turn(messages: list[dict], system_prompt: str) -> dict:
    """
    Run one full LLM turn. Tries native tools first; falls back to ReAct
    text-parsing if the model returns 400 (tools not supported).
    Appends to messages in-place. Returns the final assistant message.
    """
    global _tools_supported

    if _tools_supported is False:
        return _chat_react(messages, system_prompt)

    try:
        return _chat_with_tools(messages, system_prompt)
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 400:
            _tools_supported = False
            console.print("[dim]Model doesn't support tools API — using text mode.[/dim]")
            return _chat_react(messages, system_prompt)
        raise


# ── Apply workflow ─────────────────────────────────────────────────────────────

def apply_workflow():
    """
    Called after the LLM finishes a turn if there are uncommitted changes.
    Guides the user through confirmation → switch → commit → optional snapshot.
    """
    if not has_uncommitted_changes():
        return

    has_diff = show_diff()
    if not has_diff:
        return

    tier = classify_change()
    approved = confirm_change(tier)

    if not approved:
        console.print("[yellow]Changes discarded.[/yellow]")
        restore_changes()
        return

    console.print("[bold]Applying configuration…[/bold]")
    result = subprocess.run(
        ["sudo", "nixos-rebuild", "switch", "--flake", ".#laptop"],
        cwd=CONFIG_PATH,
    )
    if result.returncode != 0:
        console.print("[red]nixos-rebuild switch failed. Reverting changes.[/red]")
        restore_changes()
        return

    console.print("[green]✓ Configuration applied.[/green]")

    # Commit
    default_msg = f"applied configuration change"
    commit_msg = Prompt.ask("Commit message", default=default_msg)
    subprocess.run(["git", "add", "-A"], cwd=CONFIG_PATH, check=True)
    subprocess.run(
        ["git", "commit", "-m", f"nixadmin: {commit_msg}"],
        cwd=CONFIG_PATH, check=True,
    )
    console.print("[green]✓ Committed.[/green]")

    # Snapshot
    if AUTO_SNAPSHOT:
        _create_snapshot(silent=True)
    elif Confirm.ask("Save this as a working snapshot tag?"):
        _create_snapshot()


def _create_snapshot(silent: bool = False):
    date_str = datetime.now().strftime("%Y-%m-%d")
    tag_name = f"working-{date_str}"
    # If tag already exists today, append time
    existing = subprocess.run(
        ["git", "tag", "-l", tag_name],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    ).stdout.strip()
    if existing:
        tag_name = f"working-{datetime.now().strftime('%Y-%m-%d-%H%M')}"

    subprocess.run(
        ["git", "tag", "-a", tag_name, "-m", f"Working snapshot {tag_name}"],
        cwd=CONFIG_PATH, check=True,
    )
    if not silent:
        console.print(f"[green]✓ Snapshot saved: {tag_name}[/green]")
    else:
        console.print(f"[dim]  Tagged: {tag_name}[/dim]")


# ── Management commands ────────────────────────────────────────────────────────

def cmd_revert():
    result = subprocess.run(
        ["git", "log", "--oneline", "--decorate", "-15"],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    )
    console.print(Panel(result.stdout.rstrip(), title="Recent commits & tags"))
    target = Prompt.ask(
        "Revert to — enter a commit hash, tag name, or 'last' to undo the last commit"
    )

    if target == "last":
        subprocess.run(["git", "revert", "HEAD", "--no-edit"], cwd=CONFIG_PATH, check=True)
    else:
        subprocess.run(["git", "checkout", target, "--", "."], cwd=CONFIG_PATH, check=True)

    show_diff()

    if Confirm.ask("Apply this reverted configuration?"):
        result = subprocess.run(
            ["sudo", "nixos-rebuild", "switch", "--flake", ".#laptop"],
            cwd=CONFIG_PATH,
        )
        if result.returncode == 0:
            subprocess.run(["git", "add", "-A"], cwd=CONFIG_PATH)
            subprocess.run(
                ["git", "commit", "-m", f"nixadmin: revert to {target}"],
                cwd=CONFIG_PATH,
            )
            console.print("[green]✓ Reverted and applied.[/green]")
        else:
            console.print("[red]Rebuild failed — restoring previous state.[/red]")
            restore_changes()
    else:
        restore_changes()


def cmd_history():
    result = subprocess.run(
        ["git", "log", "--oneline", "--decorate", "-20"],
        cwd=CONFIG_PATH, capture_output=True, text=True,
    )
    console.print(Panel(result.stdout.rstrip(), title="Config change history"))


def cmd_snapshot():
    date_str = datetime.now().strftime("%Y-%m-%d")
    tag_name = Prompt.ask("Tag name", default=f"working-{date_str}")
    desc = Prompt.ask("Description", default="Working configuration snapshot")
    subprocess.run(
        ["git", "tag", "-a", tag_name, "-m", desc],
        cwd=CONFIG_PATH, check=True,
    )
    console.print(f"[green]✓ Saved snapshot: {tag_name}[/green]")


def cmd_help():
    console.print(Panel(
        "Just type your request in plain English — for example:\n"
        "  • 'add the spotify package'\n"
        "  • 'install the obs-studio flatpak'\n"
        "  • 'enable the printing service'\n"
        "  • 'what packages do I have installed?'\n\n"
        "[bold]Commands:[/bold]\n"
        "  /revert    — roll back to a previous commit or snapshot\n"
        "  /history   — show the change log\n"
        "  /snapshot  — save current config as a working snapshot\n"
        "  /help      — show this message\n"
        "  /quit      — exit nixadmin",
        title="nixadmin help",
        border_style="blue",
    ))


COMMANDS = {
    "/revert": cmd_revert,
    "/history": cmd_history,
    "/snapshot": cmd_snapshot,
    "/help": cmd_help,
}

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)

    console.print(Panel(
        f"[bold]nixadmin[/bold] — AI-powered NixOS system admin\n"
        f"Model: [cyan]{MODEL}[/cyan]   Config: [cyan]{CONFIG_PATH}[/cyan]\n\n"
        "Describe what you'd like to change, or type [bold]/help[/bold] to get started.",
        border_style="blue",
    ))

    # Verify Ollama is reachable
    try:
        httpx.get("http://localhost:11434", timeout=3.0)
    except Exception:
        console.print(
            "[red]Error: Ollama is not running.\n"
            "Start it with:  systemctl start ollama[/red]"
        )
        sys.exit(1)

    # Check the model is available
    try:
        r = httpx.get("http://localhost:11434/api/tags", timeout=5.0)
        models = [m["name"] for m in r.json().get("models", [])]
        if not any(m == MODEL or m.startswith(MODEL.split(":")[0] + ":") for m in models):
            console.print(Panel(
                f"[yellow]Model [bold]{MODEL}[/bold] is not downloaded yet.\n\n"
                f"Pull it with:\n  [bold]ollama pull {MODEL}[/bold]\n\n"
                "Then restart nixadmin.",
                title="[bold yellow]Model not found[/bold yellow]",
                border_style="yellow",
            ))
            sys.exit(1)
    except Exception:
        pass  # if tags check fails, let the first request surface the error

    if has_uncommitted_changes():
        console.print(Panel(
            "[yellow]The config repo has uncommitted changes from a previous session.\n"
            "These won't be touched unless you ask nixadmin to make further edits.\n"
            "Use [bold]/history[/bold] to review, or commit/discard them manually first.[/yellow]",
            title="[bold yellow]Uncommitted changes detected[/bold yellow]",
            border_style="yellow",
        ))

    console.print("[dim]Loading NixOS configuration context…[/dim]")
    system_prompt = build_system_prompt()
    console.print("[dim]Ready.[/dim]\n")

    session = PromptSession(history=FileHistory(str(HISTORY_FILE)))
    messages: list[dict] = []

    while True:
        try:
            user_input = session.prompt("\nnixadmin> ").strip()
        except (KeyboardInterrupt, EOFError):
            console.print("\n[dim]Goodbye![/dim]")
            break

        if not user_input:
            continue

        if user_input.lower() in ("/quit", "/exit", "quit", "exit"):
            console.print("[dim]Goodbye![/dim]")
            break

        cmd = COMMANDS.get(user_input)
        if cmd:
            cmd()
            continue

        messages.append({"role": "user", "content": user_input})

        # Snapshot the diff BEFORE the LLM turn so we can detect what it changed
        diff_before = subprocess.run(
            ["git", "diff"], cwd=CONFIG_PATH, capture_output=True, text=True,
        ).stdout

        try:
            response = chat_turn(messages, system_prompt)
        except httpx.HTTPStatusError as e:
            console.print(f"[red]Ollama API error: {e}[/red]")
            messages.pop()
            continue
        except httpx.TimeoutException:
            console.print("[red]Request timed out. Is the model loaded? Try again.[/red]")
            messages.pop()
            continue

        content = response.get("content", "").strip()
        if content:
            console.print(Panel(Markdown(content), border_style="green"))

        # Only trigger apply if the LLM actually changed something this turn
        diff_after = subprocess.run(
            ["git", "diff"], cwd=CONFIG_PATH, capture_output=True, text=True,
        ).stdout
        if diff_after != diff_before:
            apply_workflow()


if __name__ == "__main__":
    main()
