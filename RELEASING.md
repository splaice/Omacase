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

## Font pin (IoskeleyMono)

`lib/fonts.sh` pins the IoskeleyMono release (`OMACASE_FONT_VERSION`) and the
sha256 of its `IoskeleyMono-Term-NerdFont.zip`. To bump:

1. `V=vX.Y.Z; curl -fsSL https://github.com/ahatem/IoskeleyMono/releases/download/$V/IoskeleyMono-Term-NerdFont.zip | shasum -a 256`
2. Update `OMACASE_FONT_VERSION` and `OMACASE_FONT_SHA256` in `lib/fonts.sh`.
3. `just check`, commit. Existing installs pick it up on the next `omacase update`.

## Tool versions

Everything Omacase installs comes from Homebrew (Brewfile pins names, not
versions) except the self-updating installers (Claude Code, opt-in grok).
There is no separate pin file to bump.
