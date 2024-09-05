;; module implements Note and Interval

(macro ensure [cond message]
  `(when (not ,cond) (error ,message)))

(local u (require :modest.utils))
(local
 (contains? find circular-index map slice apply sum car second swap)
 (values u.contains? u.find u.circular-index u.map u.slice u.apply u.sum u.car u.second u.swap))

(local Octave [:C :D :E :F :G :A :B])

(local Tones [2 2 1 2 2 2 1])
(local octave-semitones (apply sum Tones))

(local Perfect-Intervals [1 4 5])
(fn is-perfect [size]
  (contains? Perfect-Intervals (% size 7)))

(local Note {})

(local Interval {})

;; luajit support
(fn floor-/ [a b]
  (math.floor (/ a b)))

(fn accidental-to-semitones [accidental]
  (match accidental
    :flat -1
    :sharp 1
    :double-flat -2
    :double-sharp 2))

;; semitones for perfect and major intervals
(fn base-interval [size]
  (faccumulate [n 0 i 1 (- size 1)]
    (+ n (circular-index Tones i))))

(fn semitone-interval [a b]
  (Interval.semitones (Interval.identify a b)))

(fn semitone-interval-between-tones [tones octave-diff direction]
  (let [[a-tone b-tone] (if (= direction -1) (swap tones) tones)]
    (semitone-interval
     (Note.new a-tone 0 0)
     (Note.new b-tone 0 octave-diff))))

(fn is-valid-interval [size quality]
  (and (or (and (is-perfect size) (not (contains? [:min :maj] quality)))
           (and (not (is-perfect size)) (~= quality :perfect)))
       (not (and (= size 1) (= quality :dim)))))

(local ascii-acc [[:b :bb] [:# :x]])
(local utf8-acc [["♭" "𝄫"] ["♯" "𝄪"]])

(fn accidental-to-string [accidental ascii]
  (let [acc-symbols (if ascii ascii-acc utf8-acc)
        [single double] (if (< accidental 0) (car acc-symbols) (second acc-symbols))]
    (.. 
     (string.rep double (floor-/ (math.abs accidental) 2))
     (if (= 1 (% accidental 2)) single ""))))

(fn find-in-octave [{: tone}]
  (find Octave tone))

(fn assoc-octave [{: tone : accidental} octave]
  (Note.new tone accidental octave))

(fn quality-to-int [size quality]
  (case quality
    :aug 1
    :dim (if (is-perfect size) -1 -2)
    :min -1
    (where (or :maj :perfect)) 0))

(fn notate-quality [{: size : quality}]
  (case quality
    -2 :d
    -1 (if (is-perfect size) :d :m)
    0 (if (is-perfect size) :P :M)
    1 :A))

(fn transpose-util [{: tone : octave : accidental} {: size &as interval} direction]
  (let [target-semitones (Interval.semitones interval)
        octave-pos (+ (find Octave tone) (* direction (- size 1)))
        new-tone (circular-index Octave octave-pos)
        octave-diff (math.abs (floor-/ (- octave-pos 1) (length Octave)))
        new-octave (when octave (+ octave (* direction octave-diff)))
        diff (- target-semitones
                (semitone-interval-between-tones [tone new-tone]
                                                 octave-diff direction))]
    (Note.new new-tone
              (+ accidental (* direction diff))
              new-octave)))

(fn Note.fromtable [t]
  (apply Note.new t))

(fn Note.new [tone acc octave]
  (ensure (= (type tone) :string) "Invalid argument")
  (ensure (contains? [:number :nil] (type acc)) "Invalid argument")
  (ensure (contains? [:number :nil] (type octave)) "Invalid argument")
  (ensure (or (not octave) (>= octave 0))
          (.. "Octave must be a positive number or zero. Octave: " octave))
  (let [r {:tone tone
           :accidental (or acc 0)
           :octave octave}]
    (setmetatable r {:__index Note :__tostring Note.tostring})
    r))

(fn Note.pitch_class [{: tone : accidental}]
  (let [pos (find Octave tone)
        ht (apply sum (slice Tones 1 (- pos 1)))]
    (% (+ accidental ht) octave-semitones)))

(fn Note.transpose [self interval]
  (transpose-util self interval 1))

(fn Note.transpose_down [self interval]
  (transpose-util self interval -1))

(fn Note.tostring [{: tone : accidental : octave} ascii]
  (.. tone
      (accidental-to-string accidental ascii)
      (or octave "")))

(fn Note.toascii [note]
  (Note.tostring note true))

(fn Interval.new [size quality]
  (let [quality
        (case (type quality)
          :number quality
          :string (do (ensure (is-valid-interval size quality) "Invalid combination of size and quality")
                      (quality-to-int size quality))
          :nil (when (is-perfect size) 0))]
    (ensure (not= size nil) "Size of interval is undefined")
    (ensure (not= quality nil) (.. "Interval quality is undefined. Size " size))
    (ensure (> size 0) (.. "Size of interval must be a positive integer. Size " size))
    (local t {: size : quality})
    (setmetatable t {:__index Interval :__tostring Interval.tostring})
    t))

(fn Interval.identify [a-note b-note]
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
                 (+ 1 (length Octave))
                 (+ 1 (% (- b-pos a-pos) (length Octave))))
        interval-ht (% (- b-int a-int) octave-semitones)
        base-ht (base-interval size)]
    (Interval.new
     (+ size (if octaves (* octaves (length Octave)) 0))
     (- interval-ht base-ht))))

(fn Interval.semitones [{: size : quality}]
  (let [base (base-interval size)]
    (+ base quality)))

(fn Interval.fromtable [[quality size]]
  (Interval.new size quality))

(fn Interval.tostring [{: size &as self}]
  (.. (notate-quality self) size))

{: Interval : Note : is-perfect : accidental-to-semitones : semitone-interval : accidental-to-string : assoc-octave : transpose-util
 :base_interval base-interval
 :accidental_to_semitones accidental-to-semitones}
