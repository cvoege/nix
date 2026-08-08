return {
  { "williamboman/mason.nvim", config = true },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "ts_ls" }, -- ts_ls is the current name for the TS language server in lspconfig
    },
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.lsp.enable("ts_ls")

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local opts = { buffer = bufnr }

          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)       -- go to definition
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)              -- show hover docs
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)        -- find references
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)    -- rename symbol
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts) -- code actions
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)      -- prev diagnostic
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)      -- next diagnostic
        end,
      })
    end,
  },
}
