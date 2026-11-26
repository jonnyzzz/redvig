# Launcher

`~/.redvig/bin/redvig` (`redvig.cmd` on Windows) is the fixed entry point. `PATH` and agent
registrations point here, never at a module directory, so they survive every update. The **binary**
writes the launcher; install scripts never do.

```sh
#!/bin/sh
# redvig launcher - managed by the redvig binary. Do not edit.
# redvig launcher version: <version>
REDVIG_MODULES='redvig jdk'; export REDVIG_MODULES
REDVIG_MODULE_REDVIG='<core start script>'; export REDVIG_MODULE_REDVIG
REDVIG_MODULE_JDK='<jdk home>'; export REDVIG_MODULE_JDK
exec '<core start script>' "$@"
```

```bat
@echo off
setlocal DisableDelayedExpansion
rem redvig launcher - managed by the redvig binary. Do not edit.
rem redvig launcher version: <version>
set "REDVIG_MODULES=redvig jdk"
set "REDVIG_MODULE_REDVIG=%~dp0..\binaries\<core dir>\<core start script>"
set "REDVIG_MODULE_JDK=%~dp0..\binaries\<jdk dir>\<jdk home>"
"%REDVIG_MODULE_REDVIG%" %*
```

- **POSIX:** absolute paths as single-quoted literals (`'` is written as `'\''`). The file is UTF-8, so
  any home path works.
- **Windows:** paths are relative to the launcher's own folder (`%~dp0` = `...\.redvig\bin\`). Module
  directory names and in-archive paths are ASCII, so the file is pure ASCII and works for any user
  profile name, including non-ASCII ones, with no code-page issues.
- The launcher writes nothing to stdout. The Windows launcher does not start PowerShell.
- **Arguments:** the POSIX launcher passes `"$@"` exactly.
- **Windows callers** cannot start a `.cmd` file directly (`CreateProcess` needs `cmd.exe` for batch
  files). Agent registrations and any other program start it as:
  ```
  cmd.exe /d /s /c ""<USERPROFILE>\.redvig\bin\redvig.cmd" <args>"
  ```
  Everything after `/c` is **one** argument wrapped in an extra pair of quotes, which `/s` makes `cmd`
  strip exactly, so a quoted launcher path and quoted arguments both survive. Programs pass that
  string as a single argument (Node: `windowsVerbatimArguments: true`). This is the form written into
  agent configuration. `%*` then passes the arguments unchanged if they use only letters, digits,
  spaces (inside a pair of quotes), `-`, `=`, `/`, `\`, `:`, and `.`. Arguments with `%`, `!`, `&`, `|`, `^`, or embedded `"` are not supported.

The binary writes and replaces this file; see `install redvig` in [binary-contract.md](binary-contract.md).
