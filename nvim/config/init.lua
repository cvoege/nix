-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Core settings
vim.opt.number = true         -- show line numbers
vim.opt.relativenumber = false -- line numbers relative to cursor (great for motions like 5j)
vim.opt.expandtab = true      -- use spaces instead of tabs
vim.opt.shiftwidth = 2        -- indent size
vim.opt.tabstop = 2           -- tab width
vim.opt.smartindent = true    -- auto-indent new lines sensibly
vim.opt.wrap = false          -- don't soft-wrap long lines
vim.opt.ignorecase = true     -- case-insensitive search...
vim.opt.smartcase = true      -- ...unless you type a capital letter
vim.opt.termguicolors = true  -- enable full color support (needed for good themes)
vim.opt.signcolumn = "yes"    -- always show the sign column (avoids text shifting when LSP diagnostics appear)

-- Plugin setup
require("lazy").setup({
  -- plugins will go here
  -- {
  --   "folke/tokyonight.nvim",
  --   priority = 1000, -- load this before other plugins
  --   config = function()
  --     vim.cmd("colorscheme tokyonight")
  --   end,
    -- },
  {
    "navarasu/onedark.nvim",
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = "dark", -- try: dark, darker, cool, deep, warm, warmer
      })
      require("onedark").load()
    end,
  },

  { "williamboman/mason.nvim", config = true },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
  },

  { "neovim/nvim-lspconfig" },
})
