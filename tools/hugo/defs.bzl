"""Hugo toolchain and rules.

hugo_site    builds a Hugo site into a directory output.
hugo_binary  exposes the resolved Hugo binary as an executable, for `bazel run` targets.
"""

HUGO_TOOLCHAIN = "//tools/hugo:toolchain_type"

def _hugo_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(hugo = ctx.executable.hugo)]

hugo_toolchain = rule(
    implementation = _hugo_toolchain_impl,
    attrs = {
        "hugo": attr.label(mandatory = True, executable = True, allow_single_file = True, cfg = "exec"),
    },
)

def _hugo_site_impl(ctx):
    hugo = ctx.toolchains[HUGO_TOOLCHAIN].hugo
    out = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add(hugo)
    args.add(out.path)
    args.add(ctx.label.package)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._build,
        arguments = [args],
        inputs = ctx.files.srcs,
        tools = [hugo],
        outputs = [out],
        mnemonic = "HugoSite",
        progress_message = "Building Hugo site %{label}",
        # The site must not depend on the network; the sandbox enforces it where it can.
        execution_requirements = {"block-network": "1"},
        toolchain = HUGO_TOOLCHAIN,
    )
    return [DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out]))]

hugo_site = rule(
    implementation = _hugo_site_impl,
    doc = "Builds the Hugo site whose hugo.toml is in this package. srcs paths are relative to the package.",
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True, doc = "Config, content, layouts, and static files."),
        "_build": attr.label(default = "//tools/hugo:hugo_build.sh", executable = True, allow_single_file = True, cfg = "exec"),
    },
    toolchains = [HUGO_TOOLCHAIN],
)

def _hugo_binary_impl(ctx):
    hugo = ctx.toolchains[HUGO_TOOLCHAIN].hugo
    out = ctx.actions.declare_file(ctx.label.name + (".exe" if hugo.extension == "exe" else ""))
    ctx.actions.symlink(output = out, target_file = hugo, is_executable = True)
    return [DefaultInfo(executable = out, files = depset([out]), runfiles = ctx.runfiles([hugo]))]

hugo_binary = rule(
    implementation = _hugo_binary_impl,
    doc = "The Hugo binary for this machine. Local `bazel run` executes on the host, so the exec toolchain is the right one.",
    executable = True,
    toolchains = [HUGO_TOOLCHAIN],
)
