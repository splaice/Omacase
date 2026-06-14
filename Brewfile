# omacase Brewfile — the opinionated package set. `brew bundle` is idempotent.
# Edit, then `omacase update` (or `brew bundle`) to converge.

# --- Window management & desktop -------------------------------------------
tap "nikitabobko/tap"
tap "FelixKratz/formulae"
cask "nikitabobko/tap/aerospace"     # tiling WM (no SIP disable, i3-style)
brew "FelixKratz/formulae/sketchybar" # status bar (Waybar analog)
brew "splaice/formulae/borders"       # JankyBorders fork (+square_apps); local tap synced by install.sh

# --- The "make Mac behave" set ---------------------------------------------
# Launcher is macOS Spotlight (⌘Space) — Tahoe's Spotlight has actions,
# clipboard history, and Quick Keys built in, so no third-party launcher.
cask "karabiner-elements" # mints the Super key (right ⌘ → ⌃⌥⌘) for AeroSpace
# Menu bar is stock macOS — no third-party menu-bar manager.

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
brew "ranger"            # TUI file manager (Super+Shift+F popup via `omacase files`)
brew "atuin"             # shell history
brew "git-delta"         # git diffs
brew "tmux"              # multiplexer
brew "zsh-completions"   # extra completion defs beyond zsh's bundled set (wired in dot_zshrc)
brew "glow"              # markdown rendered in the terminal (read READMEs where you are)
brew "dust"              # du
brew "jq"                # JSON wrangling
brew "tldr"              # example-first man pages
brew "fastfetch"         # branded system summary (`omacase menu` → About); config in home/

# --- Editor & dev -----------------------------------------------------------
brew "neovim"            # + LazyVim (seeded via dotfiles) — the editor
brew "mise"              # runtime version manager (node/python/ruby) + npm: CLIs
brew "uv"                # fast Python package/tool manager (hosts mlx-lm for the planned local LLM)
brew "direnv"
brew "lazygit"
brew "gh"                # GitHub CLI
brew "just"              # command runner (justfiles)

# --- AI coding & local LLM --------------------------------------------------
# Native binaries → Homebrew. (Fast-moving npm AI CLIs — gemini, mermaid, pi —
# are mise `npm:` tools instead; see home/dot_config/mise/config.toml. Claude
# Code self-manages via its own installer, so it's not declared here.)
cask "codex"             # OpenAI Codex CLI (official Rust binary; depends on ripgrep)
brew "opencode"          # opencode — terminal AI coding agent (homebrew-core)
cask "ollama-app"        # Ollama — local LLM runner (menu-bar app, auto-updates)
tap  "finbarr/tap"
brew "finbarr/tap/yolobox" # run AI coding agents in a sandboxed container

# --- Tooling ----------------------------------------------------------------
brew "gum"               # TUI for `omacase menu`
brew "terminal-notifier" # reliable native notifications for `omacase notify` (osascript's are flaky)
# (Omacase manages its own dotfiles via symlinks — no chezmoi dependency.)

# --- Fonts ------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font"

# --- Browser ----------------------------------------------------------------
# Brave is the dedicated `omacase webapp` browser (signed; opens chromeless
# app windows) so ⌘Q on a web app never quits your daily/default browser.
cask "brave-browser"     # Chromium + PWAs; pairs with Safari "Add to Dock"
