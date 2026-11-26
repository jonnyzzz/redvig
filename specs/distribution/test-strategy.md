# Test strategy

Distribution code breaks on machines we do not own, so every rule in these specs has a test. The lanes
follow devrig's and add the update signature. A rule without a test is a gap in this document.

## Principles

- **Test the property, not the diff.** For example, assert that `$ProgressPreference` is set before the
  first download, not that a given line exists.
- **Real shells, real OSes.** Unit tests check logic. Only real `sh`, `powershell.exe`, macOS, and
  Windows prove behaviour.
- **No real network in default runs.** Fixtures are served locally over HTTPS with a test CA. Tests
  that reach vendors run only at release time.
- **Test keys only.** Tests sign fixtures with ed25519 keys generated in the test. The binary under test
  takes a test key set through a seam that release builds do not have.
- **A home with a space**, and on Windows also a non-ASCII one: `HOME="/home/tester one"`,
  `USERPROFILE="C:\Users\tester one"` and `C:\Users\Тест`.

## Test seams

| Seam | Used by |
|---|---|
| `render(templates, version, modules) -> scripts`, pure | generator and all script lanes |
| A fake core: a tiny script with the core's start-script name that records its arguments, environment, and stdin, and returns a chosen exit code | script lanes |
| Updater with injectable HTTP, clock, random jitter, process spawner, pid-liveness check, home, and key set | updater unit tests |
| `REDVIG_OS` / `REDVIG_CPU` | script lanes for other platforms |
| A fixture installer that starts a child and a grandchild and then hangs | native timeout tests |

## Layer 1: unit tests (every push, all OSes, seconds)

**Generator and module table** ([modules.md](modules.md), [install-scripts.md](install-scripts.md)):
every platform present; `redvig` required; bad `id`, non-HTTPS or `latest` URL, unknown `format`,
`zip`-only on Windows, absolute or `..` `path`, and a `path` missing from the archive are all rejected;
no leftover placeholders; ASCII only; values with `'`, spaces, or `$` still produce working scripts; the
header version equals `VERSION`; each core archive's version file equals `redvig --version` of that build;
a third-party module without a `license` file is rejected.

**Script text:** `install.sh` ends with `main "$@"` and has only definitions before it; `$ProgressPreference`
is set before the first download and restored in `finally`; no `RuntimeInformation` lookup outside `try`;
`$LASTEXITCODE` is read right after the handoff; no agent registration, no write to `bin/`, no `sudo`, no
profile edit; `sh -n` and the PowerShell parser accept the rendered scripts.

**Signature** ([signing.md](signing.md)): a valid signature from either built-in key is accepted.
Rejected: one changed byte; an unknown key; wrong namespace; `SSHSIG` version other than 1; hash other
than `sha512`; non-ed25519 keys; a key in the signature that differs from the built-in one; a truncated,
garbage, or over-16-KiB `.sig`; a script over 1 MiB; a missing header, a bad version (`1.4`, `01.4.0`),
or a wrong `script=` value. The header is never read before verification. A real `ssh-keygen -Y sign`
signature verifies (committed fixture). The verifier code path has no call to `ssh-keygen` and no way
to load keys at runtime (checked by a test that lists the compiled-in keys).

**Version order:** numeric per part (`1.10.0` > `1.9.0`); a dev version never updates.

**Updater** ([updates.md](updates.md)):
- the first check falls in 1–60 s and later ones in 3–8 h;
- `.sig` is requested before the script, both with a cache-busting query and a 30 s timeout;
- each off switch (the file, each variable value, dev build) makes no network call, including one
  created between the two requests;
- not newer → nothing runs; `updated-<v>` → restart notice only;
- lower pid wins; stale markers are deleted;
- a bad signature never spawns;
- a failure retries at the next check; old `updated-` records and logs over 30 days are deleted;
- the restart notice appears once per process on stderr and once as an MCP notification;
- while checks fail, the session keeps answering MCP requests without delay;
- nothing but MCP frames appears on stdout, on every path.

**Binary contract** ([binary-contract.md](binary-contract.md)):
- `install redvig` fails before writing anything when a module path is missing;
- an unlisted `REDVIG_MODULE_X` is ignored, and the binary never lists `binaries/`;
- it is idempotent;
- the newer-launcher guard keeps a newer launcher;
- a failed rename keeps the old launcher;
- the POSIX launcher is mode `0755` and the Windows launcher is pure ASCII with CRLF;
- a `PATH` problem only warns.

**Profile choice** (with a fake home): zsh with and without `ZDOTDIR`; bash with each of
`.bash_profile` / `.bash_login` / `.profile` present, and with none; fish (no file changed). The block is
added once, and the rest of the file is kept byte for byte. An existing symlink that does not point into
`~/.redvig`, or a regular file named `redvig` in a `PATH` directory, is left alone.

