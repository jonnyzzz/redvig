"""Downloads pinned Hugo release binaries, one repository per platform.

Each archive is checked against the SHA-256 from Hugo's checksums.txt, so the build is
hermetic and the repositories are reproducible. Only the repository for the platform that
toolchain resolution picks is fetched. We use plain Hugo: the site needs no Sass or image
processing, so the extended build is not required.

To upgrade: change HUGO_VERSION and copy the new hashes from
https://github.com/gohugoio/hugo/releases/download/v<VERSION>/hugo_<VERSION>_checksums.txt
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

HUGO_VERSION = "0.169.0"

_ARCHIVES = {
    "hugo_linux_amd64": ("linux-amd64.tar.gz", "2d2f0bfe357d8cb4cec02f6bb28a3bff34978c8dda44b618029c5eb9d66765a7"),
    "hugo_linux_arm64": ("linux-arm64.tar.gz", "ddadaaccbf437e3d39c33140b80c2180c4f46d027d16b7716c1282ea2e14e00c"),
    "hugo_windows_amd64": ("windows-amd64.zip", "d1ea8b32bdc2d3d5d4b56178efedf0925c027d2063e6779b5e8df6f406b09948"),
    "hugo_windows_arm64": ("windows-arm64.zip", "034e21143a0e30cbf4b1a2f285b9caad1928dc0e00c5c01942ea9c3085c0b500"),
}

_DARWIN = ("darwin-universal.pkg", "9b1170c439b5444e31d4731dd0071fc2b380b8d58050e6cdae80e3e179b4bf52")

def _url(suffix):
    return "https://github.com/gohugoio/hugo/releases/download/v{v}/hugo_{v}_{s}".format(v = HUGO_VERSION, s = suffix)

def _hugo_pkg_impl(rctx):
    """macOS ships only a .pkg (a xar archive), which http_archive cannot unpack."""
    rctx.download(url = rctx.attr.url, output = "hugo.pkg", sha256 = rctx.attr.sha256)
    result = rctx.execute(["pkgutil", "--expand-full", "hugo.pkg", "expanded"])
    if result.return_code != 0:
        fail("pkgutil could not unpack the Hugo package:\n" + result.stderr)
    rctx.symlink("expanded/Payload/hugo", "hugo")
    rctx.delete("hugo.pkg")
    rctx.file("BUILD.bazel", 'exports_files(["hugo"])\n')

_hugo_pkg = repository_rule(
    implementation = _hugo_pkg_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "sha256": attr.string(mandatory = True),
    },
)

def _hugo_impl(mctx):
    for name, (suffix, sha256) in _ARCHIVES.items():
        binary = "hugo.exe" if name.startswith("hugo_windows") else "hugo"
        http_archive(
            name = name,
            url = _url(suffix),
            sha256 = sha256,
            build_file_content = 'exports_files(["{}"])\n'.format(binary),
        )
    _hugo_pkg(name = "hugo_darwin", url = _url(_DARWIN[0]), sha256 = _DARWIN[1])
    return mctx.extension_metadata(reproducible = True)

hugo = module_extension(implementation = _hugo_impl)
