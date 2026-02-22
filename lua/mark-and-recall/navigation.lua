local marks_mod = require("mark-and-recall.marks")

local M = {}

-- Track last navigated mark index for global next/prev
M._last_index = nil

--- Navigate to a mark: open file, set cursor, center view.
--- @param mark table { file_path: string, line: number, index: number|nil }
function M.navigate_to_mark(mark)
  vim.cmd.edit(mark.file_path)
  local line = math.min(mark.line, vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.cmd("normal! zz")
  if mark.index then
    M._last_index = mark.index
  end
end

--- Jump to next mark in current file (wraps around).
function M.next_mark_in_file()
  local file_path = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local marks = marks_mod.read_marks()

  -- Filter and sort by line
  local file_marks = {}
  for _, m in ipairs(marks) do
    if m.file_path == file_path then
      file_marks[#file_marks + 1] = m
    end
  end

  if #file_marks == 0 then
    vim.notify("No marks in current file", vim.log.levels.INFO)
    return
  end

  table.sort(file_marks, function(a, b) return a.line < b.line end)

  -- Find next mark below cursor
  for _, m in ipairs(file_marks) do
    if m.line > cursor_line then
      M.navigate_to_mark(m)
      return
    end
  end

  -- Wrap to first
  M.navigate_to_mark(file_marks[1])
end

--- Jump to previous mark in current file (wraps around).
function M.prev_mark_in_file()
  local file_path = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local marks = marks_mod.read_marks()

  local file_marks = {}
  for _, m in ipairs(marks) do
    if m.file_path == file_path then
      file_marks[#file_marks + 1] = m
    end
  end

  if #file_marks == 0 then
    vim.notify("No marks in current file", vim.log.levels.INFO)
    return
  end

  table.sort(file_marks, function(a, b) return a.line < b.line end)

  -- Find previous mark above cursor
  for i = #file_marks, 1, -1 do
    if file_marks[i].line < cursor_line then
      M.navigate_to_mark(file_marks[i])
      return
    end
  end

  -- Wrap to last
  M.navigate_to_mark(file_marks[#file_marks])
end

--- Get the current mark index based on cursor position or last navigation.
--- @return number|nil 0-based index
local function get_current_index(marks)
  local file_path = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Check if cursor is on a mark
  for _, m in ipairs(marks) do
    if m.file_path == file_path and m.line == cursor_line then
      M._last_index = m.index
      return m.index
    end
  end

  -- Fall back to last navigated
  if M._last_index and M._last_index < #marks then
    return M._last_index
  end

  return nil
end

--- Jump to next mark globally (wraps around).
function M.next_mark_global()
  local marks = marks_mod.read_marks()
  if #marks == 0 then
    vim.notify("No marks defined", vim.log.levels.INFO)
    return
  end

  local current = get_current_index(marks)
  local next_idx = current and ((current + 1) % #marks) or 0
  M.navigate_to_mark(marks[next_idx + 1]) -- 1-based table access
end

--- Jump to previous mark globally (wraps around).
function M.prev_mark_global()
  local marks = marks_mod.read_marks()
  if #marks == 0 then
    vim.notify("No marks defined", vim.log.levels.INFO)
    return
  end

  local current = get_current_index(marks)
  local prev_idx = current and ((current - 1 + #marks) % #marks) or 0
  M.navigate_to_mark(marks[prev_idx + 1])
end

--- Jump to mark by 1-based user index.
--- @param n number 1-based index
function M.recall_by_index(n)
  local marks = marks_mod.read_marks()
  if n < 1 or n > #marks then
    vim.notify(string.format("Mark %d out of range (have %d marks)", n, #marks), vim.log.levels.WARN)
    return
  end
  M.navigate_to_mark(marks[n])
end

--- Open Telescope picker for marks.
function M.telescope_pick()
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local marks = marks_mod.read_marks()
  if #marks == 0 then
    vim.notify("No marks found", vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 4 },
      { width = 30 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    local m = entry.mark
    local idx_str = m.index < 9 and string.format("[%d]", m.index + 1) or "[*]"
    local name = m.name or vim.fn.fnamemodify(m.file_path, ":t")
    local location = marks_mod.relative_path(m.file_path) .. ":" .. m.line
    return displayer({ idx_str, name, location })
  end

  pickers.new({}, {
    prompt_title = "Marks",
    finder = finders.new_table({
      results = marks,
      entry_maker = function(m)
        local display_name = m.name or vim.fn.fnamemodify(m.file_path, ":t")
        return {
          value = m,
          display = make_display,
          ordinal = display_name .. " " .. m.file_path .. ":" .. m.line,
          mark = m,
          filename = m.file_path,
          lnum = m.line,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = conf.grep_previewer({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          M.navigate_to_mark(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
