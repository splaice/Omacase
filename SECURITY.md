# Security

Omacase installs software and runs it on a personal Mac. The trust boundary is
the **reviewed git tag** (`vX.Y.Z`). `OMACASE_CHANNEL=dev` opts out of that
and tracks the default branch.

There is no GPG/SSH tag-signature verification yet. Distributing a signing key
inside this same repository is circular; revisit when there is an out-of-band
channel (for example a Homebrew formula). TLS protects transport.

## Trust model

| Surface | Mutable? | Why |
|---|---|---|
| Omacase payload (`omacase update`) | **Pinned** on `stable` to the greatest `v*` tag. `dev` pulls the default branch. | Tags are the unit of review. `--check` inspects pending changes; `--rollback` returns one SHA. |
| Homebrew installer (`boot.sh`) | **Pinned** to a `Homebrew/install` commit + sha256 | That repo has no tags. Fail closed on mismatch; install Homebrew from brew.sh by hand if needed. |
| Homebrew formulae / casks | **Mutable** by design | Brew's own trust chain. Brewfile pins names, not versions; brew has no supported lockfile. |
| Claude Code | **Vendor-rolling** | Self-updating, vendor-signed. Not declared anywhere. |
| Grok CLI | **Vendor-rolling, opt-in** | `OMACASE_INSTALL_GROK=1`. Installer is unversioned; a checksum would break on every vendor release with no signal to us. Opt-in is the control. |
| Omarchy theme assets (`$OMACASE_DATA/upstream`) | Content, not code | Parsed as TOML / images, never executed. |
| herdr tap | Maintainer-owned | Declared third-party tap, trusted by exact formula/cask name. |
