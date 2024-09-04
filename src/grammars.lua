local lp = require "lpeg"
local b = require "src.basics"

local S, R, P, V, C, Ct, Cc, Cg, utfR = lp.S, lp.R, lp.P, lp.V, lp.C, lp.Ct, lp.Cc, lp.Cg, lp.utfR
local Note, Interval, accidental_to_semitones = b.Note, b.Interval, b.accidental_to_semitones

local chord = {
   "chord",
   chord =
       Ct(V "root" *
          (V "power_chord" + V "alt_chord" + V "sus_chord" + V "base_chord")),

   base_chord = V "quality" ^ -1 * V "extended" ^ -1 * V "add" ^ -1 * V "chord_tail",
   power_chord = V "power" * V "bass_note" ^ -1,
   alt_chord = (V "diminished" + V "half_diminished" + V "aug") * V "extended_seventh" ^ -1 * V "chord_tail",
   sus_chord = V "sus_ext" ^ -1 * Cg(V "sus", "triad") * V "chord_tail",

   chord_tail = V "alterations" ^ -1 * V "bass_note" ^ -1,

   root = Cg(V "note", "root"),
   tone = R "AG",
   note = Ct(C(V "tone") * V "accidental" ^ -1) / Note.fromtable,
   accidental = (Cc "flat" * V "flat" + Cc "sharp" * V "sharp"
      + Cc "double-flat" * V "double_flat" + Cc "double-sharp" * V "double_sharp") / accidental_to_semitones,

   -- in utfR unicode symbols for this characters are presented
   flat = P "b" + utfR(0x266D, 0x266D),
   sharp = P "#" + utfR(0x266F, 0x266F),
   double_flat = P "bb" + utfR(0x1D12B, 0x1D12B),
   double_sharp = P "x" + utfR(0x1D12A, 0x1D12A),

   quality = V "min_maj_quality"
       + Cg(V "maj", "triad") * V "maj_ext_capture" * #V "seventh" -- maj can notate major 7
       + Cg(V "maj" + V "min" + Cc "maj", "triad"),

   maj = Cc "maj" * (P "maj" + P "ma" + P "Maj" + P "M" + V "triangle"),
   triangle = utfR(0x25B3, 0x25B3) + utfR(0x0394, 0x0394) + utfR(0x2206, 0x2206),
   min = Cc "min" * (P "min" + P "mi" + S "m-"),

   -- the next three patterns are used for matching minor/major chords, e.g. min(Maj)7, minMaj9, min/maj11
   min_maj_quality = Cg(V "min_maj", "triad") * V "maj_ext_capture",
   maj_ext_capture = Cg(C "" / function() return true end, "maj_ext"),

   min_maj = V "min" * V "maj_extension",
   maj_extension = (V "maj" + S "(" * V "maj" * S ")" + S "/" * V "maj") * #V "seventh",

   maj_7 = V "maj" / function() return nil end * V "maj_ext_capture",
   sus_ext = V "maj_7" ^ -1 * V "extended_seventh",

   power = Cg(Cc "power", "triad") * S "5",

   diminished = Cg(Cc "dim", "triad") * (P "dim" + S "o"),
   -- half-diminished chord is a seventh chord even if 7 isn't notated
   half_diminished = Cg(Cc "half-dim", "triad") * V "crossed_o" * (#V "seventh" + Cg(Cc "7" / tonumber, "ext")),
   crossed_o = utfR(0x00F8, 0x00F8),
   aug = Cg(Cc "aug", "triad") * (P "+" + P "aug") * (V "maj_7" * #V "extended_seventh") ^ -1,

   sixth =  Cg(S "6" / tonumber, "ext"),
   seventh = (S "79" + P "11" + P "13" + P "15") / tonumber,

   extended_seventh = Cg(V "seventh", "ext"),

   extended_sixth = V "sixth" * (V "sixth_add9" * - #V "add") ^ -1,
   sixth_add9 = Cg("/" * (S "9" / tonumber), "add"), -- matches 6/9 chords

   extended = V "extended_seventh" + V "extended_sixth",

   sus = Ct(C "sus" * ((S "24" + Cc "4") / tonumber)),

   add_interval = (S "249" + P "11" + P "13") / tonumber,
   add = P "add" * Cg(V "add_interval", "add"),

   alteration_interval = (S "4569" + P "11" + P "13") / tonumber,
   alteration = Ct(V "accidental" * V "alteration_interval"),
   alterations = Cg(Ct(S "(" ^ -1 * V "alteration" ^ 1 * S ")" ^ -1), "alterations"),

   bass_note = Cg(S "/" * V "note", "bass"),
}

local note = {
   "note",

   tone = chord.tone,
   accidental = chord.accidental,
   flat = chord.flat,
   sharp = chord.sharp,
   double_flat = chord.double_flat,
   double_sharp = chord.double_sharp,

   octave = R "09" / tonumber,
   note = Ct(C(V "tone") * (V "accidental" + Cc "0" / tonumber) * V "octave" ^ -1) / Note.fromtable,
}

local interval = {
   "interval",
   interval = Ct(Cg(V "quality") * Cg(V "steps")) / Interval.fromtable,
   quality = S "M" * Cc "maj" + S "m" * Cc "min" + P "A" * Cc "aug" + P "d" * Cc "dim" + P "P" * Cc "perfect",
   steps = (R "19" * R "09" ^ 0) / tonumber,
}

return {
   chord = P(chord) * -P(1), -- ensures that the entire input string matches
   note = P(note) * -P(1),
   interval = P(interval) * -P(1)
}
