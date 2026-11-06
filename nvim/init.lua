-- Use space key as the leader key (prefix key)
vim.g.mapleader = " "
vim.g.table_mode_corner = "|"
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { command = "checktime" })
vim.opt.number = true
vim.opt.relativenumber = true
-- Download and load fzf-lua
vim.pack.add({ "https://github.com/ibhagwan/fzf-lua" })

local fzf = require("fzf-lua")
fzf.setup({
	files = {
		actions = {
			--Enter opens all selected files instead of sending them to quickfix
			["enter"] = fzf.actions.file_edit,
		},
	},
})

-- FzF Keybinds
vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Search text in files" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Open buffers" })
vim.keymap.set("n", "<leader>fr", fzf.oldfiles, { desc = "Recent files" })

-- Automatically load vim-table-mode plugin when opening markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  once = true,
  callback = function()
    vim.pack.add({ "https://github.com/dhruvasagar/vim-table-mode" })
  end,
})

--Keybinds
--set "jj" to ESC when in insert mode 
vim.keymap.set("i", "jj", "<Esc>")

