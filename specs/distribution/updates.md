# Updates

An update is running today's install script. The installed binary downloads the script and its
signature, checks the signature with its built-in keys ([signing.md](signing.md)), and runs the bytes it
checked. The binary knows nothing about modules, archive URLs, or unpacking, so the update logic in an
old version cannot go out of date.

## When

Only long-lived sessions (`redvig mcp`) update. The first check runs 1–60 s after start, then one every
3–8 h, both with random jitter. Other commands never touch the network for updates. To update by hand,
re-run the install one-liner.

## Turning updates off

Auto-update is off when either is true:

- the file `~/.redvig/no-update` exists (contents ignored);
- `REDVIG_NO_UPDATE` is `1`, `true`, `yes`, or `on` (any case).

Dev builds never update. The file is there because agents often start `redvig mcp` with an
environment the user did not set up, and a file works for every process. Delete it to turn updates back
on.

## One check

Each step continues or **stops**. Stopping leaves the installed version as it was, and the next check
tries again. There is no retry limit.

1. Updates off → stop.
2. Download `install.sh.sig`, then `install.sh` (`install.ps1*` on Windows), with a cache-busting query
   and a 30 s timeout, into a new private file in `update/` (named `*.sh` / `*.ps1`). Failure → stop.
3. Check the signature, then read the header line. Failure → delete the file, print one warning on
   stderr, stop. **An unsigned or badly signed script never runs.**
4. If the header version is not newer than the running version → delete, stop.
5. If `updated-<version>` exists → print the restart notice, delete, stop.
6. If another process holds a live `update-<pid>-version-*` marker → delete, stop.
7. Create own marker `update-<pid>-version-<version>`. If a live marker with a lower pid now exists, or
   updates were turned off meanwhile, remove own marker and stop.
8. Run the checked file: `/bin/sh <file>`, or on Windows
   `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive
   -ExecutionPolicy Bypass -File <file>`. Stdin closed; output to `logs/update-<pid>-<version>.log`.
   After 1 h, kill the process and all its children.
9. Exit code 0 → create `updated-<version>` and print the restart notice. Other result → print one line
   on stderr with the log path. In every case, remove own marker and the file.

**Markers:** only the file name (pid, version) and mtime matter. A marker is stale when its pid is not
alive or it is older than 24 h; whoever sees a stale marker deletes it. Each check also deletes
`updated-<v>` records older than the running version, and logs older than 30 days. There are no locks.
If two processes update at the same moment, the scripts still produce correct module directories. In
the rare case that two different versions write the launcher within milliseconds of each other, the
last write wins. Accepted for v1: the next release, or re-running the one-liner, fixes it.

**Restart notice:** `redvig <version> is installed - restart your agent session to use it.` Printed
once per process on stderr, and sent as an MCP `notifications/message`. Nothing on the update path
writes to stdout, which carries the MCP protocol.

## Fallback

The installed version keeps working whatever fails:

| Failure | Result |
|---|---|
| No network, proxy, HTTP error, timeout | Nothing changes. Try again at the next check. |
| Bad signature, unknown key, bad header, older version | The script is deleted and never run. |
| A module download, hash check, or unpack fails | No partial directory gets its final name. The script stops before the handoff, so the launcher is unchanged. |
| The new binary cannot start, or `install redvig` fails | The launcher still points at the old version. No `updated-` record. |
| A broken release goes out | Publish a fixed, higher version. |
