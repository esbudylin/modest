(local {: assertEquals} (require :luaunit))

(local {: Chord : Interval} (require :modest))
(local {: map} (require :modest.utils))

(import-macros {: parameterized} :test-macros)

;; This file includes test cases adapted from the test suites of teoria, sharp11 and mingus libraries.
;; https://github.com/jsrmath/sharp11/blob/master/test/chord.test.js
;; https://github.com/saebekassebil/teoria/blob/master/test/chords.js
;; https://github.com/bspaans/python-mingus/blob/master/tests/unit/core/test_chords.py

(fn test-notes [chord notes octave]
  (assertEquals (map tostring
                     (-> chord Chord.fromstring (Chord.notes octave)))
                notes
                (.. "Mismatched notes for chord: " chord)))

(parameterized :symbol_aliases
               [["C∆7" [:C :E :G :B]]
                [:Cmin [:C "E♭" :G]]
                ["CminMaj9#11" [:C "E♭" :G :B :D "F♯"]]
                ["Cmin(maj)7" [:C "E♭" :G :B]]
                [:Co [:C "E♭" "G♭"]]] test-notes)

(parameterized :mingus_testcases
               [[:Amin [:A :C :E]]
                [:Am [:A :C :E]]
                [:A- [:A :C :E]]
                [:Amaj [:A "C♯" :E]]
                [:AM [:A "C♯" :E]]
                [:A [:A "C♯" :E]]
                [:Adim [:A :C "E♭"]]
                [:Aaug [:A "C♯" "E♯"]]
                [:A+ [:A "C♯" "E♯"]]
                ["A7#5" [:A "C♯" "E♯" :G]]
                [:Aaug7 [:A "C♯" "E♯" :G]]
                [:Amin7 [:A :C :E :G]]
                [:Am7 [:A :C :E :G]]
                [:Ami7 [:A :C :E :G]]
                [:A-7 [:A :C :E :G]]
                [:Amaj7 [:A "C♯" :E "G♯"]]
                [:AM7 [:A "C♯" :E "G♯"]]
                [:Ama7 [:A "C♯" :E "G♯"]]
                [:A7 [:A "C♯" :E :G]]
                [:Amin7b5 [:A :C "E♭" :G]]
                [:Am7b5 [:A :C "E♭" :G]]
                [:Adim7 [:A :C "E♭" "G♭"]]
                [:Am/M7 [:A :C :E "G♯"]]
                [:Am/ma7 [:A :C :E "G♯"]]
                [:AmM7 [:A :C :E "G♯"]]
                [:Am/maj7 [:A :C :E "G♯"]]
                [:Amin6 [:A :C :E "F♯"]]
                [:Am6 [:A :C :E "F♯"]]
                [:Amaj6 [:A "C♯" :E "F♯"]]
                [:A6 [:A "C♯" :E "F♯"]]
                [:A6/9 [:A "C♯" :E "F♯" :B]]
                [:A/G [:G :A "C♯" :E]]
                [:Amin/G [:G :A :C :E]]
                [:Am/M7/G [:G :A :C :E "G♯"]]
                [:Asus2 [:A :B :E]]
                [:Asus4 [:A :D :E]]
                [:A7sus4 [:A :D :E :G]]
                [:Asus [:A :D :E]]
                [:Asus4b9 [:A :D :E "B♭"]]
                [:Asusb9 [:A :D :E "B♭"]]
                [:Amaj9 [:A "C♯" :E "G♯" :B]]
                [:A9 [:A "C♯" :E :G :B]]
                [:Amin9 [:A :C :E :G :B]]
                [:Am9 [:A :C :E :G :B]]
                ["A7#11" [:A "C♯" :E :G "D♯"]]
                [:A7b9 [:A "C♯" :E :G "B♭"]]
                ["A7#9" [:A "C♯" :E :G "B♯"]]
                [:A7b5 [:A "C♯" "E♭" :G]]] test-notes)

(parameterized :basic_chords
               [[:C [:C :E :G]]
                [:Cm [:C "E♭" :G]]
                [:C6 [:C :E :G :A]]
                [:C7 [:C :E :G "B♭"]]
                [:C9 [:C :E :G "B♭" :D]]
                [:Cm7 [:C "E♭" :G "B♭"]]
                [:CM7 [:C :E :G :B]]
                [:CM9 [:C :E :G :B :D]]
                [:CmM7 [:C "E♭" :G :B]]
                [:C+ [:C :E "G♯"]]
                [:C+7 [:C :E "G♯" "B♭"]]
                [:C+M7 [:C :E "G♯" :B]]
                [:Cdim [:C "E♭" "G♭"]]
                [:Cdim7 [:C "E♭" "G♭" "B𝄫"]]
                ["Cø" [:C "E♭" "G♭" "B♭"]]
                ["Cø7" [:C "E♭" "G♭" "B♭"]]
                [:Csus4 [:C :F :G]]
                [:Csus2 [:C :D :G]]
                [:C6/9 [:C :E :G :A :D]]
                [:Cm6/9 [:C "E♭" :G :A :D]]
                [:C/Bb ["B♭" :C :E :G]]]
               test-notes)

(parameterized :chords_with_alterations
               [[:Cm7b5 [:C "E♭" "G♭" "B♭"]]
                [:C7b9 [:C :E :G "B♭" "D♭"]]
                ["C7♯9" [:C :E :G "B♭" "D♯"]]
                ["C7♯11" [:C :E :G "B♭" "F♯"]]
                ["C13♯11" [:C :E :G "B♭" :D "F♯" :A]]
                ["C13#9b5" [:C :E "G♭" "B♭" "D♯" :F :A]]]
               test-notes)

