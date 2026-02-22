local M = {}

--- @class Mark
--- @field name string|nil
--- @field file_path string
--- @field line number

--- Parse a marks.md file content into a list of marks.
--- Pure Lua — no vim.* dependencies.
--- @param content string
--- @param workspace_root string
--- @return Mark[]
function M.parse_marks_file(content, workspace_root)
  local marks = {}
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  local in_html_comment = false

  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Handle HTML-style markdown comments (<!-- ... -->)
    if in_html_comment then
      if trimmed:find("-->", 1, true) then
        in_html_comment = false
      end
      goto continue
    end

    if trimmed:sub(1, 4) == "<!--" then
      if not trimmed:find("-->", 5, true) then
        in_html_comment = true
      end
      goto continue
    end

    -- Skip empty lines and # comments
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      goto continue
    end

    -- Find the last colon (before the line number)
    local last_colon = nil
    for i = #trimmed, 1, -1 do
      if trimmed:sub(i, i) == ":" then
        last_colon = i
        break
      end
    end
    if not last_colon then
      goto continue
    end

    local line_str = trimmed:sub(last_colon + 1):match("^%s*(.-)%s*$")
    local line_num = tonumber(line_str)
    if not line_num or line_num ~= math.floor(line_num) then
      goto continue
    end

    local before_line_num = trimmed:sub(1, last_colon - 1):match("^%s*(.-)%s*$")

    -- Check if there's a name: prefix
    -- Using ": " (colon-space) instead of just ":" allows C++ namespaces
    local colon_space_index = before_line_num:find(": ", 1, true)

    local name, file_path

    if colon_space_index then
      local potential_name = before_line_num:sub(1, colon_space_index - 1):match("^%s*(.-)%s*$")
      local potential_path = before_line_num:sub(colon_space_index + 2):match("^%s*(.-)%s*$")

      if #potential_name > 0
        and not potential_name:find("/", 1, true)
        and not potential_name:find("\\", 1, true)
        and #potential_path > 0 then
        name = potential_name
        file_path = potential_path
      else
        name = nil
        file_path = before_line_num
      end
    else
      name = nil
      file_path = before_line_num
    end

    -- Resolve relative paths against workspace root
    local resolved_path
    if file_path:sub(1, 1) == "/" then
      resolved_path = file_path
    else
      resolved_path = workspace_root .. "/" .. file_path
    end

    marks[#marks + 1] = {
      name = name,
      file_path = resolved_path,
      line = line_num,
    }

    ::continue::
  end

  return marks
end

return M
