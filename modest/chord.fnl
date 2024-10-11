(local {: reduce : map : tomap : totable} (require :fun))

(local {: Note : Interval : is-perfect : semitone-interval
        : accidental-to-string : assoc-octave : transpose-util}
       (require :modest.basics))

(local {: flatten-nested : sort-transformed : safe-prepend
        : conj : apply : copy : mapv : vals : assoc : dissoc}
       (require :modest.utils))

(fn build-triad [{: triad}]
  (case triad
    :min [[3 :min] [5]]
    :maj [[3 :maj] [5]]
    :power [[5]]
    :aug [[3 :maj] [5 :aug]]
    [:sus 2] [[2 :maj] [5]]
    [:sus 4] [[4] [5]]
    (where (or :dim :half-dim)) [[3 :min] [5 :dim]]))

(fn add-7 [{: maj_ext : ext : triad}]
  (when ext
    (if (= ext 6) [6 :maj]
        (= triad :dim) [7 :dim]
        maj_ext [7 :maj]
        [7 :min])))

(fn extend [{: ext}]
  (when (and ext (> ext 7))
    (icollect [_ v (ipairs [9 11 13 15])
               &until (> v ext)]
      [v (when (not (is-perfect v)) :maj)])))

(fn added [{: add}]
  (when add
      (if (is-perfect add)
          [add] [add :maj])))

(fn alterate [intervals {: alterations}]
  (if alterations
      (let [interval-map
            (tomap (map (fn [i] (values (. i :size) i)) intervals))
            alterated-map
            (reduce (fn [acc [alt size]]
                      (let [quality (or (-?> interval-map (. size) (. :quality)) 0)]
                        (assoc acc size
                               (Interval.new size (+ quality alt)))))
                    interval-map
                    alterations)]
        (vals alterated-map))
      intervals))

(fn num-bass [{: root : bass}]
  (when bass
    (- (semitone-interval bass root))))

(fn transpose [v root]
  (let [inter (semitone-interval (Note.new :C) root)]
    (map #(+ inter $) v)))

(fn root [] [1])

(fn bass-with-octave [{: bass : root} octave]
  (if (and octave bass)
      (let [bass-octave (if (>= (Note.pitch_class bass) (Note.pitch_class root))
                            (- octave 1) octave)]
        (assoc-octave bass bass-octave))
      bass))

(fn quality-to-string [{: triad}]
  (case triad
    :min :m
    :power :5
    [:sus step] (.. :sus step)
 ; half-diminished chord is handled as a 7(b5) chord due to the lack of an ascii symbol for it
    (where (or :maj :half-dim)) ""
    _ triad))

(fn ext-to-string [{: maj_ext : ext}]
  (when ext
      (.. (if maj_ext "M" "") ext)))

(fn alterations-to-string [{: alterations : triad} ascii]
  (let [alterations (-> (or alterations [])
                        (copy)
                        (conj (when (= triad :half-dim) [-1 5]))
                        (sort-transformed #(. $ 2)))
        alteration-string (reduce (fn [res [acc size]]
                                    (.. res (accidental-to-string acc ascii) size))
                                  "" alterations)]
    (if (= alteration-string "")
      alteration-string
      (.. "(" alteration-string ")"))))

(fn add-to-string [{: add : ext}]
  (when add
    (.. (if (= ext 6) "/" "") add)))

;; transforms a parsed chord suffix (e.g. mM7, aug, dim7) into a string
(fn suffix-to-string [suffix ascii]
  (let [foos [quality-to-string ext-to-string
              add-to-string #(alterations-to-string $ ascii)]
        strings (mapv #($ suffix) foos)]
    (reduce #(.. $ $2) "" strings)))

(local Chord {})

(fn chord-transpose-util [{: intervals : suffix : bass : root} interval dir]
  (let [chord {: intervals
               : suffix
               :bass (when bass (transpose-util bass interval dir))
               :root (transpose-util root interval dir)}]
    (setmetatable chord {:__index Chord :__tostring Chord.tostring})
    chord))

(fn Chord.numeric [{: root : intervals &as t}]
  (safe-prepend
   (num-bass t)
   (totable
    (transpose (map Interval.semitones intervals) root))))

(fn Chord.notes [{: intervals : root &as t} octave]
  (safe-prepend
   (bass-with-octave t octave)
   (totable
    (map (partial Note.transpose (assoc-octave root octave)) intervals))))

(fn Chord.transpose [self interval]
  (chord-transpose-util self interval 1))

(fn Chord.transpose_down [self interval]
  (chord-transpose-util self interval -1))

(fn Chord.tostring [{: root : bass : suffix} ascii]
  (let [str-func #(Note.tostring $ ascii)]
    (.. (str-func root)
        (suffix-to-string suffix ascii)
        (if bass (.. "/" (str-func bass)) ""))))

(fn Chord.toascii [self] (Chord.tostring self true))

(fn Chord.transform [t]
  (let [foos [root build-triad add-7 extend added]
        intervals (map (partial apply Interval.new)
                       (flatten-nested (mapv #($ t) foos)))
        alterated (sort-transformed (alterate intervals t) Interval.semitones)
        chord {:intervals alterated
               :bass t.bass
               :root t.root
               :suffix (dissoc t :root :bass)}]
    (setmetatable chord {:__index Chord :__tostring Chord.tostring})
    chord))

Chord
