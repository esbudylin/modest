local luaunit = require('luaunit')
local lib = require('init')

local Note = lib.Note

local note_to_pitchclass = {
   { Note.new("C", 0, 0),  0 },
   { Note.new("C", 0, 5),  0 },
   { Note.new("D", 1, 0),  3 },
   { Note.new("B", -1, 0), 10 },
   { Note.new("B", 1, 0),  0 },
}

function test_note_pitchclass()
   for _, tbl in ipairs(note_to_pitchclass) do
      local note, integer = table.unpack(tbl)
      luaunit.assertEquals(note:pitch_class(), integer)
   end
end
