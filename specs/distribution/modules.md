# Modules

A release is a set of **modules**. Each module is one archive for one platform, unpacked into its own
directory in `~/.redvig/binaries/`. The **core** module `redvig` (the binary) is required on every
platform. Others are per release, for example a JDK that the core runs on, an IDE plugin, or a native
helper. The install scripts do not care what a module is for, so adding one changes release data, not
script code.

## Module table

The release bakes into the scripts a list of modules for each supported platform
(`linux-x64`, `linux-arm64`, `macos-arm64`, `windows-x64`, `windows-arm64`):

| Field | Meaning |
|---|---|
| `id` | `[a-z][a-z0-9-]*`, unique per platform. `redvig` is the core. |
| `version` | The module's own version. |
| `url` | `https://`, a fixed release URL (never `latest`). |
| `sha256` | SHA-256 of the archive. |
| `format` | `zip` or `tar.gz` (`zip` on Windows). |
| `path` | A relative path inside the unpacked archive. For the core, its start script. For a JDK, the Java home. |
| `license` | For third-party modules: the id of its file in `/licenses`. |

When the release is built, the generator downloads every archive, checks its hash, rejects absolute or
`..` paths, and checks that `path` exists. A third-party runtime archive must also pass the vendor's
signature check.

## Handoff to the core

Once all modules of the platform are in place, the script runs the core's start script with
`install redvig`. The module paths go only to that one child process, through these variables:

- `REDVIG_MODULE_<ID>`: the absolute `path` of each module (id upper-cased, `-` becomes `_`, for
  example `REDVIG_MODULE_JDK`);
- `REDVIG_MODULES`: the release's module ids, separated by spaces. The core ignores any
  `REDVIG_MODULE_*` variable whose id is not in this list.

The core writes the same variables into the launcher ([launcher.md](launcher.md)). For a JVM core, its
start script takes `JAVA_HOME` from `REDVIG_MODULE_JDK`.

If any module fails to install, the script stops before the handoff, and the launcher stays on the
previous release.
