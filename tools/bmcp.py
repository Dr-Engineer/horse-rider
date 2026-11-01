#!/usr/bin/python3
"""Small client for the Blender MCP server configured in .mcp.json.

Usage:
  bmcp.py exec <script.py> [key=value ...]   Run a script inside the live Blender.
  bmcp.py code "<python>"                    Run a snippet inside the live Blender.
  bmcp.py look <out.png> '<json args>'       Save what the `look` tool sees to a PNG.
  bmcp.py call <tool> '<json args>'          Call any other server tool.

The key=value pairs become the BMCP_ARGS dict inside the script.
"""
import base64
import json
import os
import select
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT_SECONDS = 600


def start_server():
    with open(os.path.join(ROOT, ".mcp.json")) as f:
        cfg = json.load(f)["mcpServers"]["blender"]
    return subprocess.Popen(
        [cfg["command"]] + cfg["args"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        env=dict(os.environ, **cfg["env"]),
        text=True,
    )


def rpc(proc, msg_id, method, params):
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params}) + "\n")
    proc.stdin.flush()
    deadline = time.time() + TIMEOUT_SECONDS
    while time.time() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], 1.0)
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError("MCP server closed its output")
        reply = json.loads(line)
        if reply.get("id") == msg_id:
            return reply
    raise TimeoutError("MCP call timed out: %s" % method)


def call_tool(tool, arguments):
    proc = start_server()
    try:
        rpc(proc, 1, "initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "bmcp", "version": "1"},
        })
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
        proc.stdin.flush()
        return rpc(proc, 2, "tools/call", {"name": tool, "arguments": arguments})
    finally:
        proc.terminate()


def report(reply, image_path=None):
    if "error" in reply:
        print("MCP ERROR:", reply["error"])
        return 1
    result = reply["result"]
    saved = 0
    for item in result.get("content", []):
        if item.get("type") == "text":
            print(item["text"])
        elif item.get("type") == "image" and image_path:
            path = image_path
            if saved:
                base, ext = os.path.splitext(image_path)
                path = "%s_%d%s" % (base, saved, ext)
            with open(path, "wb") as f:
                f.write(base64.b64decode(item["data"]))
            print("saved image:", path)
            saved += 1
    return 1 if result.get("isError") else 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    action = sys.argv[1]
    if action == "exec":
        script = os.path.abspath(sys.argv[2])
        args = dict(pair.split("=", 1) for pair in sys.argv[3:])
        code = (
            "import builtins\n"
            "BMCP_ARGS = %r\n"
            "__file__ = %r\n"
            "exec(compile(open(%r).read(), %r, 'exec'), {'__name__': '__main__', '__file__': %r, 'BMCP_ARGS': BMCP_ARGS})\n"
        ) % (args, script, script, script, script)
        return report(call_tool("execute_blender_code", {"code": code}))
    if action == "code":
        return report(call_tool("execute_blender_code", {"code": sys.argv[2]}))
    if action == "look":
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        return report(call_tool("look", args), image_path=sys.argv[2])
    if action == "call":
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        return report(call_tool(sys.argv[2], args))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