(parameterized :add_chords
               [[:Cadd9 [:C :E :G :D]]
                [:Cadd11 [:C :E :G :F]]
                [:Cadd13 [:C :E :G :A]]
                [:C7add9 [:C :E :G "B♭" :D]]
                [:C7add11 [:C :E :G "B♭" :F]]
                [:C7add13 [:C :E :G "B♭" :A]]
                [:C9add11 [:C :E :G "B♭" :D :F]]
                [:C9add13 [:C :E :G "B♭" :D :A]]
                [:C11add13 [:C :E :G "B♭" :D :F :A]]]
               test-notes)

(parameterized :chords_not_in_c
               [[:Emaj7 [:E "G♯" :B "D♯"]]
                [:A+ [:A "C♯" "E♯"]]
                [:Bb+ ["B♭" :D "F♯"]]
                ["F#maj7" ["F♯" "A♯" "C♯" "E♯"]]
                [:Bmaj7 [:B "D♯" "F♯" "A♯"]]
                ["B#maj7" ["B♯" "D𝄪" "F𝄪" "A𝄪"]]
                [:Eb7b5 ["E♭" :G "B𝄫" "D♭"]]
                ["D#7b5" ["D♯" "F𝄪" :A "C♯"]]
                [:Eb9 ["E♭" :G "B♭" "D♭" :F]]
                ["G#7(#9)" ["G♯" "B♯" "D♯" "F♯" "A𝄪"]]
                ["Ab7(b9)" ["A♭" :C "E♭" "G♭" "B𝄫"]]
                ["F#11(#11)" ["F♯" "A♯" "C♯" :E "G♯" "B♯"]]
                [:Ab13 ["A♭" :C "E♭" "G♭" "B♭" "D♭" :F]]
                [:Dmb6 [:D :F :A "B♭"]]
                ["F#m11(b5b9)" ["F♯" :A :C :E :G :B]]
                [:A7/G [:G :A "C♯" :E :G]]
                ["G/F#" ["F♯" :G :B :D]]
                ["A#6" ["A♯" "C𝄪" "E♯" "F𝄪"]]
                [:Bb6 ["B♭" :D :F :G]]
                [:Am6 [:A :C :E "F♯"]]
                ["D(#6)" [:D "F♯" :A "B♯"]]
                [:Eo [:E :G "B♭"]]
                ["Eø" [:E :G "B♭" :D]]
                [:Do [:D :F "A♭"]]
                ["Dø" [:D :F "A♭" :C]]
                [:Fo7 [:F "A♭" "C♭" "E𝄫"]]
                ["G#ø7" ["G♯" :B :D "F♯"]]
                [:Bmin11 [:B :D "F♯" :A "C♯" :E]]
                [:E5 [:E :B]]
                [:A5 [:A :E]]
                ["D13#5b9" [:D "F♯" "A♯" :C "E♭" :G :B]]
                [:Ab6/9 ["A♭" :C "E♭" :F "B♭"]]
                [:DM [:D "F♯" :A]]
                ["EM#5" [:E "G♯" "B♯"]]
                [:FM9 [:F :A :C :E :G]]] test-notes)

(parameterized :octave_aware
               [[:C [:C4 :E4 :G4] 4]
                [:C9 [:C4 :E4 :G4 "B♭4" :D5] 4]
                [:C/Bb ["B♭3" :C4 :E4 :G4] 4]] test-notes)

(parameterized
 :numeric [[:C [0 4 7]]
           [:Cm [0 3 7]]
           [:C6 [0 4 7 9]]
           [:C7 [0 4 7 10]]
           [:Emaj7 [4 8 11 15]]
           [:A+ [9 13 17]]
           [:Bb+ [10 14 18]]
           [:C/Bb [(- 2) 0 4 7]]
           [:Cdim [0 3 6]]
           [:Cdim7 [0 3 6 9]]]
 (fn [chord numeric]
   (assertEquals (-> chord Chord.fromstring Chord.numeric) numeric
                 (.. "Mismatched numeric notation for chord: " chord))))

(parameterized
 :tostring [["Cø" "C7(b5)"]
            [:Ab6/9]
            [:C6]
            ["D13#5b9" "D13(#5b9)"]
            [:C/Bb]
            [:CM7]
            [:CmM7]
            [:Eaug]
            [:F5]
            ["F(#11)"]]
 (fn [chord to_string]
   (let [parsed-chord (Chord.fromstring chord)]
     (assertEquals (parsed-chord:toascii)
                   (or to_string chord)
                   (.. "Mismatched string for chord: " chord)))))

(parameterized
 :transposition [[:C/Bb :E/D :M3]
                 [:C7 :G7 :P12]
                 [:E7 :G7 :m3]
                 [:E7 :Eb7 :d8]]
 (fn [chord transposed interval]
   (local parsed-interval (Interval.fromstring interval))

   (fn get-transpose-result [i]
     (-> chord Chord.fromstring (Chord.transpose i) Chord.toascii))

   (fn get-transpose-down-result [i]
     (-> transposed Chord.fromstring (Chord.transpose_down i) Chord.toascii))

   (assertEquals (get-transpose-result parsed-interval)
                 (get-transpose-result interval)
                 transposed
                 (.. "Mismatched transposition result for chord: "
                     chord))
   (assertEquals (get-transpose-down-result parsed-interval)
                 (get-transpose-down-result interval)
                 chord
                 (.. "Mismatched transpose_down result for chord: "
                     chord))))
