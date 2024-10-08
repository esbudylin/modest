package = "modest"
version = "0.1-1"
source = {
   url = "git://github.com/esbudylin/modest.git",
   tag = "0.1-1"
}
description = {
   homepage = "https://github.com/esbudylin/modest",
   summary = "Musical harmony library",
   license = "Mozilla Public License Version 2.0"
}
dependencies = {
   "lua >= 5.1, < 5.5",
   "fennel ~> 1.5",
   "lpeg ~> 1.1",
   "luarocks-build-fennel ~> 0.1",
}
build = {
   type = "fennel",
   modules = {
      ["modest"] = "modest/init.fnl",
      ["modest.utils"] = "modest/utils.fnl",
      ["modest.basics"] = "modest/basics.fnl",
      ["modest.chord"] = "modest/chord.fnl",
      ["modest.grammars"] = "modest/grammars.lua"
   },
}
