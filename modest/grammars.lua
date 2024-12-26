--[[
   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.
]]

local re = require "modest.re"
local lpeg = require "lpeg"

-- transforming functions are passed as arguments to avoid circular dependency
local function grammars(tonote, tointerval, tosemitones)
  local transformers = {
    tonote = tonote,
    tointerval = tointerval,
    tosemitones = tosemitones,
    tonumber = tonumber,
    tozero = function() return 0 end,
    totrue = function() return true end,
  }

  local common = [[
    tone <- { [A-G] }
    accidental <- (flat / sharp / double_flat / double_sharp) -> tosemitones
    
    flat <- ( 'b' / utf'0x266D' ) -> 'flat'
    sharp <- ( '#' / utf'0x266F' ) -> 'sharp'

    double_flat <- ( 'bb' / utf'0x1D12B' ) -> 'double_flat'
    double_sharp <- ( 'x' / utf'0x1D12A' ) -> 'double_sharp'
    ]]

  local chord = re.compile([[
    chord <- {| root (power_chord / alt_chord / sus_chord / base_chord) |}

    base_chord <- quality? extended? add? chord_tail
    power_chord <- power bass_note?
    alt_chord <- (diminished / half_diminished / aug) extended_seventh? chord_tail
    sus_chord <- sus_ext? {:triad: sus :} chord_tail

    chord_tail <- alterations? bass_note?

    root <- {:root: note :}
    note <- {| tone accidental? |} -> tonote

    quality <- min_maj_quality /
               {:triad: maj :} maj_ext_capture &seventh / -- maj can notate major 7
               {:triad: maj / min / '' -> "maj" :}

    maj <- ('maj' / 'ma' / 'Maj' / 'M' / triangle) -> "maj"
    triangle <- utf'0x25B3' / utf'0x0394' / utf'0x2206'
    min <- ('min' / 'mi' / 'm' / '-') -> "min"

    min_maj_quality <- {:triad: min_maj :} maj_ext_capture
    maj_ext_capture <- {:maj_ext: "" -> totrue:}
    
    min_maj <- min maj_extension
    maj_extension <- (maj / '(' maj ')' / '/' maj) &seventh

    maj_7 <- maj maj_ext_capture
    sus_ext <- maj_7? extended_seventh

    power <- {:triad: '5' -> "power" :}

    diminished <- {:triad: ('dim' / 'o') -> "dim":} 

    -- half-diminished chord is a seventh chord even if 7 isn't notated
    half_diminished <- {:triad: crossed_o -> "half-dim":} (&seventh / {:ext: "7" -> tonumber :})

    crossed_o <- utf'0x00F8'
    aug <- {:triad: ('+' / 'aug') -> "aug" :} (maj_7 &extended_seventh)?

    sixth <- {:ext: "6" -> tonumber :}
    seventh <- ('7' / '9' / '11' / '13' / '15') -> tonumber

    extended_seventh <- {:ext: seventh :}

    extended_sixth <- sixth (sixth_add9 !add)?
    sixth_add9 <- "/" {:add: "9" -> tonumber :} -- matches 6/9 chords

    extended <- extended_seventh / extended_sixth

    sus <- {| { 'sus' } ('2' / '4' / '' -> '4') -> tonumber |}

    add_interval <- ('2' / '4' / '9' / '11' / '13') -> tonumber
    add <- 'add' {:add: add_interval:}

    alteration_interval <- ('4' / '5' / '6' / '9' / '11' / '13') -> tonumber
    alteration <- {| accidental alteration_interval |}
    alterations <- "("? {:alterations: {| alteration+ |} :} ")"?

    bass_note <- '/' {:bass: note :}
    ]] .. common, transformers)

  local note = re.compile([[
    note <- {| tone (accidental / ('' -> tozero)) octave? |} -> tonote
    octave <- [0-9] -> tonumber
    ]] .. common, transformers)

  local interval = re.compile(
    [[
    interval <- {| quality steps |} -> tointerval
    quality <- 'M' -> "maj" /
               'm' -> "min" /
               'A' -> "aug" /
               'd' -> "dim" /
               'P' -> "perfect"
    steps <- ([1-9] [0-9]*) -> tonumber
    ]],
    transformers
  )

  return {
    chord = chord * -lpeg.P(1), -- ensures that the entire input string matches
    interval = interval * -lpeg.P(1),
    note = note * -lpeg.P(1),
  }
end

return grammars
