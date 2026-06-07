vim.opt.rtp:prepend(".")
for _, p in ipairs({
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
}) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.rtp:prepend(p)
    break
  end
end
