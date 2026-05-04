-- vim.o.number = true
vim.o.relativenumber = true
vim.o.wrap = true
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

-- colors
vim.o.termguicolors = true
vim.o.background = "light"

-- keybinds
vim.keymap.set('n', '<leader>o', ':update<CR> :source<CR>') -- update 
vim.keymap.set('n', '<leader>w', ':write<CR>') -- write
vim.keymap.set('n', '<leader>q', ':quit<CR>') -- quit
vim.keymap.set('t', '<leader>q', ':quit<CR>') -- quit
vim.keymap.set('i', 'jk', '<ESC>') -- norm mode entrance
vim.keymap.set('t', 'jk', '<C-\\><C-n>') -- norm mode entrance
vim.keymap.set('n', '<C-c>', "<cmd> %y+ <CR>") -- copy whole filecontent
-- vim.keymap.set('n', 'bv', '<C-v>') -- visual block selècter
-- vim.keymap.set('t', 'bv', '<C-v>')
-- vim.keymap.set('v', 'bv', '<C-v>')
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
  { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim"},
  { src = "https://github.com/xiyaowong/transparent.nvim"},
  { src = "https://github.com/hudson-trading/slang-server.nvim"},
  { src = "https://github.com/maxmx03/solarized.nvim"},
})

require("nvim-tree").setup()
require("mason").setup()
require("mason-lspconfig").setup()
require("trouble").setup()
require("fzf-lua").setup({'telescope'})
-- require("").setup()
-- require("").setup()
-- require("").setup()

vim.cmd("packadd nvim-treesitter")
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
vim.lsp.config["clangd"] = {
  capabilities = capabilities,
  on_attach = on_attach,
  cmd = { vim.fn.expand("/usr/bin/clangd-22") },
}
vim.lsp.enable('clangd')

-- localucwd = require("unified_cwd")
-- vim.keymap.set("n", "<leader>sd", ucwd.save, { desc = "Save cwd (shared with bash)" })
-- vim.keymap.set("n", "<leader>gd", ucwd.save, { desc = "Go to saved cwd(shared with bash)" })

vim.lsp.config("slang-server", {
  cmd = { "/home/wayne/slang-server/build/bin/slang-server" },
  root_markers = { ".git", ".slang" },
  filetypes = { "systemverilog", "verilog" },
})
vim.lsp.enable("slang-server")

vim.opt.backupcopy = "yes"      -- avoid rename-on-save weirdness
vim.keymap.set("n", "<leader>W", "<cmd>noautocmd write!<cr>", { silent = true, desc = "Force save (overwrite external changes)" })
-- vim.lsp.enable("ocaml-lsp")

vim.lsp.config('ocamllsp', {
  -- cmd = { vim.fn.expand("~/.opam/5.4.0/bin/ocamllsp") },
  cmd = { vim.fn.expand("~/.opam/5.2.0+ox/bin/ocamllsp") },

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
vim.lsp.enable('ocamllsp')

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

require("nvim-treesitter").setup(
  {
    ensure_installed = { "ocaml", "ocaml_interface" },
    highlight = {enable = true},
  }
)


vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
-- vim.cmd [[colorscheme solarized]]
vim.cmd [[colorscheme koehler]]

vim.lsp.config('pyright', {
  -- config
})

-- Competitive programming runner
local function cp_run()
  local src  = vim.fn.expand('%:t')
  local dir  = vim.fn.expand('%:p:h')

  vim.cmd('write')

  vim.fn.jobstart({ 'bash', dir .. '/build.sh', src, 'input.txt', 'output.txt' }, {
    cwd = dir,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify('Build failed', vim.log.levels.ERROR)
      else
        vim.notify('Done', vim.log.levels.INFO)
      end
    end,
  })
end
vim.keymap.set('n', '<leader>d', cp_run, { desc = 'CP: compile and run' })

