"""Exposes the host's Docker CLI as @docker_cli//:docker.

Build actions run with a fixed PATH (--incompatible_strict_action_env), which may not
contain docker (Homebrew and Docker Desktop install it outside /usr/bin). This rule finds
docker once, when the repository is fetched, and writes a wrapper with its absolute path.
If docker is missing, the wrapper fails with a clear message only when an action uses it,
so targets that do not need Docker still build.
"""

def _docker_cli_impl(rctx):
    docker = rctx.which("docker")
    if docker == None:
        script = "#!/bin/sh\necho 'docker is required for this target; install Docker and run again' >&2\nexit 1\n"
    else:
        # Credential helpers (docker-credential-*) are looked up on PATH next to docker.
        dirs = [str(docker.dirname), str(docker.realpath.dirname), "/usr/local/bin", "/usr/bin", "/bin"]
        path = ":".join([d for i, d in enumerate(dirs) if d not in dirs[:i]])
        script = "#!/bin/sh\nPATH='{path}'\nexport PATH\nexec '{docker}' \"$@\"\n".format(
            path = path,
            docker = str(docker),
        )
    rctx.file("docker", script, executable = True)
    rctx.file("BUILD.bazel", 'exports_files(["docker"])\n')

docker_cli = repository_rule(
    implementation = _docker_cli_impl,
    environ = ["PATH"],
    local = True,
    doc = "The host's docker CLI, wrapped with an absolute path.",
)
