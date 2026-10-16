-- grok — GrokNight / GrokDay colorschemes for Neovim.
-- Local Omacase nvim plugin (loaded via the `dir` spec in lua/plugins/colorscheme.lua).
--
-- Grok Build's themes are "a neutral gray base with Tokyo Night accents", so
-- rather than hand-maintain every highlight group we feed Grok's palette to
-- tokyonight.nvim's engine (full treesitter/LSP/plugin coverage for free).
-- Source palette: xai-org/grok-build (Apache-2.0)
--   crates/codegen/xai-grok-pager-render/src/theme/{groknight,grokday}.rs

local M = {}

-- ANSI 0-15, identical to themes/<name>/ghostty so :terminal matches Ghostty.
local terminal = {
  groknight = {
    "#111111", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#1abc9c", "#c8c8c8",
    "#6c6c6c", "#f7768e", "#8bc34a", "#ff9e64", "#7aa2f7", "#9d7cd8", "#3a95ab", "#e1e1e1",
  },
  grokday = {
    "#262626", "#cd3048", "#378e23", "#a27612", "#2f64d2", "#7d4bc6", "#0a8e70", "#444444",
    "#767676", "#cd3048", "#4caf50", "#c3691e", "#2f64d2", "#6c3eb2", "#0f87a2", "#262626",
  },
}

-- Overrides on top of tokyonight's `night` palette (the accents Grok shares).
local palettes = {
  groknight = {
    background = "dark",
    bg = "#0a0a0a", -- Grok bg_terminal
    bg_dark = "#111111",
    bg_dark1 = "#0c0c0c",
    bg_highlight = "#242424",
    fg = "#e1e1e1",
    fg_dark = "#c8c8c8",
    fg_gutter = "#414141",
    comment = "#6c6c6c",
    dark3 = "#5a5a5a",
    dark5 = "#787878",
    terminal_black = "#414141",
    blue1 = "#3a95ab",
    blue7 = "#2a3148",
    visual = "#363636",
    border = "#323237",
  },
  grokday = {
    background = "light",
    bg = "#f5f5f5",
    bg_dark = "#eaeaea",
    bg_dark1 = "#e4e4e4",
    bg_highlight = "#dedede",
    fg = "#262626",
    fg_dark = "#444444",
    fg_gutter = "#b2b2b2",
    comment = "#767676",
    dark3 = "#8e8e8e",
    dark5 = "#626262",
    terminal_black = "#b2b2b2",
    blue = "#2f64d2",
    blue0 = "#28448a",
    blue1 = "#0f87a2",
    blue2 = "#0082aa",
    blue5 = "#0082aa",
    blue6 = "#0c947c",
    blue7 = "#c9d6f2",
    cyan = "#0082aa",
    green = "#378e23",
    green1 = "#0c947c",
    green2 = "#0a8e70",
    magenta = "#7d4bc6",
    magenta2 = "#b8237a",
    orange = "#c3691e",
    purple = "#6c3eb2",
    red = "#cd3048",
    red1 = "#af2323",
    teal = "#0a8e70",
    yellow = "#a27612",
    git = { add = "#378e23", change = "#2f64d2", delete = "#cd3048" },
    visual = "#c6c6c6",
    border = "#c8c8cd",
  },
}

---@param name "groknight"|"grokday"
function M.load(name)
  local p = palettes[name]
  local ansi = terminal[name]
  local colors = require("tokyonight.colors")

  -- Register the palette as a tokyonight style so its derived colors (diff,
  -- popups, sidebars, rainbow, …) are computed from Grok's base.
  colors.styles[name] = function()
    local base = vim.deepcopy(require("tokyonight.colors.night"))
    for k, v in pairs(p) do
      if k ~= "background" and k ~= "visual" and k ~= "border" then
        base[k] = v
      end
    end
    return base
  end

  -- Bypass tokyonight.load(): it forces background=dark for any style but "day".
  vim.o.background = p.background
  require("tokyonight.theme").setup({
    style = name,
    on_colors = function(c)
      c.bg_visual = p.visual
      c.border = p.border
      c.terminal = {
        black = ansi[1], red = ansi[2], green = ansi[3], yellow = ansi[4],
        blue = ansi[5], magenta = ansi[6], cyan = ansi[7], white = ansi[8],
        black_bright = ansi[9], red_bright = ansi[10], green_bright = ansi[11],
        yellow_bright = ansi[12], blue_bright = ansi[13], magenta_bright = ansi[14],
        cyan_bright = ansi[15], white_bright = ansi[16],
      }
    end,
  })
  vim.g.colors_name = name
end

return M
