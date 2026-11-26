# Bazel build

Bazel is the root build system for the whole repository. One command builds and tests everything:

```sh
./bazelw test //...
```

## No install needed: `./bazelw`

Bazel has no official wrapper like `gradlew`. Its launcher is [Bazelisk](https://github.com/bazelbuild/bazelisk),
which reads `.bazelversion` and downloads that Bazel. We commit a tiny wrapper around it:

| File | Job |
|---|---|
| `bazelw` (POSIX `sh`) and `bazelw.cmd` (Windows) | Download Bazelisk `v1.31.0` for this OS and CPU, check its SHA-256, cache it in `~/.cache/redvig/bazelisk/` (`%LOCALAPPDATA%\redvig\bazelisk\` on Windows), and run it with the given arguments |
| `.bazelversion` | Pins Bazel (`9.3.3`). Bazelisk downloads it into `~/.cache/bazelisk/` and checks Bazel's signature |

What the machine needs: `sh`, `curl` or `wget`, and `sha256sum` or `shasum`. No Docker, no Hugo, no
JDK. These are the same tools the install scripts need ([install-scripts.md](../distribution/install-scripts.md)).

To upgrade: change `.bazelversion`. To upgrade Bazelisk: change the version and the four (plus two
Windows) hashes in the wrappers, using the `digest` values from the GitHub release.

## Layout

```
MODULE.bazel           Bazel modules (bzlmod; Bazel 9 has no WORKSPACE)
MODULE.bazel.lock      resolved module graph, committed; CI fails when stale (--config=ci)
.bazelrc               shared flags; machine flags go in user.bazelrc (git-ignored)
BUILD.bazel            the root package
tools/hugo/            Hugo toolchain: pinned binaries (extensions.bzl), rules (defs.bzl), action script
website/BUILD.bazel    //website:site, //website:site_test, //website:dev
```

| Target | What it does |
|---|---|
| `//website:site` | The production site as a directory, `bazel-bin/website/site/` |
| `//website:site_test` | Checks pages, `CNAME`, and assets in the built site |
| `//website:dev` | `bazel run` it for the live-reload preview (`-- PORT` to change the port) |

## How the website builds

Hugo is a single static Go binary, and the site uses no Sass, image processing, or JS pipes. So the
build uses a plain Hugo release binary as a Bazel toolchain rather than a container:

1. `tools/hugo/extensions.bzl` declares one repository per platform: Linux and Windows (amd64 and
   arm64), and macOS (universal). Each archive is pinned by the SHA-256 from Hugo's `checksums.txt`.
   macOS ships only a `.pkg`, so a small repository rule unpacks it with `pkgutil`.
2. `tools/hugo/BUILD.bazel` registers a toolchain for each one. Toolchain resolution picks the one for
   the machine that runs the build, and only that archive is downloaded. The per-platform targets are
   tagged `manual` so that `//...` does not fetch them all.
3. `hugo_site` declares every file under `content/`, `layouts/`, `static/`, and `hugo.toml` as inputs.
   The action copies them out of the sandbox (Hugo does not follow the sandbox's symlinks) and runs
   Hugo with an empty environment, a private `HOME` and cache, and `block-network`.
4. The action key covers the sources, the action script, and the Hugo binary. So results are shared
   across machines through a disk or remote cache, and the action can run on remote executors.
5. `bazel run //website:dev` runs the same binary as a live-reload server on the real `website/`
   directory, so edits reload. It is a `bazel run` target, not a build action.

The output is byte-for-byte identical to the earlier Docker-based build (checked with `diff -r` on
2026-11-26).

We considered and dropped two alternatives:

- **Hugo in the pinned Docker image.** This was the first version. It needed a running Docker daemon
  that Bazel cannot see. It pulled the image during the build, outside Bazel's fetch and cache, and
  ignored `DOCKER_HOST`. Its cache keys depended on the host's docker path, it could not run remotely
  or on Windows runners, and Docker Desktop needs a paid licence in larger companies.
- **Building Hugo from source with `rules_go`.** This would be the most hermetic, but it adds a large
  Go dependency graph and a slow first build for no gain over checksum-pinned releases.

Windows note: the `hugo_site` action is a POSIX `sh` script, so Windows builds need Bazel's MSYS2
`bash`, which GitHub's Windows runners have. The Windows Hugo toolchains are already registered.

## Next: install scripts and their tests

The [test strategy](../distribution/test-strategy.md) maps onto Bazel like this:

| Piece | Bazel shape |
|---|---|
| `render(templates, version, modules)` generator | A binary target (`//dist/installgen`), in Kotlin once the JVM rules are in, and called by a rule `install_scripts(templates, module_table)` |
| Rendered `install.sh` / `install.ps1` | Outputs of that rule. `//website:site` takes them as inputs, so the site always ships the scripts it was tested with |
| Layer 1: script text, generator, `sh -n` | `sh_test` and JVM tests, on every OS. They are hermetic and cacheable |
| Layer 2: container lanes (dash, alpine, HTTPS side-car) | `sh_test` with `tags = ["requires-docker", "no-remote-exec"]` and images pinned by digest. This is where Docker belongs: the container is the thing under test. Find `docker` through a repository rule that also passes `DOCKER_HOST` and `DOCKER_CONTEXT` |
| Layer 3: native macOS | Tests with `target_compatible_with = ["@platforms//os:macos"]`. They are skipped elsewhere and run on the macOS runner |
| Layer 4: native Windows | `target_compatible_with = ["@platforms//os:windows"]`. `powershell.exe` and `pwsh` come from the host, tagged `local` |
| Layer 5: release checks (real network) | `tags = ["manual", "requires-network"]`, run only by the release workflow |

The CI matrix then becomes `./bazelw test //...` on `ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`,
and `windows-latest`. Each runner runs the tests that are compatible with it, and the disk cache skips
the rest.

## Later: the JVM

Add these modules when the first JVM code lands (versions current on 2026-11-26):

```starlark
bazel_dep(name = "rules_java", version = "9.9.0")
bazel_dep(name = "rules_kotlin", version = "2.4.21")
bazel_dep(name = "rules_jvm_external", version = "7.2")

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    artifacts = [...],
    lock_file = "//:maven_install.json",  # pinned with ./bazelw run @maven//:pin
)
use_repo(maven, "maven")
```

And in `.bazelrc`, use a JDK downloaded by Bazel rather than the machine's `JAVA_HOME`:

```
common --java_runtime_version=remotejdk_21
common --tool_java_runtime_version=remotejdk_21
common --java_language_version=21
```

- The JDK that redvig bundles ([modules.md](../distribution/modules.md)) can come from the same pinned
  remote JDK archives, so the build and the shipped runtime match.
- Maven artifacts are locked with hashes in `maven_install.json`, like `MODULE.bazel.lock`.
- In IntelliJ IDEA, open the repository with the JetBrains Bazel plugin.

## CI

- `.github/workflows/ci.yml` runs `./bazelw test --config=ci //...` on every push and PR.
- `.github/workflows/pages.yml` builds and tests `//website/...` and uploads `bazel-bin/website/site/`.
- Both use `bazel-contrib/setup-bazel` only for its caches (Bazelisk, disk, and repository caches). The
  build itself still goes through `./bazelw`.
- Later, a remote cache (for example BuildBuddy, EngFlow, or `bazel-remote`) can be added with a
  `--config=remote` block in `.bazelrc`.
