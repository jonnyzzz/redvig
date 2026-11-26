# Signed updates

## Threat model

- **Install** (`curl | sh`, `irm | iex`) trusts HTTPS to `redvig.dev`. No signature is involved: if
  HTTPS is broken, a signature fetched over the same connection cannot help.
- **Auto-update** is the one place a signature is checked. An installed redvig runs code from the
  network with no human watching, on every machine at once. So it runs a new install script only if the
  script is signed by a key the **old, already installed** version has built in.

This follows our previous Go version: an `SSHSIG` `.sig` file next to the signed file, verified
natively against public keys embedded in the binary.

## What is signed

The install scripts are the release information. There is no separate manifest:

```
https://redvig.dev/install.sh      https://redvig.dev/install.sh.sig
https://redvig.dev/install.ps1     https://redvig.dev/install.ps1.sig
```

The script changes only when a release is published. Its second line (the first line in `install.ps1`)
says which release it installs:

```
# redvig-release: version=<version> script=<install.sh|install.ps1>
```

The updater reads this line only after the signature has passed. `script` must name the file it asked
for, so a signed `install.ps1` cannot be served as `install.sh`.

## Versions

A release version is `MAJOR.MINOR.PATCH`, decimal, no leading zeros (`1.4.0`). Compare numerically per
part. Every version is published once. A binary whose version does not match this form is a dev build
and never updates itself.

## Signature format

- OpenSSH `SSHSIG`, armored, as `ssh-keygen -Y sign` writes it. One signature per `.sig` file.
- Key type `ssh-ed25519`, `SSHSIG` version 1, hash `sha512`, namespace `redvig-release`. Anything else
  is rejected.
- Signed data: the exact downloaded bytes of the script.
- Accepted when the signature verifies with one of the public keys built into the binary, and the key
  inside the signature is byte-equal to that built-in key.
- Native verification code in the binary (Ed25519 is in the JDK and in Go's standard library). It does
  not run `ssh-keygen`. Malformed input is an error, never a crash. The `.sig` file is limited to 16 KiB
  and the script to 1 MiB.

## Keys

Two `ssh-ed25519` keys are built into every binary, as in our previous version. Either one is enough:

- **primary:** signs every release, from the release operator's `ssh-agent`;
- **backup:** kept offline, used only when the primary is lost or compromised.

The public keys live in `distribution/allowed_signers` in this repository, and the build embeds that
file. The binary never loads keys from the network.

**Changing keys:** release N, signed with a key the installed versions know, builds in the new key set.
Later releases are signed with the new key. An installation that never updated to N stops updating
itself; re-running the install one-liner fixes it.
