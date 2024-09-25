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

