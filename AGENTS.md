# Agent notes for redvig

## Product

- **redvig is a new product** for the market. It gives AI coding agents real IDE tools: the project model, typed refactors, inspections, a debugger, and test runs. This repository holds it and its website, [redvig.dev](https://redvig.dev/).
- **devrig ([devrig.dev](https://devrig.dev/)) is the previous version, not redvig.** Never sell, install, or document devrig on redvig pages, and never present devrig's claims or numbers as redvig's. You may mention it only as "our previous version", for example when linking to its published eval findings.
- redvig works with any coding agent and any model provider or subscription. It is built on an open-source core.

## Website

- The site is Hugo under `website/`. It builds **only** in Docker through `website/build.sh`.
  - `./website/build.sh` makes the production build in `website/public/`.
  - `./website/build.sh dev [PORT]` runs the live-reload preview at `http://localhost:1313/`.
- Never build or serve the site any other way: no local `hugo`, `python -m http.server`, `npx serve`, or opening HTML from disk. `layouts/baseof.html` fails the build unless `build.sh` runs it. Keep that guard.
- Pin the Hugo image by digest in `build.sh`. Production builds run with `--network none` and `--panicOnWarning`, so fix deprecation warnings rather than silencing them.
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
