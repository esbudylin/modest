local luaunit = require "luaunit"
local lib = require "modest"

local u = require "modest.utils"

local unpack = unpack or table.unpack

-- most of test cases in this file are based on the test suites of teoria and sharp11 libraries
-- https://github.com/jsrmath/sharp11/blob/master/test/chord.test.js
-- https://github.com/saebekassebil/teoria/blob/master/test/chords.js

local function test_chords(chords, octave)
  for _, test in ipairs(chords) do
    local parsed_chord = lib.Chord.fromstring(test.chord)

    luaunit.assertEquals(
      u.map(tostring, parsed_chord:notes(octave)),
      test.letters,
      "Mismatched notes for chord: " .. test.chord
    )

    if test.numeric then
      luaunit.assertEquals(
        parsed_chord:numeric(),
        test.numeric,
        "Mismatched numeric notation for chord: " .. test.chord
      )
    end
  end
end

function test_chord_symbol_aliases()
  local chords = {
    { chord = "C∆7", letters = { "C", "E", "G", "B" } },
    { chord = "Cmin", letters = { "C", "E♭", "G" } },
    { chord = "CminMaj9#11", letters = { "C", "E♭", "G", "B", "D", "F♯" } },
    { chord = "Cmin(maj)7", letters = { "C", "E♭", "G", "B" } },
    { chord = "Co", letters = { "C", "E♭", "G♭" } },
  }

  test_chords(chords)
end

function test_basic_chords()
  local chords = {
    { chord = "C", letters = { "C", "E", "G" }, numeric = { 0, 4, 7 } },
    { chord = "Cm", letters = { "C", "E♭", "G" }, numeric = { 0, 3, 7 } },
    { chord = "C6", letters = { "C", "E", "G", "A" }, numeric = { 0, 4, 7, 9 } },
    { chord = "C7", letters = { "C", "E", "G", "B♭" }, numeric = { 0, 4, 7, 10 } },
    { chord = "C9", letters = { "C", "E", "G", "B♭", "D" } },
    { chord = "Cm7", letters = { "C", "E♭", "G", "B♭" } },
    { chord = "CM7", letters = { "C", "E", "G", "B" } },
    { chord = "CM9", letters = { "C", "E", "G", "B", "D" } },
    { chord = "CmM7", letters = { "C", "E♭", "G", "B" } },
    { chord = "C+", letters = { "C", "E", "G♯" } },
    { chord = "C+7", letters = { "C", "E", "G♯", "B♭" } },
    { chord = "C+M7", letters = { "C", "E", "G♯", "B" } },
    { chord = "Cdim", letters = { "C", "E♭", "G♭" }, numeric = { 0, 3, 6 } },
    { chord = "Cdim7", letters = { "C", "E♭", "G♭", "B𝄫" }, numeric = { 0, 3, 6, 9 } },
    { chord = "Cø", letters = { "C", "E♭", "G♭", "B♭" } },
    { chord = "Cø7", letters = { "C", "E♭", "G♭", "B♭" } },
    { chord = "Csus4", letters = { "C", "F", "G" } },
    { chord = "Csus2", letters = { "C", "D", "G" } },
    { chord = "C6/9", letters = { "C", "E", "G", "A", "D" } },
    { chord = "Cm6/9", letters = { "C", "E♭", "G", "A", "D" } },
    { chord = "C/Bb", letters = { "B♭", "C", "E", "G" }, numeric = { -2, 0, 4, 7 } },
  }

  test_chords(chords)
end

function test_chords_with_alterations()
  local chords = {
    { chord = "Cm7b5", letters = { "C", "E♭", "G♭", "B♭" } },
    { chord = "C7b9", letters = { "C", "E", "G", "B♭", "D♭" } },
    { chord = "C7♯9", letters = { "C", "E", "G", "B♭", "D♯" } },
    { chord = "C7♯11", letters = { "C", "E", "G", "B♭", "F♯" } },
    { chord = "C13♯11", letters = { "C", "E", "G", "B♭", "D", "F♯", "A" } },
    { chord = "C13#9b5", letters = { "C", "E", "G♭", "B♭", "D♯", "F", "A" } },
  }

  test_chords(chords)
end

function test_add_chords()
  local chords = {
    { chord = "Cadd9", letters = { "C", "E", "G", "D" } },
    { chord = "Cadd11", letters = { "C", "E", "G", "F" } },
    { chord = "Cadd13", letters = { "C", "E", "G", "A" } },
    { chord = "C7add9", letters = { "C", "E", "G", "B♭", "D" } },
    { chord = "C7add11", letters = { "C", "E", "G", "B♭", "F" } },
    { chord = "C7add13", letters = { "C", "E", "G", "B♭", "A" } },
    { chord = "C9add11", letters = { "C", "E", "G", "B♭", "D", "F" } },
    { chord = "C9add13", letters = { "C", "E", "G", "B♭", "D", "A" } },
    { chord = "C11add13", letters = { "C", "E", "G", "B♭", "D", "F", "A" } },
  }

  test_chords(chords)
end

