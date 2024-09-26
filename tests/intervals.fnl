(local {: assertEquals : assertError} (require :luaunit))

(local {: Note : Interval} (require :modest))

(import-macros {: parameterized} :test-macros)

(fn assert-intervals [note1 note2 interval semitones transposition]
  (local transposition (or transposition note2))
  (local parsed-interval (Interval.fromstring interval))
  (assertEquals (tostring (Interval.identify note1 note2))
                interval
                "Mismatched interval name")
  (assertEquals (Interval.semitones (Interval.identify note1 note2))
                semitones
                "Mismatched semitones")
  (assertEquals (tostring (Interval.identify (note1:toascii) (note2:toascii)))
                interval
                "Can't identify interval by strings")
  (assertEquals (note1:transpose parsed-interval)
                transposition
                "Mismatched transposition result")
  (assertEquals (note1:transpose interval)
                transposition
                "Can't tranpose by string")
  (assertEquals (transposition:transpose_down parsed-interval)
                note1
                "Mismatched result for transpose_down")
  (assertEquals (transposition:transpose_down interval)
                note1
                "Can't transpose down by string"))

(parameterized :across_octave
               [[(Note.new :C 0 0) (Note.new :C 0 1) :P8 12]
                [(Note.new :C 0 0) (Note.new :D 0 1) :M9 14]
                [(Note.new :C 0 0) (Note.new :D 1 1) :A9 15]
                [(Note.new :B 0 0) (Note.new :C 1 1) :M2 2]
                [(Note.new :D 0 0) (Note.new :C 0 1) :m7 10]
                [(Note.new :C 0 0) (Note.new :C 0 2) :P15 24]
                [(Note.new :C 0 0) (Note.new :D 0 2) :M16 26]
                [(Note.new :D 0 0) (Note.new :C 0 2) :m14 22]
                [(Note.new :B 0 0) (Note.new :C 1 2) :M9 14]
                [(Note.new :C 0 4) (Note.new :C 1 5) :A8 13]
                [(Note.new :C 0 4) (Note.new :C (- 1) 5) :d8 11]
                [(Note.new :C 0 4) (Note.new :C (- 1) 6) :d15 23]]
               assert-intervals)

(parameterized :octave_unaware
               [[(Note.new :C 0 nil) (Note.new :C 0 nil) :P1 0]
                [(Note.new :C 0 nil) (Note.new :D 0 nil) :M2 2]
                [(Note.new :B (- 1) nil) (Note.new :C 0 nil) :M2 2]
                [(Note.new :D 0 nil) (Note.new :C 0 nil) :m7 10]
                [(Note.new :C 0 nil) (Note.new :E (- 1) nil) :m3 3]
                [(Note.new :C 0 nil) (Note.new :C (- 1) nil) :d8 11]
                [(Note.new :D 0 nil) (Note.new :C 0 4) :m7 10 (Note.new :C 0 nil)]
                [(Note.new :D 0 4) (Note.new :C 0 nil) :m7 10 (Note.new :C 0 5)]]
               assert-intervals)

(parameterized :unison
               [[(Note.new :C 0 0) (Note.new :C 0 0) :P1 0]
                [(Note.new :D 1 0) (Note.new :D 1 0) :P1 0]
                [(Note.new :B 1 0) (Note.new :C 0 1) :d2 0]]
               assert-intervals)

(parameterized :interval_to_semitones
               [[:A4 6]
                [:A7 12]
                [:M10 16]
                [:M3 4]
                [:P11 17]
                [:P4 5]
                [:d2 0]
                [:d3 2]]
               (fn [interval semitones]
                 (assertEquals (: (Interval.fromstring interval) :semitones) semitones
                               (.. "Mismatched semitones amount for interval " interval))))

(parameterized :invalid_intervals
               [[:d1] [:M5] [:P3]]
               (partial assertError Interval.fromstring))
