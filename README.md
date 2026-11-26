# redvig

Static tools to boost AI coding. The website source for [redvig.dev](https://redvig.dev/) lives in [website/](website/).

## Build

Bazel builds the whole repository. You do not need to install it: run the committed wrapper `./bazelw` (`bazelw.cmd` on Windows), which downloads a pinned, checksum-verified [Bazelisk](https://github.com/bazelbuild/bazelisk), which in turn downloads the Bazel version in [.bazelversion](.bazelversion). Nothing else is needed: Hugo is downloaded the same way.

```sh
./bazelw test //...                  # build and test everything
./bazelw build //website:site        # production site in bazel-bin/website/site/
./bazelw run //website:dev           # live-reload preview at http://localhost:1313/
./bazelw run //website:dev -- 8080   # preview on another port
```

Hugo is a pinned, checksum-verified release binary ([tools/hugo/extensions.bzl](tools/hugo/extensions.bzl)), and the layout refuses to render outside Bazel. The first run downloads Bazel and Hugo. Dev mode serves from memory, includes drafts, and rebuilds when files under `website/` change. See [specs/build/bazel.md](specs/build/bazel.md) for how the build is set up.

## GitHub Pages

Pages is set to deploy from **GitHub Actions** with the custom domain `redvig.dev`. To set it up again with `gh`, run:

```sh
gh api -X POST repos/jonnyzzz/redvig/pages -f build_type=workflow
gh api -X PUT repos/jonnyzzz/redvig/pages -f cname=redvig.dev
```

The [deploy workflow](.github/workflows/pages.yml) runs when website files change on `main` and can also be run manually. Hugo copies [CNAME](website/static/CNAME) into the artifact. The Pages setting controls the domain for Actions deployments.

Configure the domain's public DNS separately, then enable **Enforce HTTPS** in Pages once GitHub issues the certificate.
