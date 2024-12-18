;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(local {: assertEquals} (require :luaunit))

(local {: Note} (require :modest))

(import-macros {: parameterized} :test-macros)

(parameterized :note_to_pitchclass
               [[(Note.new :C 0 0) 0]
                [(Note.new :C 0 5) 0]
                [(Note.new :D 1 0) 3]
                [(Note.new :B (- 1) 0) 10]
                [(Note.new :B 1 0) 0]]
               (fn [note integer]
                 (assertEquals (note:pitch_class) integer)))

(parameterized :parse_notes
               [["D♯4" (Note.new :D 1 4)]
                ["E♭3" (Note.new :E -1 3)]
                ["C1" (Note.new :C 0 1)]
                ["G𝄫" (Note.new :G -2)]
                ["B𝄪" (Note.new :B 2)]]
               (fn [str note]
                 (assertEquals (Note.fromstring str) note)))
