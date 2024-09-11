(local b (require :modest.basics))
(local (Note Interval is-perfect semitone-interval accidental-to-string assoc-octave transpose-util)
       (values b.Note b.Interval b.is-perfect b.semitone-interval b.accidental-to-string b.assoc-octave b.transpose-util))

(local u (require :modest.utils))
(local
 (map flatten-nested sort apply safe-cons index-by vals remove-keys copy conj)
 (values u.map u.flatten-nested u.sort u.apply u.safe-cons u.index-by u.vals u.remove-keys u.copy u.conj))

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
      (let [alt-map (collect [_ [acc interval-size] (ipairs alterations)]
                      (values interval-size acc))
            interval-map (index-by intervals #(. $1 :size))]
        (each [size alt (pairs alt-map)]
          (let [{: quality} (or (. interval-map size) {})]
            (tset interval-map size (Interval.new size (+ (or quality 0) alt)))))
        (vals interval-map))
      intervals))

(fn num-bass [{: root : bass}]
  (when bass
    (- (semitone-interval bass root))))

(fn transpose [v root]
  (let [inter (semitone-interval (Note.new :C) root)]
    (map #(+ inter $1) v)))

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
                        (sort #(. $1 2)))
        alteration-string (accumulate [res ""
                                       _ [acc interval-size] (ipairs alterations)]
                            (.. res (accidental-to-string acc ascii) interval-size))]
    (if (= alteration-string "")
      alteration-string
      (.. "(" alteration-string ")"))))

(fn add-to-string [{: add : ext}]
  (when add
    (.. (if (= ext 6) "/" "") add)))

;; transforms a parsed chord suffix (e.g. mM7, aug, dim7) into a string
(fn suffix-to-string [suffix ascii]
  (let [foos [quality-to-string ext-to-string
              add-to-string #(alterations-to-string $1 ascii)]
        strings (map #($1 suffix) foos)]
    (accumulate [res "" _ s (ipairs strings)]
      (.. res s))))

(local Chord {})

(fn chord-transpose-util [{: intervals : suffix : bass : root} interval dir]
  (let [chord {: intervals
               : suffix
               :bass (when bass (transpose-util bass interval dir))
               :root (transpose-util root interval dir)}]
    (setmetatable chord {:__index Chord :__tostring Chord.tostring})
    chord))

(fn Chord.numeric [{: root : intervals &as t}]
  (safe-cons (num-bass t)
             (transpose (map Interval.semitones intervals) root)))

(fn Chord.notes [{: intervals : root &as t} octave]
  (safe-cons (bass-with-octave t octave)
             (map (partial Note.transpose (assoc-octave root octave)) intervals)))

(fn Chord.transpose [self interval]
  (chord-transpose-util self interval 1))

(fn Chord.transpose_down [self interval]
  (chord-transpose-util self interval -1))

(fn Chord.tostring [{: root : bass : suffix} ascii]
  (local str-func #(Note.tostring $1 ascii))
  (.. (str-func root)
      (suffix-to-string suffix ascii)
      (if bass (.. "/" (str-func bass)) "")))

(fn Chord.toascii [self] (Chord.tostring self true))

(fn Chord.transform [t]
  (let [foos [root build-triad add-7 extend added]
        intervals (map (partial apply Interval.new)
                       (flatten-nested (map #($1 t) foos)))
        alterated (sort (alterate intervals t) Interval.semitones)
        chord {:intervals alterated
               :bass t.bass
               :root t.root
               :suffix (remove-keys t :root :bass)}]
    (setmetatable chord {:__index Chord :__tostring Chord.tostring})
    chord))

Chord
