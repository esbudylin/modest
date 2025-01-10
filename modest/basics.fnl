;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; module implements Note and Interval

(macro ensure [cond message]
  `(when (not ,cond) (error ,message)))

;; macro for checking if an element exists in a table known at compile-time 
(macro contains-at-compile? [tbl el]
  (let [unpack (or table.unpack _G.unpack)]
    `(let [el# ,el]
       (or ,(unpack (icollect [_ i (ipairs tbl)]
                      `(= ,i el#)))))))

(local
 {: circular-index : slice : second : swap
  : apply : map : dec : sum
  : parse : parse-if-string : dissoc! : copy
  : head }
 (require :modest.utils))

(local Notes [:C :D :E :F :G :A :B])

;; an associative table to look up the position of a note within the octave
(local Octave (collect [i n (ipairs Notes)] (values n i)))
(local octave-steps (length Notes))

(local Tones [2 2 1 2 2 2 1])
(local octave-semitones (apply sum Tones))

(fn is-perfect [size]
  (contains-at-compile? [1 4 5] (% size 7)))

;; luajit support
(fn floor-/ [a b]
  (math.floor (/ a b)))

;; semitones for perfect and major intervals
(fn base-interval [size]
  (faccumulate [n 0 i 1 (dec size)]
    (+ n (circular-index Tones i))))

(local Note {})

(local Interval {})

(fn note-fromtable [t]
  (apply Note.new t))

(fn interval-fromtable [[quality size]]
  (Interval.new size quality))

(fn accidental->semitones [accidental]
  (case accidental
    :flat -1
    :sharp 1
    :double-flat -2
    :double-sharp 2))

(local Grammars ((require :modest.grammars)
               note-fromtable interval-fromtable accidental->semitones))

(fn semitone-interval [a b]
  (Interval.semitones (Interval.identify a b)))

(fn semitone-interval-between-tones [tones octave-diff direction]
  (let [[a-tone b-tone] (if (= direction -1) (swap tones) tones)]
    (semitone-interval
     (Note.new a-tone 0 0)
     (Note.new b-tone 0 octave-diff))))

(fn is-valid-interval [size quality]
  (if (is-perfect size)
      (not (or (contains-at-compile? [:min :maj] quality)
               (and (= size 1) (= quality :dim))))
      (not= quality :perfect)))

(local ascii-acc [[:b :bb] [:# :x]])
(local utf8-acc [["♭" "𝄫"] ["♯" "𝄪"]])

(fn accidental->string [accidental ascii]
  (let [acc-symbols (if ascii ascii-acc utf8-acc)
        [single double] (if (< accidental 0)
                            (head acc-symbols)
                            (second acc-symbols))]
    (.. 
     (string.rep double (floor-/ (math.abs accidental) 2))
     (if (= 1 (% accidental 2)) single ""))))

(fn find-in-octave [{: tone}]
  (. Octave tone))

(fn dissoc-octave [{: tone : accidental}]
  (Note.new tone accidental))

(fn assoc-octave [{: tone : accidental} octave]
  (Note.new tone accidental octave))

(fn quality->int [size quality]
  (case quality
    :aug 1
    :dim (if (is-perfect size) -1 -2)
    :min -1
    (where (or :maj :perfect)) 0))

(fn quality->string [{: size : quality}]
  (case quality
    -2 :dim
    -1 (if (is-perfect size) :dim :min)
    0 (if (is-perfect size) :perfect :maj)
    1 :aug)) 

(fn notate-quality [interval]
  (case (quality->string interval)
    :dim :d
    :min :m
    :maj :M
    :aug :A
    :perfect :P))

(fn transpose-util* [{: tone : octave : accidental} {: size &as interval} direction]
  (let [target-semitones (Interval.semitones interval)
        octave-pos (+ (. Octave tone) (* direction (dec size)))
        new-tone (circular-index Notes octave-pos)
        octave-diff (math.abs (floor-/ (dec octave-pos) octave-steps))
        new-octave (when octave (+ octave (* direction octave-diff)))
        diff (- target-semitones
                (semitone-interval-between-tones [tone new-tone]
                                                 octave-diff direction))]
    (Note.new new-tone
          (+ accidental (* direction diff))
          new-octave)))

(fn transpose-util [self interval direction]
  (transpose-util* self
   (parse-if-string Grammars.interval interval)
   direction))

(fn Note.new [tone acc octave]
  (ensure (= (type tone) :string) "Invalid argument")
  (ensure (contains-at-compile? [:number :nil] (type acc)) "Invalid argument")
  (ensure (contains-at-compile? [:number :nil] (type octave)) "Invalid argument")
  (ensure (or (not octave) (>= octave 0))
          (.. "Octave must be a positive number or zero. Octave: " octave))
  (let [r {:tone tone
           :accidental (or acc 0)
           :octave octave}]
    (setmetatable r Note.mt)
    r))

(fn Note.pitch_class [{: tone : accidental}]
  (let [pos (. Octave tone)
        ht (if (= pos 1)
               0
               (apply sum (slice Tones 1 (dec pos))))]
    (% (+ accidental ht) octave-semitones)))

(fn Note.transpose [self interval]
  (transpose-util self interval 1))

(fn Note.transpose_down [self interval]
  (transpose-util self interval -1))

(fn Note.tostring [{: tone : accidental : octave} ascii]
  (.. tone
      (accidental->string accidental ascii)
      (or octave "")))

(fn Note.toascii [note]
  (Note.tostring note true))

(λ Interval.new [size ?quality]
  (let [quality
        (case (type ?quality)
          :number ?quality
          :string (do (ensure (is-valid-interval size ?quality) "Invalid combination of size and quality")
                      (quality->int size ?quality))
          :nil (do (ensure (is-perfect size) "Interval quality is undefined")
                   0)
          _ (error (.. "Invalid argument for quality " ?quality)))]
    (ensure (> size 0) (.. "Size of interval must be a positive integer. Size " size))
    (local t {: size : quality})
    (setmetatable t Interval.mt)
    t))

(fn identify-interval [a-note b-note]
  (let [[a-pos b-pos] (map find-in-octave [a-note b-note])
        [a-int b-int] (map Note.pitch_class [a-note b-note])
        diminished-octave (and (= a-pos b-pos)
                               (> a-note.accidental b-note.accidental)) ;; e.g. a-note - C; b-note - Cb
        octave-offset (if (or diminished-octave (> a-pos b-pos)) 1 0)
        octaves (when (and b-note.octave a-note.octave)
                  (- b-note.octave
                     a-note.octave
                     octave-offset))
        size (if diminished-octave
                 (+ 1 octave-steps)
                 (+ 1 (% (- b-pos a-pos) octave-steps)))
        interval-ht (% (- b-int a-int) octave-semitones)
        base-ht (base-interval size)]
    (Interval.new
     (+ size (if octaves (* octaves octave-steps) 0))
     (- interval-ht base-ht))))

;; unlike identify-interval, this method can accept strings as arguments
(fn Interval.identify [& args]
  (apply identify-interval
         (map
          (partial parse-if-string Grammars.note)
          args)))

(fn Interval.semitones [{: size : quality}]
  (let [base (base-interval size)]
    (+ base quality)))

(fn Interval.tostring [{: size &as self}]
  (.. (notate-quality self) size))

(fn Note.fromstring [str]
  (parse Grammars.note str)) 

(fn Interval.fromstring [str]
  (parse Grammars.interval str))

(set Note.mt {:__index (dissoc! (copy Note)
                                :new :fromstring :mt)
              :__tostring Note.tostring})

(set Interval.mt {:__index (dissoc! (copy Interval)
                                    :new :identify :fromstring :mt)
                  :__tostring Interval.tostring})

{: Interval : Note : Grammars
 : is-perfect : semitone-interval : accidental->string : quality->string
 : assoc-octave : dissoc-octave : transpose-util }