function test_chords_not_in_c()
  local chords = {
    { chord = "Emaj7", letters = { "E", "G♯", "B", "D♯" }, numeric = { 4, 8, 11, 15 } },
    { chord = "A+", letters = { "A", "C♯", "E♯" }, numeric = { 9, 13, 17 } },
    { chord = "Bb+", letters = { "B♭", "D", "F♯" }, numeric = { 10, 14, 18 } },
    { chord = "F#maj7", letters = { "F♯", "A♯", "C♯", "E♯" } },
    { chord = "Bmaj7", letters = { "B", "D♯", "F♯", "A♯" } },
    { chord = "B#maj7", letters = { "B♯", "D𝄪", "F𝄪", "A𝄪" } },
    { chord = "Eb7b5", letters = { "E♭", "G", "B𝄫", "D♭" } },
    { chord = "D#7b5", letters = { "D♯", "F𝄪", "A", "C♯" } },
    { chord = "Eb9", letters = { "E♭", "G", "B♭", "D♭", "F" } },
    { chord = "G#7(#9)", letters = { "G♯", "B♯", "D♯", "F♯", "A𝄪" } },
    { chord = "Ab7(b9)", letters = { "A♭", "C", "E♭", "G♭", "B𝄫" } },
    { chord = "F#11(#11)", letters = { "F♯", "A♯", "C♯", "E", "G♯", "B♯" } },
    { chord = "Ab13", letters = { "A♭", "C", "E♭", "G♭", "B♭", "D♭", "F" } },
    { chord = "Dmb6", letters = { "D", "F", "A", "B♭" } },
    { chord = "F#m11(b5b9)", letters = { "F♯", "A", "C", "E", "G", "B" } },
    { chord = "A7/G", letters = { "G", "A", "C♯", "E", "G" } },
    { chord = "G/F#", letters = { "F♯", "G", "B", "D" } },
    { chord = "A#6", letters = { "A♯", "C𝄪", "E♯", "F𝄪" } },
    { chord = "Bb6", letters = { "B♭", "D", "F", "G" } },
    { chord = "Am6", letters = { "A", "C", "E", "F♯" } },
    { chord = "D(#6)", letters = { "D", "F♯", "A", "B♯" } },
    { chord = "Eo", letters = { "E", "G", "B♭" } },
    { chord = "Eø", letters = { "E", "G", "B♭", "D" } },
    { chord = "Do", letters = { "D", "F", "A♭" } },
    { chord = "Dø", letters = { "D", "F", "A♭", "C" } },
    { chord = "Fo7", letters = { "F", "A♭", "C♭", "E𝄫" } },
    { chord = "G#ø7", letters = { "G♯", "B", "D", "F♯" } },
    { chord = "Bmin11", letters = { "B", "D", "F♯", "A", "C♯", "E" } },
    { chord = "E5", letters = { "E", "B" } },
    { chord = "A5", letters = { "A", "E" } },
    { chord = "D13#5b9", letters = { "D", "F♯", "A♯", "C", "E♭", "G", "B" } },
    { chord = "Ab6/9", letters = { "A♭", "C", "E♭", "F", "B♭" } },
    { chord = "DM", letters = { "D", "F♯", "A" } },
    { chord = "EM#5", letters = { "E", "G♯", "B♯" } },
    { chord = "FM9", letters = { "F", "A", "C", "E", "G" } },
  }

  test_chords(chords)
end

function test_octave_aware()
  local chords = {
    { chord = "C", letters = { "C4", "E4", "G4" } },
    { chord = "C9", letters = { "C4", "E4", "G4", "B♭4", "D5" } },
    { chord = "C/Bb", letters = { "B♭3", "C4", "E4", "G4" } },
  }

  test_chords(chords, 4)
end

function test_chord_tostring()
  local chords = {
    { chord = "Cø", to_string = "C7b5" },
    { chord = "Ab6/9" },
    { chord = "C6" },
    { chord = "D13#5b9" },
    { chord = "C/Bb" },
    { chord = "CM7" },
    { chord = "CmM7" },
    { chord = "Eaug" },
    { chord = "F5" },
  }

  for _, test in ipairs(chords) do
    local parsed_chord = lib.Chord.fromstring(test.chord)

    luaunit.assertEquals(
      parsed_chord:toascii(),
      test.to_string or test.chord,
      "Mismatched string for chord: " .. test.chord
    )
  end
end

function test_chord_transposition()
  local chords = {
    { "C/Bb", "E/D", "M3" },
    { "C7", "G7", "P12" },
    { "E7", "G7", "m3" },
    { "E7", "Eb7", "d8" },
  }

  for _, test in ipairs(chords) do
    local chord, transposed_chord, interval = unpack(test)
    local parsed_interval = lib.Interval.fromstring(interval)

    local get_transpose_result = function(i) return lib.Chord.fromstring(chord):transpose(i):toascii() end

    local get_transpose_down_result = function(i)
      return lib.Chord.fromstring(transposed_chord):transpose_down(i):toascii()
    end

    luaunit.assertEquals(
      get_transpose_result(parsed_interval),
      get_transpose_result(interval),
      transposed_chord,
      "Mismatched transposition result for chord: " .. chord
    )

    luaunit.assertEquals(
      get_transpose_down_result(parsed_interval),
      get_transpose_down_result(interval),
      chord,
      "Mismatched transpose_down result for chord: " .. chord
    )
  end
end