**Licenses** ([licenses.md](licenses.md)): every file passes the CycloneDX 1.6 schema and has the
required fields and full texts; a module `license` id with no file fails; `THIRD-PARTY-NOTICES.txt` is
generated from the right files and is present in the core archive.

## Layer 2: script lanes in containers (every push, Linux x64 and arm64 runners, minutes)

An HTTPS side-car serves the fixture archives. The fake core stands in for redvig.

- **ubuntu, dash:** a release with a core and a JDK module. A fresh install downloads each archive
  once, the directory names are right, the handoff gets the module variables with stdin at EOF, and
  stdout stays empty. A second run downloads nothing.
- **Failure cases:**
  - `wget` only;
  - `unzip` missing: fails before any download;
  - a tampered archive, a corrupt archive, and an archive missing `path`: no directory created;
  - a script cut off halfway runs nothing;
  - two installers at once: one directory, both exit 0;
  - a fake core that fails: the script fails and the launcher is unchanged;
  - `.tmp.*` older than 24 h is removed, and newer ones are kept.
- **alpine:** musl is refused before any download.
- **Update end to end, with the real core:** install A; serve a signed B; start `redvig mcp`: B is
  installed, the launcher points at B, and the restart notice appears. Then serve a script signed by an
  unknown key and one with an older version: nothing runs.
- **Timeout:** the fixture installer hangs; after the (test-shortened) timeout, the child and the
  grandchild are gone before the marker is removed, and the next check retries.

## Layer 3: native macOS (`macos` arm64 runner)

- Run the rendered `install.sh` with the real core, from `bash`, `zsh`, and `sh`, in a fresh `HOME`.
- **PATH:** `~/.redvig/bin` already on `PATH`; a writable `~/.local/bin` on `PATH` (symlink made); and
  neither, with `SHELL=/bin/zsh` and with `SHELL=/bin/bash`. In the last case, a new login shell
  (`zsh -l -c` / `bash -l -c 'command -v redvig'`) finds the launcher.
- The launcher runs with the bundled JDK, not with a `JAVA_HOME` from the environment.
- Update end to end and the timeout test, as in layer 2, with the macOS build.

## Layer 4: native Windows (`windows` x64 and arm64 runners)

Run everything under both `powershell.exe` 5.1 and `pwsh` 7, with a spaced profile and a non-ASCII
profile:

- `irm <local https>/install.ps1 | iex` with the real core: the install succeeds; the output never
  contains `The property 'OSArchitecture' cannot be found`; the caller's `$ProgressPreference` and
  environment are as before, apart from the session `PATH`.
- A fake core that exits 42 makes the script fail.
- Failure cases: a tampered archive, a corrupt archive, and an archive missing `path` leave no
  directory; two installers at once both succeed.
- **PATH:** the test saves the user `Path` and restores it afterwards. It runs three times: with `Path`
  missing, as `REG_SZ`, and as `REG_EXPAND_SZ` containing `%USERPROFILE%` and an entry longer than 1024
  characters. Afterwards the entry appears once, the type and every other entry are unchanged, and
  `%USERPROFILE%` is still unexpanded. The `REG_SZ` case gets the absolute path. In each case a process
  started with the environment built from the refreshed registry finds `redvig`. A second install adds
  nothing.
- **Broadcast:** a small test window started before the install receives `WM_SETTINGCHANGE` with
  `"Environment"`.
- **`redvig.cmd`:** run as `cmd.exe /d /s /c ""...\redvig.cmd" <args>"` (with a spaced profile and an
  argument containing a space) from Java `ProcessBuilder`, from Node
  `child_process.spawn`, and from an interactive `cmd.exe`, with the supported argument characters; the core receives the same arguments and the exit code passes through. The caller's
  environment is unchanged afterwards. The launcher is replaced while another `cmd.exe` runs it.
- Update end to end through `powershell.exe -File` on a `.ps1` file in the profile, and the timeout
  test (child and grandchild killed).

## Layer 5: release checks (every release, real network)

- Resolve the vendor modules and check their vendor signatures.
- Download every module URL in the new scripts and compare hashes.
- Verify both `.sig` files with the verifier from the **previous** release's binary, which is what
  installed copies will run.
- The CI checks before deploy ([release-process.md](release-process.md)).

## Gating

- Layers 1 and 2 must pass on every PR.
- Layers 3 and 4 must pass before merging any change to the templates, the generator, the module table,
  the core's start script, the updater, or the binary contract.
- Layer 5 must pass before the website commit of a release.
