-- Any copyright is dedicated to the Public Domain.
-- https://creativecommons.org/publicdomain/zero/1.0/

local luaunit = require "luaunit"

local fennel = require "fennel"
table.insert(package.loaders or package.searchers, fennel.searcher)

debug.traceback = fennel.traceback

local function get_fennel_files(dir, modules)
  local files = {}
  for _, mod in ipairs(modules) do
    table.insert(files, dir .. "/" .. mod .. ".fnl")
  end
  return files
end

local testdir = "tests"
local modules = { "chords", "intervals", "notes" }
local testfiles = get_fennel_files(testdir, modules)

for _, testfile in ipairs(testfiles) do
  fennel.dofile(testfile)
end

os.exit(luaunit.LuaUnit.run())
