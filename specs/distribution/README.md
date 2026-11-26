# redvig distribution specs

How redvig is installed, launched, updated, and how its third-party licenses are recorded.

| Spec | What it defines |
|---|---|
| [install-scripts.md](install-scripts.md) | `install.sh` / `install.ps1`, generated per release |
| [modules.md](modules.md) | A release as a set of per-platform modules (core, JVM, ...) |
| [home-layout.md](home-layout.md) | `~/.redvig` on disk |
| [launcher.md](launcher.md) | `~/.redvig/bin/redvig`, written by the binary |
| [binary-contract.md](binary-contract.md) | What the core binary must do: launcher, `PATH` on macOS and Windows, updates |
| [signing.md](signing.md) | Why and how auto-update checks signatures |
| [updates.md](updates.md) | Auto-update, the no-update switch, fallback |
| [release-process.md](release-process.md) | Building, signing, and publishing a release |
| [licenses.md](licenses.md) | `/licenses`: one CycloneDX file per dependency |
| [test-strategy.md](test-strategy.md) | Tests |

## The design in five lines

1. **Install trusts HTTPS.** `curl -fsSL https://redvig.dev/install.sh | sh` runs a generated script.
   Every module's URL and SHA-256 is baked into it, as in devrig.
2. **Update is install.** A running redvig downloads the current `install.sh` and runs it. When the
   script changes, there is an update.
3. **Updates must be signed.** The script runs only if its `.sig` verifies with a key built into the
   **installed** version, so an old version checks the new one. Signing works as in our previous Go
   version: `SSHSIG` files and embedded keys.
4. **Failure means stay put.** New versions are installed next to the old ones. The launcher moves only
   after the new binary has started. Any failure leaves the current version working.
5. **Updates can be turned off** with `~/.redvig/no-update` or `REDVIG_NO_UPDATE=1`.

Requirements on the machine are what a stock OS ships: `sh`, `curl` or `wget`, `sha256sum` or
`shasum`, `tar` or `unzip`, and PowerShell 5.1 or later on Windows.

Not in v1: garbage collection of old versions, an uninstall command, a rollback command, manual update
commands (re-run the one-liner instead), package managers, musl, Intel macOS, and a configurable home.
