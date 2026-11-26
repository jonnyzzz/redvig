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

What the machine needs: `sh`, `curl` or `wget`, `sha256sum` or `shasum`, and Docker for the website.
These are the same tools the install scripts need ([install-scripts.md](../distribution/install-scripts.md)).

To upgrade: change `.bazelversion`. To upgrade Bazelisk: change the version and the four (plus two
Windows) hashes in the wrappers, using the `digest` values from the GitHub release.

## Layout

```
MODULE.bazel           Bazel modules (bzlmod; Bazel 9 has no WORKSPACE)
MODULE.bazel.lock      resolved module graph, committed; CI fails when stale (--config=ci)
.bazelrc               shared flags; machine flags go in user.bazelrc (git-ignored)
BUILD.bazel            the root package
tools/docker/repo.bzl  @docker_cli//:docker, the host docker CLI with an absolute path
tools/hugo/            hugo_site rule, its action script, and IMAGE (Hugo image pinned by digest)
website/BUILD.bazel    //website:site, //website:site_test, //website:dev
```

| Target | What it does |
|---|---|
| `//website:site` | The production site as a directory, `bazel-bin/website/site/` |
| `//website:site_test` | Checks pages, `CNAME`, and assets in the built site |
| `//website:dev` | `bazel run` it for the live-reload preview (`-- PORT` to change the port) |

## How the website builds

The rule is that Hugo runs only in the pinned Docker image. Bazel keeps that rule:

1. `hugo_site` declares every file under `content/`, `layouts/`, `static/`, and `hugo.toml` as
   inputs, plus `tools/hugo/IMAGE`. The action key covers all sources and the image digest, so a
   cached result is correct: the same inputs give the same site.
2. The action copies the sources (resolving the sandbox's symlinks) into a tar, pipes it into
   `docker run --network none`, runs Hugo, and reads the site back as a tar on stdout. Nothing is
   bind-mounted, so this works in the macOS and Linux sandboxes and with a remote Docker daemon.
3. The action is tagged `no-remote-exec` because it needs the local Docker daemon. Its outputs can
   still go to a remote cache.
4. Actions run with a fixed `PATH` (`--incompatible_strict_action_env`). `@docker_cli` finds `docker`
   once, when the repository is fetched, so Homebrew and Docker Desktop installs work. A machine
   without Docker can still build every target that does not need it.

The dev preview stays outside the action graph on purpose. It bind-mounts the real `website/` so
edits reload, which Bazel actions must not do.

We considered and rejected two alternatives:

- **A Hugo binary fetched with `http_archive`.** This would be more hermetic and need no Docker, but it
  breaks the Docker-only rule and needs a binary per platform.
- **`rules_oci` to pull the image.** It pins the image in `MODULE.bazel`, but `docker load` still needs
  a daemon. The digest in `IMAGE` gives the same guarantee for less code.

## Next: install scripts and their tests

The [test strategy](../distribution/test-strategy.md) maps onto Bazel like this:

| Piece | Bazel shape |
|---|---|
| `render(templates, version, modules)` generator | A binary target (`//dist/installgen`), in Kotlin once the JVM rules are in, and called by a rule `install_scripts(templates, module_table)` |
| Rendered `install.sh` / `install.ps1` | Outputs of that rule. `//website:site` takes them as inputs, so the site always ships the scripts it was tested with |
| Layer 1: script text, generator, `sh -n` | `sh_test` and JVM tests, on every OS. They are hermetic and cacheable |
| Layer 2: container lanes (dash, alpine, HTTPS side-car) | `sh_test` with `tags = ["requires-docker", "no-remote-exec"]`, through `@docker_cli`, with images pinned by digest like Hugo |
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
