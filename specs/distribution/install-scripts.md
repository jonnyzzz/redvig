# Install scripts

```sh
curl -fsSL https://redvig.dev/install.sh | sh
```
```powershell
irm https://redvig.dev/install.ps1 | iex
```

These are the same scripts the updater runs ([updates.md](updates.md)). Each one does two things:

1. Download, check, and unpack every module of the current platform ([modules.md](modules.md)).
2. Hand off to the core: `install redvig`, which writes the launcher and registers `PATH`.

Nothing else. The scripts never write `~/.redvig/bin`, never change shell profiles or the user's
environment (except that `install.ps1` adds `~\.redvig\bin` to the current session's `PATH`), never register redvig with an agent or an IDE, never install system packages or use
`sudo`, never prompt, and never ask a server what to install.

## Generation

At release time the scripts are rendered from `install.sh.tmpl` and `install.ps1.tmpl`. The templates
hold all the logic; the generator fills in only the version and the module table. Every value is
written as a quoted literal, escaped for the script's language. Generation fails if a placeholder is
left over, a platform is missing, or the output contains non-ASCII bytes (PowerShell 5.1 misreads
UTF-8 without a BOM). Rendering does no network or disk access, so tests can render real scripts from
test data.

## `install.sh` (POSIX `sh`)

- Line 2 is the header line from [signing.md](signing.md). All the code is inside `main()`, called on
  the last line, so a download cut off halfway runs nothing.
- `set -eu`. All messages go to stderr.
- Platform from `uname -s` / `uname -m` (`REDVIG_OS` / `REDVIG_CPU` override it, for tests). On Linux,
  musl is rejected before any download.
- Needs `curl` or `wget`, `sha256sum` or `shasum`, and `unzip` or `tar`. If any is missing, it prints
  what to install and exits.
- For each module:
  1. If the target directory exists, skip the module.
  2. Download into a new `binaries/.tmp.*` directory: `curl -fsSL --retry 3 --connect-timeout 30` or
     `wget -q --tries=3`.
  3. Check the SHA-256, unpack, and check `path`.
  4. `mv` the result to the target. If another installer got there first, delete own copy and use
     theirs: the same name means the same archive.
- Hand off with stdin from `/dev/null` and the module variables set only for that child. A non-zero exit
  fails the script.

## `install.ps1` (PowerShell 5.1 and 7)

- Same steps. The header line is line 1. The code runs inside `& { ... }` with
  `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`. TLS 1.2 is enabled.
- `$ProgressPreference = 'SilentlyContinue'` while it runs (the progress bar makes downloads crawl).
  The old value is restored in `finally`, because `irm | iex` runs in the caller's session.
- CPU from `PROCESSOR_ARCHITEW6432`, then `PROCESSOR_ARCHITECTURE`. (`RuntimeInformation` is missing
  on the .NET that base Windows 10 ships.)
- Uses `Invoke-WebRequest -UseBasicParsing`, `Get-FileHash`, and `Expand-Archive`. `Move-Item` puts
  the source inside an existing directory instead of failing, so the script checks for that case.
- Hands off with `$null | & $start install redvig`, checks `$LASTEXITCODE` on the next line, then adds
  `~\.redvig\bin` to the current session's `$env:PATH`.

Exit code 0 means installed (or already installed). Anything else is a failure with one `ERROR:` line
on stderr.
