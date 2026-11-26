# Agent notes for redvig

## Product

- **redvig is a new product** for the market. It gives AI coding agents real IDE tools: the project model, typed refactors, inspections, a debugger, and test runs. This repository holds it and its website, [redvig.dev](https://redvig.dev/).
- **devrig ([devrig.dev](https://devrig.dev/)) is the previous version, not redvig.** Never sell, install, or document devrig on redvig pages, and never present devrig's claims or numbers as redvig's. You may mention it only as "our previous version", for example when linking to its published eval findings.
- redvig works with any coding agent and any model provider or subscription. It is built on an open-source core.

## Build

- **Bazel is the root build system** for the whole repository: the website now, then the install scripts, their tests, and the JVM code. See [specs/build/bazel.md](specs/build/bazel.md).
- Always run Bazel through the committed wrapper, `./bazelw` (`bazelw.cmd` on Windows). Never ask anyone to install Bazel. The wrapper pins Bazelisk by SHA-256, and `.bazelversion` pins Bazel.
- `./bazelw test //...` builds and tests everything. CI runs the same command with `--config=ci`.
- Bazel 9 has no built-in shell rules. Load `sh_binary` and `sh_test` from `@rules_shell`.
- Commit `MODULE.bazel.lock`. CI fails when it is stale.

## Website

- The site is Hugo under `website/`. Hugo runs **only** in the pinned Docker image, through Bazel or the dev script:
  - `./bazelw build //website:site` makes the production build in `bazel-bin/website/site/`, and `//website:site_test` checks it.
  - `./bazelw run //website:dev [-- PORT]` runs the live-reload preview at `http://localhost:1313/`.
- Never build or serve the site any other way: no local `hugo`, `python -m http.server`, `npx serve`, or opening HTML from disk. `layouts/baseof.html` fails the build unless `HUGO_REDVIG_DOCKER=1` is set by our scripts. Keep that guard.
- `tools/hugo/IMAGE` pins the Hugo image by digest. The build action runs it with `--network none` and `--panicOnWarning`, so fix deprecation warnings rather than silencing them.
- Pages:
  - `layouts/baseof.html` holds the shared head, nav, and footer.
  - `layouts/home.html` is the homepage.
  - `layouts/pricing.html` with `content/pricing.md` is `/pricing/`.
  - Build asset and page links with `relURL` so they work from any page.
- Deploy: `.github/workflows/pages.yml` publishes to GitHub Pages on push to `main`. The custom domain is `redvig.dev`, behind Cloudflare DNS.

## Commercial messaging

- **Two editions:**
  - **Personal** is free for personal use. The main CTA is to try it and tell us what you find, with feedback through GitHub issues.
  - **Enterprise** is "call us". It is fine-tuned to the customer's agents, IDEs, model providers, and tools.
- **What we sell:** a paid proof-of-concept and an enterprise support contract. That revenue pays for infrastructure, evals, and product work to make redvig the best way to give AI agents real tools.
- **Contact:** `poc@redvig.dev`. Link https://jonnyzzz.com/services/ and nothing more. Do not copy personal rates, terms, or wording from that page.
- We are looking for funding, mainly to extend the evals. Say so plainly on the pricing page.
