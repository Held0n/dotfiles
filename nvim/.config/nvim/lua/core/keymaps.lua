
local function map(mode, lhs, rhs, opts)
  local options = { noremap=true, silent=true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Change leader to a <space>
vim.g.mapleader = ' '

map('i', 'jj', '<Esc>')

map('n', '<S-j>', '5j')
map('n', '<S-k>', '5k')
map('n', '<S-h>', '^')
map('n', '<S-l>', '$')

map('v', '<S-j>', '5j')
map('v', '<S-k>', '5k')
map('v', '<S-h>', '^')
map('v', '<S-l>', '$')

map('n', '<leader>/', ':nohl<CR>')
map('n', '<leader>q>', ':q<CR>')
map('n', '<leader>q>', ':q<CR>')

map('n', '<leader>h>', '<C-w>h')
map('n', '<leader>j>', '<C-w>j')
map('n', '<leader>k>', '<C-w>k')
map('n', '<leader>l>', '<C-w>l')

