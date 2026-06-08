# macarchy Brewfile — the opinionated package set. `brew bundle` is idempotent.
# Edit, then `macarchy update` (or `brew bundle`) to converge.

# --- Window management & desktop -------------------------------------------
tap "nikitabobko/tap"
tap "FelixKratz/formulae"
cask "nikitabobko/tap/aerospace"     # tiling WM (default profile, no SIP disable)
brew "FelixKratz/formulae/sketchybar" # status bar (Waybar analog)
brew "FelixKratz/formulae/borders"    # JankyBorders — active-window borders
# yabai profile (advanced; needs SIP partially disabled — see `macarchy wm yabai`)
brew "koekeishiya/formulae/yabai"
brew "koekeishiya/formulae/skhd"
tap  "koekeishiya/formulae"

# --- The "make Mac behave" quartet -----------------------------------------
cask "raycast"            # launcher / command palette / window mgmt / clipboard
cask "karabiner-elements" # keyboard remapping (caps→ctrl/esc, Hyper key)
cask "alt-tab"            # real alt-tab across all windows
cask "jordanbaird-ice"    # Ice — open-source menu-bar manager (Bartender alt)

# --- Terminal & shell -------------------------------------------------------
cask "ghostty"           # native GPU terminal
brew "starship"          # prompt
brew "eza"               # ls
brew "bat"               # cat
brew "fd"                # find
brew "ripgrep"           # grep
brew "zoxide"            # cd
brew "fzf"               # fuzzy finder
brew "btop"              # system monitor
brew "atuin"             # shell history
brew "git-delta"         # git diffs
brew "tmux"              # multiplexer

# --- Editor & dev -----------------------------------------------------------
brew "neovim"            # + LazyVim (seeded via dotfiles)
cask "zed"               # GUI editor
brew "mise"              # runtime version manager (node/python/ruby)
brew "direnv"
brew "lazygit"
brew "gh"

# --- Dotfiles & tooling -----------------------------------------------------
brew "chezmoi"           # dotfiles manager
brew "gum"               # TUI for `macarchy menu`

# --- Fonts ------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font"

# --- Browser ----------------------------------------------------------------
cask "brave-browser"     # Chromium + PWAs; pairs with Safari "Add to Dock"
