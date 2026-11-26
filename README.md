# redvig

Static tools to boost AI coding. The website source for [redvig.dev](https://redvig.dev/) lives in [website/](website/).

## Build the website

Start Docker and run this command from the repository root.

```sh
./website/build.sh
```

The script runs a pinned Hugo image in Docker and writes the static site to `website/public/`. The first run pulls the image. For a local preview, serve the generated files.

```sh
python3 -m http.server 1313 --bind 127.0.0.1 --directory website/public
```

Open [localhost:1313](http://127.0.0.1:1313/).

## GitHub Pages

In repository **Settings → Pages**, choose **GitHub Actions** as the publishing source and set **Custom domain** to `redvig.dev`. The [deploy workflow](.github/workflows/pages.yml) runs when website files change on `main` and can also be run manually. Hugo copies [CNAME](website/static/CNAME) into the artifact. The Pages setting controls the domain for Actions deployments.

Configure the domain's public DNS separately, then enable **Enforce HTTPS** in Pages once GitHub issues the certificate.
