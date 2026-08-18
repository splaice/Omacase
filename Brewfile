# frozen_string_literal: true

# omacase Brewfile — the opinionated package set. `brew bundle` is idempotent.
# Edit, then `omacase update` (or `brew bundle`) to converge.

# --- Window management & desktop -------------------------------------------
tap "BarutSRB/tap"
cask "omniwm" # native Niri + Hyprland Dwindle WM, workspace bar, borders, quake terminal

# --- The "make Mac behave" set ---------------------------------------------
# Launcher is macOS Spotlight (⌘Space) — Tahoe's Spotlight has actions,
# clipboard history, and Quick Keys built in, so no third-party launcher.
# OmniWM owns its keyboard shortcuts directly.
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
brew "btop"              # full terminal system monitor (OmniWM also has a compact native stats popup)
brew "yazi"              # TUI file manager (`omacase files` opens it as an optional popup)
brew "atuin"             # shell history
brew "git-delta"         # git diffs
brew "herdr"             # agent-aware multiplexer; sessions survive disconnect (`herdr --remote` for SSH)
brew "zsh-completions"   # extra completion defs beyond zsh's bundled set (wired in dot_zshrc)
brew "glow"              # markdown rendered in the terminal (read READMEs where you are)
brew "dust"              # du
brew "mole"              # `mo` — deep clean + thorough app uninstaller (`omacase extras mole`; `mo clean --dry-run` previews)
brew "jq"                # JSON wrangling
brew "tldr"              # example-first man pages
brew "fastfetch"         # branded system summary (`omacase menu` → About); config in home/

# --- Editor & dev -----------------------------------------------------------
brew "neovim"            # + LazyVim (seeded via dotfiles) — the editor
brew "mise"              # runtime version manager (node/python/ruby) + npm: CLIs
brew "uv"                # fast Python package/tool manager (hosts mlx-lm for the planned local LLM)
brew "direnv"           # per-directory env vars (.envrc), hooked into zsh
brew "lazygit"          # git TUI (`lg`)
brew "gh"                # GitHub CLI
brew "just"              # command runner (justfiles)

# --- AI coding & local LLM --------------------------------------------------
# Native binaries → Homebrew. (Fast-moving npm AI CLIs — gemini, mermaid, pi —
# are mise `npm:` tools instead; see home/dot_config/mise/config.toml. Claude
# Code and the Grok CLI self-manage via their own installers — Grok can be
# explicitly enabled with OMACASE_INSTALL_GROK=1, so neither is declared here.)
cask "codex"             # OpenAI Codex CLI (official Rust binary; depends on ripgrep)
brew "opencode"          # opencode — terminal AI coding agent (homebrew-core)
tap  "finbarr/tap"
brew "finbarr/tap/yolobox" # run AI coding agents in a sandboxed container

# --- Networking -------------------------------------------------------------
# Tailscale is what makes the remote half of herdr usable: `herdr --remote
# <host>` needs the box reachable from anywhere, and the herdr server keeps the
# agent running there after the laptop disconnects.
cask "tailscale-app"     # mesh VPN / private network

# --- Opinionated applications -----------------------------------------------
# Omacase installs these and offers optional CLI/menu launch helpers. OmniWM's
# own shortcuts remain untouched; its app rules decide which windows float.
cask "spotify"           # music (Apple Music is stock)
cask "obsidian"          # notes / knowledge base
cask "1password"         # password manager
cask "todoist-app"       # tasks
cask "the-unarchiver"    # archives beyond zip (stock Archive Utility handles little else)

# Messaging. Native apps rather than `omacase webapp` shells: these want
# background notifications, and the desktop clients carry features the web
# versions do not.
cask "discord"          # Discord — community & voice chat
cask "signal"           # Signal — private messaging
cask "telegram"         # Telegram — messaging
cask "whatsapp"         # WhatsApp — messaging (self-updates; brew upgrade skips it)
# --- Dictation --------------------------------------------------------------
cask "fluidvoice" # offline voice-to-text (local model); needs Mic + Accessibility

# --- Tooling ----------------------------------------------------------------
brew "gum"               # TUI for `omacase menu`
brew "terminal-notifier" # reliable native notifications for `omacase notify` (osascript's are flaky)
# (Omacase manages its own dotfiles via symlinks — no chezmoi dependency.)

# --- Fonts ------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font" # terminal/editor font with glyph icons
# --- Browsers ---------------------------------------------------------------
# Brave is the dedicated `omacase webapp` browser (signed; opens chromeless
# app windows) so ⌘Q on a web app never quits your daily/default browser.
cask "brave-browser" # Chromium + PWAs; pairs with Safari "Add to Dock"
# Chrome is the third role the line above implies: a daily/default browser and
# the web-dev reference engine (and where Claude in Chrome runs). Safari stays
# stock. Only the stable channel ships — a default set has no business
# installing two channels of one browser.
cask "google-chrome"    # Chrome — secondary browser (web apps)