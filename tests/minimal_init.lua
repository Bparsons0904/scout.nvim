local log_path = vim.fn.tempname()
vim.env.NVIM_LOG_FILE = log_path
vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    vim.fn.delete(log_path)
  end,
})

vim.opt.rtp:prepend(".")
vim.opt.swapfile = false
for _, p in ipairs({
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
}) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.rtp:prepend(p)
    break
  end
end
