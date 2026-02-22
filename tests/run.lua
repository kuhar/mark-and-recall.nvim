-- Minimal test harness for running tests with: nvim --headless -l tests/run.lua

local passed = 0
local failed = 0
local errors = {}

local current_describe = ""

function describe(name, fn)
  local parent = current_describe
  current_describe = parent == "" and name or (parent .. " > " .. name)
  fn()
  current_describe = parent
end

function it(name, fn)
  local full_name = current_describe .. " > " .. name
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.write("  \27[32m✓\27[0m " .. full_name .. "\n")
  else
    failed = failed + 1
    errors[#errors + 1] = { name = full_name, err = err }
    io.write("  \27[31m✗\27[0m " .. full_name .. "\n")
    io.write("    " .. tostring(err) .. "\n")
  end
end

function assert_eq(actual, expected, msg)
  if actual ~= expected then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function assert_nil(actual, msg)
  if actual ~= nil then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected nil, got " .. tostring(actual), 2)
  end
end

function assert_table_eq(actual, expected, msg)
  local prefix = msg and (msg .. ": ") or ""

  if type(actual) ~= "table" or type(expected) ~= "table" then
    error(prefix .. "expected both values to be tables", 2)
  end

  -- Check all keys in expected exist in actual with same values
  for k, v in pairs(expected) do
    if type(v) == "table" then
      if type(actual[k]) ~= "table" then
        error(prefix .. "key '" .. tostring(k) .. "': expected table, got " .. type(actual[k]), 2)
      end
      local ok, err = pcall(assert_table_eq, actual[k], v, prefix .. tostring(k))
      if not ok then error(err, 2) end
    elseif actual[k] ~= v then
      error(prefix .. "key '" .. tostring(k) .. "': expected " .. tostring(v) .. ", got " .. tostring(actual[k]), 2)
    end
  end

  -- Check no extra keys in actual
  for k, _ in pairs(actual) do
    if expected[k] == nil then
      error(prefix .. "unexpected key '" .. tostring(k) .. "'", 2)
    end
  end
end

-- Discover and run test files
local script_path = debug.getinfo(1, "S").source:match("@(.*)")
if not script_path then
  script_path = arg and arg[0] or "tests/run.lua"
end

-- Resolve to absolute path if relative
if script_path:sub(1, 1) ~= "/" then
  local handle = io.popen("pwd")
  local cwd = handle:read("*l")
  handle:close()
  script_path = cwd .. "/" .. script_path
end

local script_dir = script_path:match("(.*/)")
local plugin_root = script_dir:match("(.*/)[^/]*/")

-- Add the plugin's lua directory to package.path
package.path = plugin_root .. "lua/?.lua;" .. plugin_root .. "lua/?/init.lua;" .. package.path

-- Collect test files
local test_files = {}
local handle = io.popen('ls "' .. script_dir .. '"test_*.lua 2>/dev/null')
if handle then
  for line in handle:lines() do
    test_files[#test_files + 1] = line
  end
  handle:close()
end

if #test_files == 0 then
  io.write("No test files found in " .. script_dir .. "\n")
  os.exit(1)
end

io.write("\n")
for _, file in ipairs(test_files) do
  io.write("Running " .. file .. "\n")
  dofile(file)
  io.write("\n")
end

io.write(string.format("\n%d passed, %d failed\n", passed, failed))

if failed > 0 then
  io.write("\nFailures:\n")
  for _, e in ipairs(errors) do
    io.write("  " .. e.name .. "\n")
    io.write("    " .. e.err .. "\n")
  end
  os.exit(1)
end
