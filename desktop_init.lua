-- options
vim.o.number = true
vim.o.relativenumber = true
vim.o.wrap = false
vim.o.tabstop = 2
vim.o.swapfile = false
vim.g.mapleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.o.clipboard = 'unnamedplus'
vim.o.laststatus = 1 -- when more than 1 window
vim.o.showmode = true
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.smartindent = false
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.mouse = ''
vim.o.timeoutlen = 400
vim.o.undofile = true
vim.o.cursorline = true
-- vim.o.termguicolors = true

-- keybinds
vim.keymap.set('n', '<leader>o', ':update<CR> :source<CR>') -- update 
vim.keymap.set('n', '<leader>w', ':write<CR>') -- write
vim.keymap.set('n', '<leader>q', ':quit<CR>') -- quit
vim.keymap.set('t', '<leader>q', ':quit<CR>') -- quit
vim.keymap.set('i', 'jk', '<ESC>') -- norm mode entrance
vim.keymap.set('t', 'jk', '<C-\\><C-n>') -- norm mode entrance
vim.keymap.set('n', '<C-c>', "<cmd> %y+ <CR>") -- copy whole filecontent
vim.keymap.set('n', 'j', 'gj') -- wrap line moves
vim.keymap.set('n', 'k', 'gk')

-- nerdtree
vim.keymap.set('n', '<C-n>', '<cmd> NvimTreeToggle <CR>')
vim.keymap.set('n', '<C-h>', '<cmd> NvimTreeFocus <CR>')

-- telescope
vim.keymap.set('n', '<leader>tf', '<cmd> Telescope find_files <CR>')
vim.keymap.set('n', '<leader>to', '<cmd> Telescope oldfiles <CR>')
vim.keymap.set('n', '<leader>gt', '<cmd> Telescope git_status <CR>')

-- fzf
vim.keymap.set('n', '<leader>ff', '<cmd>FzfLua files<CR>')
vim.keymap.set('n', '<leader>fo', '<cmd>FzfLua oldfiles<CR>')

-- plugin
vim.pack.add({
  { src = "https://github.com/nvim-lua/plenary.nvim"}, -- quintessential lib
  { src = "https://github.com/nvim-treesitter/nvim-treesitter"}, -- syntax engine
  { src = "https://github.com/folke/trouble.nvim"}, -- better linting
  { src = "https://github.com/nvim-tree/nvim-tree.lua"}, -- nerdtree

  { src = "https://github.com/mason-org/mason.nvim"}, -- lsp management
  { src = "https://github.com/neovim/nvim-lspconfig"}, -- lsp configuration
  { src = "https://github.com/mason-org/mason-lspconfig.nvim"}, -- lsp configuration
  { src = "https://github.com/hrsh7th/nvim-cmp"}, -- lsp hookin
  { src = "https://github.com/hrsh7th/cmp-buffer"}, -- pull from current file
  { src = "https://github.com/hrsh7th/cmp-path"}, -- pull from path
  { src = "https://github.com/hrsh7th/cmp-nvim-lsp"}, -- lsp integration

  { src = "https://github.com/ibhagwan/fzf-lua"}, -- searcher one
  { src = "https://github.com/nvim-telescope/telescope.nvim"}, -- searcher two
  { src = "https://github.com/rmagatti/goto-preview"}, 
  { src = "https://github.com/sphamba/smear-cursor.nvim"}, 
  -- { src = "https://github.com/nvimdev/lspsaga.nvim"},
  -- { src = "https://github.com/christoomey/vim-tmux-navigator"},
  -- { src = "https://github.com/"},
})

require("nvim-tree").setup()
require("mason").setup()
require("mason-lspconfig").setup()
require("trouble").setup()
require("fzf-lua").setup({'telescope'})
-- require("").setup()
-- require("").setup()
-- require("").setup()

local cmp = require("cmp")

-- set completion sources 
cmp.setup({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "buffer" },
    { name = "path" },
  }),

  mapping = require("cmp").mapping.preset.insert({
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end, { 'i', 's' }), 
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end, { 'i', 's' }),
  })
})

-- C/C++ Semantics
-- vim.lsp.config["clangd"] = {
--   capabilities = capabilities,
--   on_attach = on_attach,
-- }

-- vim.lsp.config["ocaml-lsp"] = {
--   Command = "/home/wave/.opam/hardcaml_4XX/bin/ocamllsp",
--   capabilities = capabilities,
--   on_attach = on_attach,
-- }

-- vim.lsp.config["ocaml-lsp"] = {
--   cmd = "/home/wave/.opam/hardcaml_4XX/bin/ocamllsp",
--   -- capabilities = capabilities,
--   -- on_attach = on_attach,
-- }

-- vim.lsp.start(vim.lsp.config["clangd"])
-- vim.lsp.log.set_level("ERROR")

-- vim.lsp.config("slang-server", {
--   cmd = "slang-server",
--   root_markers = {".git", ".slang"},
--   filetypes = {
--     "systemverilog",
--     "verilog",
--   },
-- })

-- vim.lsp.enable("ocaml-lsp")

-- init.lua
vim.opt.backupcopy = "yes"      -- avoid rename-on-save weirdness
vim.keymap.set("n", "<leader>W", "<cmd>noautocmd write!<cr>", { silent = true, desc = "Force save (overwrite external changes)" })


vim.lsp.config('ocamllsp', {
  cmd = { vim.fn.expand("~/.opam/ocaml_5XX/bin/ocamllsp") },

  -- If you still have nvim-lspconfig installed, you can actually omit these,
  -- because its ocamllsp config will be merged in. But it doesn't hurt to be explicit.
  filetypes = { "ocaml", "menhir", "ocamlinterface", "ocamllex", "reason", "dune" },
  root_markers = {
    "dune-project",
    "dune-workspace",
    "*.opam",
    "opam",
    "esy.json",
    "package.json",
    ".git",
  },

  capabilities = capabilities,  -- if you’re using cmp_nvim_lsp etc.
  -- on_attach is *deprecated-ish* in favor of LspAttach, but still works.
  -- You can keep using it for now if you want:
  on_attach = on_attach,
})

require("nvim-treesitter").setup(
  {
    ensure_installed = { "ocaml", "ocaml_interface" },
    highlight = {enable = true},
  }
)

require("smear_cursor").setup(
  {
    cursor_color = "#ff4000",
    particles_enabled = true,
    particle_max_num = 200,
    stiffness = 0.5,
    trailing_stiffness = 0.2,
    trailing_exponent = 5,
    damping = 0.6,
    gradient_exponent = 0,
  }
)
-- require('tree-sitter-ocaml').ocaml
-- require('tree-sitter-ocaml').ocaml_interface
-- require('tree-sitter-ocaml').ocaml_type
-- Actually turn it on:
vim.cmd("syntax off")
vim.lsp.enable('ocamllsp')

vim.cmd [[colorscheme industry]]
-- vim.api.nvim_set_hl(0, "@lsp.type.function", { link = "@function" })
-- vim.api.nvim_set_hl(0, "@lsp.type.variable", { link = "@variable" })
-- vim.api.nvim_set_hl(0, "@lsp.type.type",     { link = "@type" })
