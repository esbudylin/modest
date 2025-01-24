;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(local {: Note : Interval : Grammars
        : is-perfect : semitone-interval
        : accidental->string : assoc-octave
        : dissoc-octave : transpose-util}
       (require :modest.basics))

(local {: flatten-nested : sort! : safe-prepend! : parse
        : conj! : apply : copy : vals : assoc! : dissoc!
        : map : reduce : map-into-kv : parse-if-string
        : prepend! : head}
       (require :modest.utils))

(local {: intervals->suffix : into-intervals } (require :modest.identify))

(fn build-triad [{: triad}]
  (case triad
    :min [[3 :min] [5]]
    :maj [[3 :maj] [5]]
    :power [[5]]
    :aug [[3 :maj] [5 :aug]]
    :dim [[3 :min] [5 :dim]]
    [:sus 2] [[2 :maj] [5]]
    [:sus 4] [[4] [5]]))

(fn add-7 [{: seventh : ext}]
  (when ext
    (if (= ext 6) [6 :maj]
        [7 seventh])))

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
            (map-into-kv (fn [i] (values (. i :size) i))
                         intervals)
            alterated-map
            (reduce (fn [acc [alt size]]
                         (let [quality
                               (or (-?> interval-map (. size) (. :quality))
                                   0)]
                           (assoc! acc
                                   size
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

(fn is-half-dim [{: triad : seventh}]
  (and (= triad :dim) (= seventh :min)))

(fn quality->string [{: triad &as chord}]
  (if (is-half-dim chord)
      ;; half-diminished chord is handled as a m7(b5) chord due to the lack of an ascii symbol for it
      :m
      (case triad
        :power :5
        [:sus step] (.. :sus step)
        :min :m
        :maj ""
        _ triad)))

(fn ext->string [{: seventh : ext}]
  (when ext
    (.. (if (= seventh :maj) "M" "") ext)))

(fn alterations->string [{: alterations &as chord} ascii]
  (let [alterations (-> (or alterations [])
                        (copy)
                        (conj! (when (is-half-dim chord) [-1 5]))
                        (sort! #(. $ 2)))
        alteration-string (reduce (fn [res [acc size]]
                                    (.. res (accidental->string acc ascii) size))
                                  "" alterations)]
    (if (= alteration-string "")
      alteration-string
      (.. "(" alteration-string ")"))))

(fn add->string [{: add : ext}]
  (when add
    (.. (if (= ext 6) :/ :add) add)))

;; transforms a parsed chord suffix (e.g. mM7, aug, dim7) into a string
(fn suffix->string [suffix ascii]
  (let [foos [quality->string ext->string
              add->string #(alterations->string $ ascii)]
        strings (map #($ suffix) foos)]
    (reduce #(.. $ (or $2 "")) "" strings)))

(local Chord {})

(fn chord-transpose-util [{: intervals : suffix : bass : root} interval dir]
  (let [chord {: intervals
               : suffix
               :bass (when bass (transpose-util bass interval dir))
               :root (transpose-util root interval dir)}]
    (setmetatable chord Chord.mt)
    chord))

(fn Chord.fromstring [str]
  (let [t (parse Grammars.chord str)
        foos [root build-triad add-7 extend added]
        intervals (map (partial apply Interval.new)
                       (flatten-nested (map #($ t) foos)))
        alterated (sort! (alterate intervals t) Interval.semitones)
        chord {:intervals alterated
               :bass t.bass
               :root t.root
               :suffix (dissoc! t :root :bass)}]
    (setmetatable chord Chord.mt)
    chord))

(fn Chord.identify [& notes]
  (assert (> (length notes) 1) "More than single note is expected")
  (let [notes (map (partial parse-if-string Grammars.note) notes)
        intervals (apply into-intervals notes)
        chord {:suffix (intervals->suffix intervals)
               :intervals (prepend! (Interval.new 1) intervals)
               :root (dissoc-octave (head notes))}]
    (setmetatable chord Chord.mt)
    chord))

(fn Chord.numeric [{: root : intervals &as t}]
  (safe-prepend!
   (num-bass t)
   (transpose (map Interval.semitones intervals) root)))

(fn Chord.notes [{: intervals : root &as t} octave]
  (safe-prepend!
   (bass-with-octave t octave)
   (map (partial Note.transpose (assoc-octave root octave)) intervals)))

(fn Chord.transpose [self interval]
  (chord-transpose-util self interval 1))

(fn Chord.transpose_down [self interval]
  (chord-transpose-util self interval -1))

(fn Chord.tostring [{: root : bass : suffix} ascii]
  (let [str-func #(Note.tostring $ ascii)]
    (.. (str-func root)
        (suffix->string suffix ascii)
        (if bass (.. "/" (str-func bass)) ""))))

(fn Chord.toascii [self] (Chord.tostring self true))

(set Chord.mt {:__index (dissoc! (copy Chord) :fromstring :mt)
               :__tostring Chord.tostring})

Chord
