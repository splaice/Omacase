# Releasing Omacase

Versioned tags are the unit of review. Public installs (`OMACASE_CHANNEL=stable`,
the default) check out the greatest `v*` tag. Maintainer machines set
`OMACASE_CHANNEL=dev` and keep `git pull --ff-only` on the default branch.

## Cut a release

1. Bump `VERSION` to `X.Y.Z`.
2. Commit the bump (and any pin updates below) on `main`.
3. `git tag -a vX.Y.Z -m "<notes>"`
4. `git push --follow-tags`

The first stable target after this model landed is `v0.2.0` (matches `VERSION`).

## Homebrew installer pin

`boot.sh` / `site/install` fetch a **commit-pinned** `install.sh` from
`Homebrew/install` (that repo has no tags) and verify its sha256. When the
installer needs a bump:

1. Pick a reviewed commit on `Homebrew/install`.
2. `curl -fsSL https://raw.githubusercontent.com/Homebrew/install/<commit>/install.sh | shasum -a 256`
3. Update `HOMEBREW_INSTALLER_VERSION` and `HOMEBREW_INSTALLER_SHA256` in
   `boot.sh`, then `cp boot.sh site/install`.

A checksum mismatch fails closed and tells the user to update Omacase or
install Homebrew by hand from brew.sh.

## mise / npm pins

`home/dot_config/mise/config.toml` uses exact versions. `mise outdated` lists
candidates. Bump pins in a dedicated commit; do not restore `@latest`.
Do not pin tools that self-update by design (Claude Code, grok).
