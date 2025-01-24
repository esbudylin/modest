(local {: quality->string : Interval } (require :modest.basics))

(local {: map : head : empty?} (require :modest.utils))

(local unpack (or table.unpack _G.unpack))

(fn includes-sequence [t seq discovered]
  (each [i e (ipairs t) &until (empty? seq)]
    (when (= e (head seq))
      (set (. discovered i) true)
      (table.remove seq 1)))
  (empty? seq))

(fn undiscovered [{: seq : discovered}]
  (collect [i e (ipairs seq)]
    (when (not (. discovered i))
      (values i e))))

(macro table-set [& seq]
  (collect [_ e (ipairs seq)]
    (values e true)))

(macro interval-cond [interval-obj & rest]
  (let [cases (icollect [i e (ipairs rest)]
                (if (= (% i 2) 1)
                    `(includes-sequence
                      (. ,interval-obj :str-seq)
                      ,e
                      (. ,interval-obj :discovered))
                    e))]
    `(if ,(unpack cases))))

(fn is-power [{: str-seq}]
  (let [[first & rest] str-seq]
    (and (= first :P5)
         (= (length rest) 0))))

(fn identify-triad [interval-obj]
  (interval-cond interval-obj
                 [:m3 :P5] :min
                 [:M3 :P5] :maj
                 [:M3 :A5] :aug
                 [:M2 :P5] [:sus 2]
                 [:P4 :P5] [:sus 4]
                 [:m3 :d5] :dim))

(fn identify-ext [interval-obj]
  (interval-cond interval-obj
                 [:m7 :M9 :P11 :M13] 13
                 [:m7 :M9 :P11] 11
                 [:m7 :M9] 9
                 [:m7] 7
                 [:M7] 7
                 [:d7] 7
                 [:M6] 6))

(fn identify-add [{: discovered &as interval-obj}]
  (let [add-intervals (table-set 2 4 9 11 13)]
    (var res nil)
    (each [i interval (pairs (undiscovered interval-obj)) &until res]
      (when (and (. add-intervals interval.size)
               (= interval.quality 0))
          (do (set (. discovered i) true)
              (set res interval.size))))
    res))

(fn intervals->suffix [intervals]
  (let [interval-obj {:seq intervals
                      :str-seq (map tostring intervals)
                      :discovered []}
        triad (if (is-power interval-obj)
                  :power
                  (or (identify-triad interval-obj)
                      (error "Chord can't be identified")))
        ext (identify-ext interval-obj)
        seventh (when (and ext (not= 6 ext))
                  (-?> intervals (. 3) quality->string))
        add (identify-add interval-obj)]
    {: triad : ext : seventh : add}))

(fn into-intervals [root & notes]
  (var last-interval nil)
  (icollect [_ note (ipairs notes)]
    (let [without-octave (not (and root.octave note.octave))
          interval (Interval.identify root note)
          lesser-interval (when last-interval
                            (< (interval:semitones) (last-interval:semitones)))]
      (if (and without-octave lesser-interval)
          (set interval.size (+ interval.size 7)))
      (set last-interval interval)
      interval)))

{: intervals->suffix : into-intervals}
