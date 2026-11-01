# Setting up on a new computer

Written for Claude Code running on the new computer, as the user wants Claude to do this work. The user only approves
prompts and signs in where a person has to. Read `docs/HANDOFF.md` afterwards.

Only the macOS setup has actually been run. Treat the Windows and Linux notes as untested, and report what you had to
change.

## Versions

| Tool | Version | Source |
|---|---|---|
| Git and Git LFS | current | git-scm.com, git-lfs.com |
| Godot | 4.7.2-stable, standard build (not .NET) | github.com/godotengine/godot/releases, verify against `SHA512-SUMS.txt` |
| Blender | 5.2.3 LTS | blender.org. `download.blender.org` refuses scripted downloads, so use an official mirror such as `mirrors.ocf.berkeley.edu/blender`, and verify the release's `.sha256` file |
| Node | current LTS | nodejs.org, verify `SHASUMS256.txt` |
| uv | current | github.com/astral-sh/uv/releases, verify its `.sha256` |
| Godot MCP | `@coding-solo/godot-mcp@0.1.1` | npm, install with `--ignore-scripts` |
| Blender MCP | `mcp-for-blender==2.2.6` | PyPI, `uv tool install --python 3.11` |

Install per-user where possible, so no admin rights are needed. Check signatures where the platform has them.

## Steps

1. **Git LFS, then clone.** Run `git lfs install`, then clone `https://github.com/Dr-Engineer/horse-rider.git` to
   `~/games/horse-rider`. Confirm nothing is a placeholder: `grep -rl git-lfs.github.com/spec assets` must find nothing.
2. **Godot.**
   - macOS: put it in `/Applications`.
   - Windows: `%LOCALAPPDATA%\Programs\Godot\godot.exe`.
   - If it's anywhere else, set a `GODOT` environment variable to the executable. The `tools/*.sh` scripts and `Play.bat` read it.
3. **Test the game before anything else.** Import, then run the rule checks:
   ```bash
   "$GODOT" --headless --path . --import
   "$GODOT" --headless --path . res://tests/sim_balance.tscn -- 2 0 500 0
   ```
   There should be no `SCRIPT ERROR` and no failed checks. "Resources still in use at exit" is harmless.
4. **Blender and its MCP.**
   - Install Blender, then install the MCP server with `uv`.
   - Install the add-on into Blender 5.2 only, and leave any older Blender alone. Find `blender_mcp/bundled/addon.py` in the installed
     package, copy it to a temporary file named `blender_mcp_addon.py`, then in `blender --background --factory-startup` run
     `bpy.ops.preferences.addon_install(filepath=..., overwrite=True)`, `addon_utils.enable("blender_mcp_addon", default_set=True)`
     and `bpy.ops.wm.save_userpref()`.
   - The add-on only serves in a running Blender window, on port 9876, not in background mode.
5. **MCP config.** Copy `.mcp.example.json` to `.mcp.json` and fill in absolute paths. Keep `DISABLE_TELEMETRY` on. `.mcp.json` is
   gitignored because it holds local paths. If the session doesn't load the servers, `tools/bmcp.py` can talk to the Blender server.
6. **Check the MCP servers.** `get_godot_version` on the Godot server, and on the Blender server, `execute_blender_code` running
   `import bpy; print(bpy.app.version_string)`.
7. **Play it.** Double-click `Play.command` on macOS or `Play.bat` on Windows. On Linux run `"$GODOT" --path .`
8. **GitHub sign-in for pushing.** A person has to do this. Run `git config user.name "Dr-Engineer"` and
   `git config user.email "17087741+Dr-Engineer@users.noreply.github.com"`, so the user's real email stays private. Installing `gh` and
   running `gh auth login --web` is easiest. **The repo is public: run the leak check skill before every push.**
9. **Report** what was installed, what passed and what you had to change, then commit any fixes for this computer.

## Platform notes

- **Windows:** `tools/*.sh` need Git Bash. Blender's Python is at `<Blender>\5.2\python\bin\python.exe`.
- **Windows and Linux:** `tools/record_demo.sh` needs a replacement for the two Swift video tools (for example ffmpeg). Everything else in
  the game is cross-platform Godot and Python.
- **macOS:** when testing with a window, add `--disable-vsync`. With vsync on, Godot nearly stalls if its window is hidden behind others,
  which looks like a hang.
