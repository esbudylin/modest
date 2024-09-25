local lfs = require "lfs"
local luaunit = require "luaunit"

local fennel = require "fennel"
table.insert(package.loaders or package.searchers, fennel.searcher)

debug.traceback = fennel.traceback

local function get_lua_files(dir)
  local files = {}
  for file in lfs.dir(dir) do
    if file:match "%.fnl$" then
      table.insert(files, dir .. "/" .. file)
    end
  end
  return files
end

local testdir = "tests"
local testfiles = get_lua_files(testdir)

for _, testfile in ipairs(testfiles) do
  fennel.dofile(testfile)
end

os.exit(luaunit.LuaUnit.run())
