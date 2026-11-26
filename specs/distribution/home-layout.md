# Home layout

The home is `~/.redvig` (`%USERPROFILE%\.redvig` on Windows), laid out like devrig's `~/.mcp-steroid`.
It is not configurable; tests change `HOME` / `USERPROFILE` instead.

```
~/.redvig/
├── bin/redvig, bin/redvig.cmd        launcher on PATH          written by the binary
├── binaries/                                                   written by the install scripts
│   ├── <module>-<os>-<cpu>-<version>-<sha12>/   one module, unpacked as is
│   └── .tmp.*                        download and unpack staging
├── update/                           update markers, downloaded script     written by the binary
├── logs/                             update logs                            written by the binary
└── no-update                         optional: if present, auto-update is off
```

- `<sha12>` is the first 12 hex characters of the archive's SHA-256. `<version>` is the module's own
  version (the JDK's vendor version, not redvig's).
- A module directory gets its final name only by renaming a fully unpacked and checked staging
  directory, so "the directory exists" means "installed".
- Archives are unpacked as they are, without stripping or moving anything. Paths inside come from the
  module table.
- Install scripts delete `binaries/.tmp.*` entries older than 24 h. Module directories are never
  deleted in v1. The updater cleans up its own files in `update/` and `logs/` ([updates.md](updates.md)).
- The product may add its own directories under the home, using names other than these.
