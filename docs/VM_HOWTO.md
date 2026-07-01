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

## Known first-boot issues (from cold-start testing)

Observed on earlier fresh-VM installs — re-verify each on the next cold start
and fix in `lib/install.sh` / `lib/doctor.sh` where possible:

- `omacase install` completed without surfacing the system permission dialogs;
  they only appeared after running `omacase doctor`. Install now launches
  Karabiner and prints a doctor reminder, but the ideal is prompts firing
  during install itself.
- Karabiner's DriverKit driver-approval prompt did not appear automatically.
  Install now runs the bundled `VirtualHIDDevice-Manager activate` to force
  the dialog — confirm it actually appears on a clean VM.
- AeroSpace was not started by install on a cold machine. Install step 8
  launches it (and waits for the process) now — confirm on a fresh VM,
  including the first-run Accessibility gate.
