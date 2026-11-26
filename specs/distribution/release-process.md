# Release process

1. **Third-party modules:** pick the exact vendor builds (for example the JDK), check their vendor
   signatures, record URL, version, and SHA-256. Update their files in `/licenses`.
2. **Build** our modules. The core includes `THIRD-PARTY-NOTICES.txt`, generated from `/licenses`.
3. **Publish** the GitHub release `v<version>` with our archives. The website still serves the
   previous release.
4. **Render** `install.sh` and `install.ps1` from the version and the module table
   ([install-scripts.md](install-scripts.md)).
5. **Sign** both on the operator's machine, with the primary key in `ssh-agent`:
   `ssh-keygen -Y sign -n redvig-release -f primary.pub install.sh` (and the same for `install.ps1`).
   Check both signatures with the same verifier code the binary uses.
6. **Commit** the four files to `website/static/` on `main`. The Pages workflow publishes them. From
   then on, new installs and running copies get the new release.

The private key never leaves the operator's machine. Signing never runs in CI.

## CI check before deploy

A job separate from the Hugo build (which runs without network) fails the deploy unless:

- both `.sig` files verify against `distribution/allowed_signers`;
- both header lines name the same version; if the scripts changed, that version is newer than the one
  already published;
- every module URL in the scripts exists. This is what makes step 3 come before step 6.
