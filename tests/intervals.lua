local luaunit = require "luaunit"
local lib = require "modest"

local Note = lib.Note
local Interval = lib.Interval

local unpack = unpack or table.unpack

local function assert_intervals(test_cases)
  for _, test_case in ipairs(test_cases) do
    local note1, note2, interval, semitones = unpack(test_case)
    local transposition = test_case.transposition or note2

    luaunit.assertEquals(
      Interval.identify(note1, note2):tostring(),
      interval,
      "Mismatched interval name for notes " .. tostring(note1) .. " " .. tostring(note2)
    )

    luaunit.assertEquals(
      Interval.identify(note1, note2):semitones(),
      semitones,
      "Mismatched semitones for notes " .. tostring(note1) .. " " .. tostring(note2)
    )

    luaunit.assertEquals(
      Interval.identify(note1:toascii(), note2:toascii()):tostring(),
      interval,
      "Can't identify by strings" .. tostring(note1) .. " " .. tostring(note2)
    )

    luaunit.assertEquals(
      note1:transpose(Interval.fromstring(interval)),
      transposition,
      "Mismatched transposition result " .. tostring(note1) .. " " .. tostring(note2)
    )

    luaunit.assertEquals(
      note1:transpose(interval),
      transposition,
      "Can't tranpose by string" .. tostring(note1) .. " " .. tostring(note2)
    )

    luaunit.assertEquals(
      transposition:transpose_down(Interval.fromstring(interval)),
      note1,
      "Mismatched result for transpose_down " .. tostring(transposition) .. " " .. interval
    )

    luaunit.assertEquals(
      transposition:transpose_down(interval),
      note1,
      "Can't transpose down by string " .. tostring(transposition) .. " " .. interval
    )
  end
end

local across_octave = {
  { Note.new("C", 0, 0), Note.new("C", 0, 1), "P8", 12 },
  { Note.new("C", 0, 0), Note.new("D", 0, 1), "M9", 14 },
  { Note.new("C", 0, 0), Note.new("D", 1, 1), "A9", 15 },
  { Note.new("B", 0, 0), Note.new("C", 1, 1), "M2", 2 },
  { Note.new("D", 0, 0), Note.new("C", 0, 1), "m7", 10 },
  { Note.new("C", 0, 0), Note.new("C", 0, 2), "P15", 24 },
  { Note.new("C", 0, 0), Note.new("D", 0, 2), "M16", 26 },
  { Note.new("D", 0, 0), Note.new("C", 0, 2), "m14", 22 },
  { Note.new("B", 0, 0), Note.new("C", 1, 2), "M9", 14 },
  { Note.new("C", 0, 4), Note.new("C", 1, 5), "A8", 13 },
  { Note.new("C", 0, 4), Note.new("C", -1, 5), "d8", 11 },
  { Note.new("C", 0, 4), Note.new("C", -1, 6), "d15", 23 },
}

function test_across_octaves() assert_intervals(across_octave) end

local octave_unaware = {
  { Note.new("C", 0, nil), Note.new("C", 0, nil), "P1", 0 },
  { Note.new("C", 0, nil), Note.new("D", 0, nil), "M2", 2 },
  { Note.new("B", -1, nil), Note.new("C", 0, nil), "M2", 2 },
  { Note.new("D", 0, nil), Note.new("C", 0, nil), "m7", 10 },
  { Note.new("C", 0, nil), Note.new("E", -1, nil), "m3", 3 },
  { Note.new("C", 0, nil), Note.new("C", -1, nil), "d8", 11 },
  { Note.new("D", 0, nil), Note.new("C", 0, 4), "m7", 10, transposition = Note.new("C", 0, nil) },
  { Note.new("D", 0, 4), Note.new("C", 0, nil), "m7", 10, transposition = Note.new("C", 0, 5) },
}

function test_octave_unaware() assert_intervals(octave_unaware) end

local unison = {
  { Note.new("C", 0, 0), Note.new("C", 0, 0), "P1", 0 },
  { Note.new("D", 1, 0), Note.new("D", 1, 0), "P1", 0 },
  { Note.new("B", 1, 0), Note.new("C", 0, 1), "d2", 0 },
}

function test_unisons() assert_intervals(unison) end

local interval_to_semitones = {
  M3 = 4,
  P4 = 5,
  M10 = 16,
  P11 = 17,
  d3 = 2,
  A4 = 6,
  d2 = 0,
  A7 = 12,
}

function test_interval_to_semitones()
  for interval, expected_semitones in pairs(interval_to_semitones) do
    luaunit.assertEquals(
      Interval.fromstring(interval):semitones(),
      expected_semitones,
      "Mismatched semitones amount for interval " .. interval
    )
  end
end

local invalid_intervals = { "d1", "M5", "P3" }

function test_invalid_intervals()
  for _, inv_int in pairs(invalid_intervals) do
    local _, err = pcall(function() Interval.fromstring(inv_int) end)
    luaunit.assertNotEquals(err, nil, "Interval " .. inv_int .. " validated")
  end
end
