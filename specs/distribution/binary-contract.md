# What the core binary must do

The install scripts and the website stay small because the **core binary** does the rest. This file
lists everything the binary owes the distribution. Each item is tested ([test-strategy.md](test-strategy.md)).

## 1. Global rules

- **Stdout:** diagnostics never go to stdout. In `redvig mcp`, stdout carries only MCP frames. All
  messages below go to stderr.
- **Stdin:** `install redvig` and the updater never read stdin and never prompt.
- **Home:** always `~/.redvig` (`%USERPROFILE%\.redvig`); the literal appears once in the code.
- **Version:** `redvig --version` prints the release version (`MAJOR.MINOR.PATCH`), the same constant
  the build writes into the archive. Any other version string is a dev build: no auto-update.
- **Modules:** the binary reads module paths only from `REDVIG_MODULES` and `REDVIG_MODULE_<ID>`
  ([modules.md](modules.md)). It never scans `binaries/`.
- **Keys:** the two public keys from `distribution/allowed_signers` are compiled in.

## 2. `redvig install redvig`

The install script runs this with the new binary as its last step. It must be idempotent, and it
returns 0 on success and non-zero on failure. In order:

1. **Check** that `REDVIG_MODULES` contains `redvig` and every listed module path exists.
2. **Put `~/.redvig/bin` on `PATH`** (platform rules below). A `PATH` problem is reported as a warning
   and does not fail the command. Agents start the launcher by its absolute path.
3. **Newer-launcher guard:** if the existing launcher's `redvig launcher version:` line names a newer
   version, keep it and exit 0.
4. **Write the launcher** ([launcher.md](launcher.md)) as the last step: write
   `bin/redvig.new.<random>` (Windows: `bin/redvig.cmd.new.<random>`), set it executable, then rename
   it over the old file in one step. If the rename fails, retry a few times, then keep the old launcher
   and exit non-zero.
5. **Print** the launcher path and the next commands (for example `redvig install claude`). This is the
   only "next steps" text; the scripts print none.

It never registers redvig with an agent and never touches an IDE. Those are separate explicit
commands.

### macOS (and Linux)

- Launcher: `~/.redvig/bin/redvig`, POSIX `sh`, mode `0755`.
- `PATH`:
  1. If `~/.redvig/bin` is already on `PATH`, do nothing.
  2. Otherwise, if a directory on `PATH` under `$HOME` is writable (for example `~/.local/bin`),
     create the symlink `<dir>/redvig` → `~/.redvig/bin/redvig`. Replace it only if it is already a
     symlink pointing into `~/.redvig`; if another file named `redvig` is there, leave it and go to step 3.
  3. Otherwise, add this block to the login profile of the user's shell, chosen from `$SHELL`:
     - zsh (the macOS default): `${ZDOTDIR:-$HOME}/.zprofile`;
     - bash: the first that exists of `~/.bash_profile`, `~/.bash_login`, `~/.profile` (bash reads only
       the first one); if none exists, `~/.bash_profile` on macOS and `~/.profile` on Linux;
     - any other shell: change no file, and print the line to add.

     The file is created if needed. The block is written once and is recognised by its marker lines:
     ```sh
     # >>> redvig >>>
     export PATH="$HOME/.redvig/bin:$PATH"
     # <<< redvig <<<
     ```
  4. Print that a new terminal is needed when step 2 or 3 changed something.
- The binary needs no Gatekeeper handling: files downloaded by `curl` carry no quarantine attribute.

### Windows

- Launcher: `%USERPROFILE%\.redvig\bin\redvig.cmd` (CMD, ASCII, CRLF, paths relative to itself,
  see [launcher.md](launcher.md)). No PowerShell at launch.
- `PATH`, in one short PowerShell command run only by `install redvig` (never at launch):
  1. Read the user `Path` from `HKCU\Environment` **unexpanded**
     (`RegistryKey.GetValue('Path', '', 'DoNotExpandEnvironmentNames')`), together with its type. If the
     value is missing, treat it as empty with type `REG_EXPAND_SZ`.
  2. If `%USERPROFILE%\.redvig\bin` is already in it (case-insensitive, ignoring a trailing `\`), stop.
  3. Append the entry and write the value back **with its original type** (`RegistryKey.SetValue` with
     that `RegistryValueKind`). For `REG_EXPAND_SZ` append `%USERPROFILE%\.redvig\bin`; for `REG_SZ`,
     whose references are never expanded, append the absolute path. Never use `setx`, which cuts values at 1024 characters.
  4. Broadcast the change so that new terminals see it: setting any user variable through
     `[Environment]::SetEnvironmentVariable('REDVIG_PATH_REFRESH', $null, 'User')` sends
     `WM_SETTINGCHANGE` with `"Environment"`. (Writing `Path` itself through that API would lose the
     `REG_EXPAND_SZ` type.)
- Whenever the binary writes an agent registration (a separate, explicit command), the Windows command
  is `cmd.exe /d /s /c ""<USERPROFILE>\.redvig\bin\redvig.cmd" mcp"` ([launcher.md](launcher.md)).
- Replacing `redvig.cmd` while `cmd.exe` runs it works: `cmd.exe` opens the file with full sharing.
- The install script also adds the directory to the current PowerShell session ([install-scripts.md](install-scripts.md)).

## 3. Auto-update

In `redvig mcp` only, as specified in [updates.md](updates.md):

- Check the off switches (`~/.redvig/no-update`, `REDVIG_NO_UPDATE`, dev build) before every network
  call.
- Verify the `.sig` file natively ([signing.md](signing.md)) before reading anything from the script.
- Run the verified file as it is: `/bin/sh <file>` on macOS and Linux; on Windows, the file is named
  `*.ps1` (Windows PowerShell's `-File` accepts no other extension) and run with
  `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive
  -ExecutionPolicy Bypass -File <file>`. Stdin is closed, and output goes to the update log.
- On timeout, kill the whole process tree: repeat "kill every descendant, then the script host" until
  no descendant is left (the tree can change while it is being killed), and only then clean up.
- Manage the marker files, write `updated-<version>`, and print the restart notice once per process,
  also as an MCP `notifications/message`.
- An update failure never stops or slows the session. Errors are logged at most once per check.

## 4. What the binary does not do

It does not download modules, unpack archives, build URLs, or install system packages: that is the
install script's job. It does not edit agent or IDE configuration during install or update.
