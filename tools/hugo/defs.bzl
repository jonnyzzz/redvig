"""hugo_site: build a Hugo site in the pinned Docker image into a directory output."""

def _hugo_site_impl(ctx):
    out = ctx.actions.declare_directory(ctx.label.name)
    site_root = ctx.label.package

    args = ctx.actions.args()
    args.add(ctx.executable._docker)
    args.add(ctx.file._image)
    args.add(out.path)
    args.add(site_root)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._build,
        arguments = [args],
        inputs = depset(ctx.files.srcs + [ctx.file._image]),
        tools = [ctx.executable._docker],
        outputs = [out],
        mnemonic = "HugoSite",
        progress_message = "Building Hugo site %{label}",
        # The action talks to the local Docker daemon, so it cannot run on remote executors.
        # Its result is still cacheable: the key covers every source and the image digest.
        execution_requirements = {"no-remote-exec": "1", "requires-docker": "1"},
    )
    return [DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out]))]

hugo_site = rule(
    implementation = _hugo_site_impl,
    doc = "Builds the Hugo site whose hugo.toml is in this package. srcs paths are relative to the package.",
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True, doc = "Config, content, layouts, and static files."),
        "_build": attr.label(default = "//tools/hugo:hugo_build.sh", executable = True, allow_single_file = True, cfg = "exec"),
        "_docker": attr.label(default = "@docker_cli//:docker", executable = True, allow_single_file = True, cfg = "exec"),
        "_image": attr.label(default = "//tools/hugo:IMAGE", allow_single_file = True),
    },
)
