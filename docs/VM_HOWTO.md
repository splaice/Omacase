# macOS VM Test Loop

Use this to test Omacase install, uninstall, and restore flows on a disposable
macOS VM.

## Recommended: Tart

Tart is the best fit for repeatable Omacase testing on Apple Silicon because it
uses Apple's Virtualization.framework and makes it easy to clone/delete VM images.

```bash
brew install cirruslabs/cli/tart
```

Create a clean-ish base VM:

```bash
tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest omacase-base
tart set omacase-base --cpu 4 --memory 8192 --disk-size 100
tart run omacase-base
```

Inside the VM, test the public installer:

```bash
/bin/bash -c "$(curl -fsSL https://omacase.org/install)"

omacase doctor
omacase uninstall
omacase restore --list
omacase restore
```

For fast repeatable runs, clone from the base and delete the test VM afterward:

```bash
tart clone omacase-base omacase-test
tart run omacase-test

# Run install/uninstall/restore checks inside the VM.

tart delete omacase-test
```

Keep two useful images:

- `omacase-vanilla`: fresh macOS, useful for full bootstrap testing including
  Xcode Command Line Tools and Homebrew.
- `omacase-base`: already through first boot, SSH enabled, maybe CLT installed,
  useful for faster install/uninstall iteration.

## Manual Alternative: VirtualBuddy

Use VirtualBuddy if you want a simple GUI VM for manual testing. It is easier to
operate casually, but less convenient for a repeatable clone/delete loop.

## Notes

- Test on an Apple Silicon host. Omacase supports Apple Silicon macOS with
  Homebrew at `/opt/homebrew`.
- macOS privacy permissions still need manual clicks inside the VM:
  Accessibility, Input Monitoring, Automation, and Screen Recording.
- GitHub-hosted macOS runners are useful for shell/unit checks, but not enough
  for Omacase's GUI, TCC, window-manager, and restore behavior.
