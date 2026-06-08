-- macarchy theme integration. `macarchy theme <name>` symlinks
-- themes/<name>/nvim.lua → ~/.config/nvim/lua/theme.lua, which returns the
-- colorscheme name. We read it here so the editor matches the rest of the system.
local ok, colorscheme = pcall(require, "theme")
if not ok or type(colorscheme) ~= "string" then
  colorscheme = "catppuccin-mocha"
end

return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  { "folke/tokyonight.nvim", priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = colorscheme } },
}
