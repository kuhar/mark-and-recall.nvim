local marks_mod = require("mark-and-recall.marks")

local M = {}

local ns = nil

function M.setup()
  ns = vim.api.nvim_create_namespace("mark-and-recall")

  vim.api.nvim_set_hl(0, "MarkAndRecallSign", { default = true, fg = "#2196F3", bold = true })
  vim.api.nvim_set_hl(0, "MarkAndRecallLineHighlight", { default = true, bg = "#1a2a3a" })
end

--- Update signs for a single buffer.
--- @param bufnr number
function M.update_signs(bufnr)
  if not ns then return end
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if buf_name == "" then return end
  local file_path = vim.fn.resolve(buf_name)

  local marks = marks_mod.read_marks()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, mark in ipairs(marks) do
    if mark.file_path == file_path then
      local line_0 = mark.line - 1
      if line_0 >= 0 and line_0 < line_count then
        local sign_text
        if mark.index < 9 then
          sign_text = tostring(mark.index + 1)
        else
          sign_text = "*"
        end

        vim.api.nvim_buf_set_extmark(bufnr, ns, line_0, 0, {
          sign_text = sign_text,
          sign_hl_group = "MarkAndRecallSign",
          line_hl_group = "MarkAndRecallLineHighlight",
          priority = 10,
        })
      end
    end
  end
end

--- Update signs for all loaded buffers.
function M.update_all_signs()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      M.update_signs(bufnr)
    end
  end
end

return M
