-- Ensure lazy.nvim is installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git", "clone", "--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", lazypath
	})
end
vim.opt.rtp:prepend(lazypath)

-- LSP on_attach function with keymaps
local on_attach = function(client, bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }
	-- LSP navigation
	vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
	vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
	vim.keymap.set('n', 'gI', vim.lsp.buf.implementation, opts)
	vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
	vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, opts)
	vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
	vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)
	vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
	vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
	-- Setup navic (current code context) if LSP supports it
	if client.server_capabilities.documentSymbolProvider then
		require("nvim-navic").attach(client, bufnr)
	end
end

-- Initialize lazy.nvim with plugins
require("lazy").setup({
	-- Tokyo Night theme
	{
		"folke/tokyonight.nvim",
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = true,
				on_highlights = function(hl, c)
					-- set telescope-bg transparent
					hl.TelescopeNormal = {
						fg = c.fg_dark,
					}
					hl.TelescopeBorder = {
						fg = c.bg_dark,
					}
				end,
			})
			vim.cmd [[colorscheme tokyonight]]
		end,
	},
	-- LSP, Mason & Formatting
	{
		"williamboman/mason.nvim",
		dependencies = {
			"neovim/nvim-lspconfig",
			"williamboman/mason-lspconfig.nvim",
			"nvimtools/none-ls.nvim", -- Add this dependency
		},
		config = function()
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = { "pyright", "gopls", "lua_ls", "clangd", "rust_analyzer", "ocamllsp", "omnisharp" },
				automatic_installation = true,
			})

			-- Set up null-ls for additional formatting/import functionality
			local null_ls = require("null-ls")
			null_ls.setup({
				sources = {
					-- Go import
					null_ls.builtins.formatting.goimports,
					null_ls.builtins.diagnostics.golangci_lint,
					-- gitsigns
					null_ls.builtins.code_actions.gitsigns,
					-- Python imports
					null_ls.builtins.formatting.isort,
				},
			})

			-- Enhanced LSP setup with import configuration
			local lspconfig = require("lspconfig")

			-- Configure gopls with imports
			lspconfig.gopls.setup({
				on_attach = on_attach,
				settings = {
					gopls = {
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
						gofumpt = true,
						usePlaceholders = true,
						completeUnimported = true,
						experimentalPostfixCompletions = true,
					},
				},
			})

			-- Configure rust-analyzer with imports
			lspconfig.rust_analyzer.setup({
				on_attach = on_attach,
				settings = {
					["rust-analyzer"] = {
						imports = {
							granularity = {
								group = "module",
							},
							prefix = "self",
						},
						cargo = {
							buildScripts = {
								enable = true,
							},
						},
						procMacro = {
							enable = true,
						},
						checkOnSave = {
							command = "clippy",
						},
					}
				}
			})
			-- Configure pyright with imports
			lspconfig.pyright.setup({
				on_attach = on_attach,
				settings = {
					python = {
						analysis = {
							autoSearchPaths = true,
							diagnosticMode = "workspace",
							useLibraryCodeForTypes = true
						}
					}
				}
			})

			-- Set up other LSPs with default config
			for _, server in ipairs({ "lua_ls", "clangd", "ocamllsp", "omnisharp" }) do
				lspconfig[server].setup({
					on_attach = on_attach,
				})
			end

			-- Auto-format on save
			vim.api.nvim_create_autocmd("BufWritePre", {
				pattern = { "*.go", "*.rs", "*.py", "*.js", "*.jsx", "*.ts", "*.tsx" },
				callback = function()
					vim.lsp.buf.format({ async = false })
				end,
			})
		end,
	},

	-- Add a dedicated formatter plugin for more control
	{
		"nvimtools/none-ls.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvimtools/none-ls-extras.nvim",
		},
	},

	-- Add conform.nvim for enhanced formatting control
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>f",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				mode = "",
				desc = "Format buffer",
			},
		},
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "isort", "black" },
				go = { "goimports", "gofmt" },
				rust = { "rustfmt" },
			},
			format_on_save = {
				timeout_ms = 500,
				lsp_fallback = true,
			},
		},
	},
	-- LSP Signature (shows function signatures as you type)
	{
		"ray-x/lsp_signature.nvim",
		event = "VeryLazy",
		config = function()
			require("lsp_signature").setup({
				bind = true,
				handler_opts = {
					border = "rounded"
				},
				hint_enable = false, -- Disable virtual text hints
			})
		end,
	},
	-- Navic (shows code context at the top)
	{
		"SmiteshP/nvim-navic",
		dependencies = "neovim/nvim-lspconfig",
		config = function()
			require("nvim-navic").setup({
				icons = {
					File = "📄 ",
					Module = "📦 ",
					Namespace = "🏷️ ",
					Package = "📁 ",
					Class = "🔶 ",
					Method = "🔷 ",
					Property = "🔧 ",
					Field = "🏁 ",
					Constructor = "🏗️ ",
					Enum = "🔢 ",
					Interface = "🔌 ",
					Function = "⚙️ ",
					Variable = "📌 ",
					Constant = "🔒 ",
					String = "📝 ",
					Number = "🔢 ",
					Boolean = "⚖️ ",
					Array = "📚 ",
					Object = "🧩 ",
					Key = "🔑 ",
					Null = "❌ ",
					EnumMember = "🔍 ",
					Struct = "🧱 ",
					Event = "🎭 ",
					Operator = "💠 ",
					TypeParameter = "🔡 "
				},
				lsp = {
					auto_attach = true,
				},
			})
		end,
	},
	-- NeoGit
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration

			-- Only one of these is needed.
			"nvim-telescope/telescope.nvim", -- optional
		},
		cmd = "Neogit",
		keys = {
			{ "<leader>gg", "<cmd>Neogit<CR>", desc = "Open Neogit" },
		},
		config = function()
			require("neogit").setup()
		end,
	},
	-- Trouble (better diagnostics UI)
	{
		"folke/trouble.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		cmd = { "TroubleToggle", "Trouble" },
		keys = {
			{ "<leader>xx", "<cmd>TroubleToggle<cr>",                       desc = "Toggle Trouble" },
			{ "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics" },
			{ "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>",  desc = "Document Diagnostics" },
			{ "<leader>xl", "<cmd>TroubleToggle loclist<cr>",               desc = "Location List" },
			{ "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",              desc = "Quickfix List" },
			{ "gR",         "<cmd>TroubleToggle lsp_references<cr>",        desc = "LSP References" },
		},
		opts = {
			auto_close = true,
			use_diagnostic_signs = true,
		},
	},
	-- GitSigns (git integration in the gutter)
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "│" },
					change = { text = "│" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns
					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end
					-- Navigation
					map('n', ']c', function()
						if vim.wo.diff then return ']c' end
						vim.schedule(function() gs.next_hunk() end)
						return '<Ignore>'
					end, { expr = true })
					map('n', '[c', function()
						if vim.wo.diff then return '[c' end
						vim.schedule(function() gs.prev_hunk() end)
						return '<Ignore>'
					end, { expr = true })
					-- Actions
					map('n', '<leader>hs', gs.stage_hunk, { desc = 'Stage Hunk' })
					map('n', '<leader>hr', gs.reset_hunk, { desc = 'Reset Hunk' })
					map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
						{ desc = 'Stage Selected Hunks' })
					map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
						{ desc = 'Reset Selected Hunks' })
					map('n', '<leader>hS', gs.stage_buffer, { desc = 'Stage Buffer' })
					map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Undo Stage Hunk' })
					map('n', '<leader>hR', gs.reset_buffer, { desc = 'Reset Buffer' })
					map('n', '<leader>hp', gs.preview_hunk, { desc = 'Preview Hunk' })
					map('n', '<leader>hb', function() gs.blame_line { full = true } end, { desc = 'Blame Line' })
					map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = 'Toggle Line Blame' })
					map('n', '<leader>hd', gs.diffthis, { desc = 'Diff This' })
					map('n', '<leader>hD', function() gs.diffthis('~') end, { desc = 'Diff This ~' })
					map('n', '<leader>td', gs.toggle_deleted, { desc = 'Toggle Deleted' })
				end
			})
		end,
	},
	-- Treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "lua", "python", "go", "c", "cpp", "rust", "ocaml", "c_sharp" },
				highlight = { enable = true },
				indent = { enable = true },
				playground = { enable = true },
			})
		end,
	},
	-- Telescope
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = "Telescope",
		keys = {
			{ "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
			{ "<leader>/",        "<cmd>Telescope live_grep<cr>",  desc = "Live Grep" },
			{ "<leader>bb",       "<cmd>Telescope buffers<cr>",    desc = "Buffers" },
			{ "<leader>fh",       "<cmd>Telescope help_tags<cr>",  desc = "Help Tags" },
		},
		config = function()
			require("telescope").setup()
		end,
	},
	-- UndoTree
	{
		"mbbill/undotree",
		cmd = "UndotreeToggle",
		keys = {
			{ "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undotree" },
		},
	},
	-- Lualine (Statusline) with navic integration
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons", "SmiteshP/nvim-navic" },
		config = function()
			require("lualine").setup({
				options = { theme = "tokyonight" },
				sections = {
					lualine_c = {
						{ "filename" },
						{
							function() return require("nvim-navic").get_location() end,
							cond = function()
								return package
									.loaded["nvim-navic"] and require("nvim-navic").is_available()
							end
						},
					}
				}
			})
		end,
	},
	-- AutoClose (Auto-closing brackets)
	{
		'windwp/nvim-autopairs',
		event = "InsertEnter",
		config = true
	},
	-- Comment.nvim (gc to comment)
	{
		"numToStr/Comment.nvim",
		event = "BufRead",
		config = function()
			require("Comment").setup()
		end,
	},
})
