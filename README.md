# redvig

Static tools to boost AI coding. The website source for [redvig.dev](https://redvig.dev/) lives in [website/](website/).

## Build the website

The website builds only in Docker, through [website/build.sh](website/build.sh). Start Docker and run the script from the repository root. Running Hugo directly is not supported, and the layout fails the build when it is not run by the script.

```sh
./website/build.sh            # production build into website/public/
./website/build.sh dev        # live-reload preview at http://localhost:1313/
./website/build.sh dev 8080   # preview on another port
```

Both modes use the same pinned Hugo image, and the first run pulls it. Dev mode serves from memory and includes drafts. It rebuilds when files under `website/` change. Press Ctrl+C to stop it.

## GitHub Pages

Pages is set to deploy from **GitHub Actions** with the custom domain `redvig.dev`. To set it up again with `gh`, run:

```sh
gh api -X POST repos/jonnyzzz/redvig/pages -f build_type=workflow
gh api -X PUT repos/jonnyzzz/redvig/pages -f cname=redvig.dev
```

The [deploy workflow](.github/workflows/pages.yml) runs when website files change on `main` and can also be run manually. Hugo copies [CNAME](website/static/CNAME) into the artifact. The Pages setting controls the domain for Actions deployments.

Configure the domain's public DNS separately, then enable **Enforce HTTPS** in Pages once GitHub issues the certificate.
