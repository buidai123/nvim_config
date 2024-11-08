return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = {
		{ "williamboman/mason.nvim" },
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		"hrsh7th/cmp-nvim-lsp", -- for autocompletion
		-- { "antosha417/nvim-lsp-file-operations", config = true },
		"nvim-lua/plenary.nvim",
		{ "justinsgithub/wezterm-types", lazy = true },
		{ "LuaCATS/luassert", name = "luassert-types", lazy = true },
		{ "LuaCATS/busted", name = "busted-types", lazy = true },
		{
			"folke/lazydev.nvim",
			ft = "lua",
			opts = {
				library = {
					-- Load luvit types when the `vim.uv` word is found
					{ path = "luvit-meta/library", words = { "vim%.uv" } },
					{ path = "wezterm-types", mods = { "wezterm" } },
					{ path = "luassert-types/library", words = { "assert" } },
					{ path = "busted-types/library", words = { "describe" } },
				},
			},
		},
	},
	config = function()
		local lspconfig = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")
		local util = require("lspconfig.util")
		local lspui = require("lspconfig.ui.windows")

		require("lazydev").setup()
		lspui.default_options.border = "none"

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
			callback = function(event)
				local map = function(keys, func, desc)
					vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
				end

				map("<leader>rs", ":LspRestart", "LSP [R]e[S]tart")

				-- Diagnostic keymaps
				-- Don't need these right now
				map("[d", vim.diagnostic.goto_prev, "Go to previous diagnostic message")
				map("]d", vim.diagnostic.goto_next, "Go to next diagnostic message")

				-- Lesser used LSP functionality
				map("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
				map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
				map("<leader>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, "[W]orkspace [L]ist Folders")

				vim.api.nvim_buf_create_user_command(event.buf, "Format", function(_)
					vim.lsp.buf.format()
				end, { desc = "Format current buffer with LSP" })

				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client.server_capabilities.documentHighlightProvider then
					local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.clear_references,
					})
				end

				vim.api.nvim_create_autocmd("LspDetach", {
					group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
					callback = function(event2)
						vim.lsp.buf.clear_references()
						vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
					end,
				})

				if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
					vim.lsp.inlay_hint.enable(true, { event.buf })
					map("<leader>ti", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
					end, "[T]oggle [I]nlay Hints")
				end

				vim.diagnostic.config({
					signs = {
						active = true,
						values = {
							{ name = "DiagnosticSignError", text = "" },
							{ name = "DiagnosticSignWarn", text = "" },
							{ name = "DiagnosticSignHint", text = "󰌶" },
							{ name = "DiagnosticSignInfo", text = "" },
						},
					},
					virtual_text = {
						spacing = 4,
						source = "if_many",
						prefix = "●",
					},
					update_in_insert = false,
					underline = true,
					severity_sort = true,
					float = {
						focusable = true,
						style = "minimal",
						border = "none",
						source = "always",
						header = "",
						prefix = "",
					},
				})
			end,
		})

		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities = vim.tbl_deep_extend("force", capabilities, cmp_nvim_lsp.default_capabilities())

		local servers = {
			-- bashls = {}, -- Bash
			clangd = {
				cmd = {
					"clangd",
					"--function-arg-placeholders=0",
				},
			}, -- C/C++
			marksman = {}, -- Markdown lsp
			sqlls = {}, -- SQL
			eslint = {}, -- React/NextJS/Svelte
			emmet_language_server = {}, -- HTML
			ts_ls = {}, -- Javascript, TypeScript
			html = {}, -- HTML
			htmx = {}, -- HTMX
			cssls = {}, -- CSS
			tailwindcss = {}, -- Tailwind CSS
			templ = {}, -- Templ
			pyright = {}, -- Python
			gopls = { -- Golang
				cmd = { "gopls" },
				filetypes = { "go", "gomod", "gowork", "gotmpl" },
				root_dir = util.root_pattern("go.work", "go.mod", ".git"),
				settings = {
					gopls = {
						completeUnimported = true,
						usePlaceholders = false,
						analyses = {
							unusedparams = true,
							unreachable = true,
						},
						-- report vulnerabilities
						vulncheck = "Imports",
						staticcheck = true,
						gofumpt = true,
					},
				},
			},
			lua_ls = {
				settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						workspace = {
							checkThirdParty = false,
						},
						completion = {
							callSnippet = "Replace",
							displayContext = 10,
							keywordSnippet = "Both",
						},
						diagnostics = {
							globals = { "vim" },
							disable = { "missing-fields" },
						},
						codeLens = {
							enable = true,
						},
						doc = {
							privateName = { "^_" },
						},
						hint = {
							enable = true,
							setType = false,
							paramType = true,
							paramName = "Disable",
							semicolon = "Disable",
							arrayIndex = "Disable",
						},
					},
				},
			},
		}

		local border = {
			{ "╭", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "╮", "FloatBorder" },
			{ "│", "FloatBorder" },
			{ "╯", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "╰", "FloatBorder" },
			{ "│", "FloatBorder" },
		}

		local ensure_installed = vim.tbl_keys(servers or {})
		vim.list_extend(ensure_installed, {
			-- FORMATTERS
			{ "gofumpt" }, -- GO
			{ "goimports" }, -- GO
			{ "black" }, -- Python
			{ "isort" }, -- Python
			{ "prettierd" }, -- JS and Many More
			{ "prettier" }, -- JS and Many More
			{ "shfmt" }, -- Shell Script
			{ "stylua" }, -- Lua

			-- LINTERS
			{ "codespell" },
			-- { "eslint_d" },
			{ "pylint" },
			{ "shellcheck" },

			--DAP
			{ "delve" },
			{ "debugpy" },
		})
		mason_tool_installer.setup({
			ensure_installed = ensure_installed,

			auto_update = true,
			run_on_start = true,
			start_delay = 3000, -- 3 second delay
		})

		local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
		function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
			opts = opts or {}
			opts.border = opts.border or border
			return orig_util_open_floating_preview(contents, syntax, opts, ...)
		end

		mason_lspconfig.setup({
			handlers = {
				function(server_name)
					local server = servers[server_name] or {}
					server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
					lspconfig[server_name].setup(server)
				end,
			},
		})
	end,
}
