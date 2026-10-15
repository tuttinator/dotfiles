return {
  -- GitHub Copilot inline ghost text
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = '<M-l>', -- Alt-L accepts
          accept_word = '<M-w>',
          accept_line = '<M-j>',
          next = '<M-]>',
          prev = '<M-[>',
          dismiss = '<C-]>',
        },
      },
      panel = { enabled = false },
      filetypes = { markdown = true, gitcommit = true, yaml = true },
    },
  },

  -- Claude Code CLI wired into Neovim (same IDE protocol as the VS Code
  -- extension): it sees your selection/open buffers and proposes edits as
  -- native diffs. Uses the `claude` binary on PATH.
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {},
    keys = {
      { '<leader>ac', '<cmd>ClaudeCode<CR>', desc = 'Toggle Claude' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<CR>', desc = 'Focus Claude' },
      { '<leader>ar', '<cmd>ClaudeCode --resume<CR>', desc = 'Resume Claude' },
      { '<leader>aC', '<cmd>ClaudeCode --continue<CR>', desc = 'Continue Claude' },
      { '<leader>am', '<cmd>ClaudeCodeSelectModel<CR>', desc = 'Select Claude model' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<CR>', desc = 'Add current buffer' },
      { '<leader>as', '<cmd>ClaudeCodeSend<CR>', mode = 'x', desc = 'Send selection to Claude' },
      { '<leader>as', '<cmd>ClaudeCodeTreeAdd<CR>', desc = 'Add file', ft = { 'oil', 'snacks_picker_list' } },
      { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<CR>', desc = 'Accept diff' },
      { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<CR>', desc = 'Deny diff' },
    },
  },
}
