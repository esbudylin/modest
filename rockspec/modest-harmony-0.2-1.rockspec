package = "modest-harmony"
version = "0.2-1"
source = {
   url = "git://github.com/esbudylin/modest.git",
   tag = "0.2-1"
}
description = {
   homepage = "https://github.com/esbudylin/modest",
   summary = "Musical harmony library",
   detailed = "A library that provides methods for working with musical harmony — intervals, notes, chords. It supports flexible parsing of chord notation and can handle a wide range of chord types, from basic to complex.",
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
