-- return {
--   {
--     "marko-cerovac/material.nvim",
--     priority = 1000,
--     config = function()
--       vim.g.material_style = "deep ocean"
--       vim.cmd("colorscheme material")
--     end,
--   },
-- }
--
return {
  -- {
  --   "Shatur/neovim-ayu",
  --   lazy = false,
  --   priority = 1000, -- make sure it loads before others
  --   config = function()
  --     require("ayu").setup({
  --       mirage = false, -- true for mirage variant
  --       overrides = {}, -- you can override highlights here
  --     })
  --     vim.cmd("colorscheme ayu") -- apply the colorscheme
  --   end,
  -- },
  {
    "kwsp/halcyon-neovim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true -- Enable true color support
      vim.cmd("colorscheme halcyon")
    end,
  },
  {
    "sphamba/smear-cursor.nvim",
    opts = {},
  },
}
