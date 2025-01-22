(local {: quality->string} (require :modest.basics))

(local {: map : head : empty?} (require :modest.utils))

(local unpack (or table.unpack _G.unpack))

(fn includes-sequence [t seq discovered]
  (each [i e (ipairs t) &until (empty? seq)]
    (when (= e (head seq))
      (set (. discovered i) true)
      (table.remove seq 1)))
  (empty? seq))

(macro interval-cond [intervals & rest]
  (let [cases (icollect [i e (ipairs rest)]
                (if (= (% i 2) 1)
                    `(includes-sequence
                      (. ,intervals :str-seq)
                      ,e
                      (. ,intervals :discovered))
                    e))]
    `(if ,(unpack cases))))

(fn is-power [{: str-seq}]
  (let [[first & rest] str-seq]
    (and (= first :P5)
         (= (length rest) 0))))

(fn identify-triad [intervals]
  (interval-cond intervals
                 [:m3 :P5] :min
                 [:M3 :P5] :maj
                 [:M3 :A5] :aug
                 [:M2 :P5] [:sus 2]
                 [:P4 :P5] [:sus 4]
                 [:m3 :d5] :dim))

(fn identify-ext [intervals]
  (interval-cond intervals
                 [:m7 :M9 :P11 :M13] 13
                 [:m7 :M9 :P11] 11
                 [:m7 :M9] 9
                 [:m7] 7
                 [:M7] 7
                 [:d7] 7
                 [:M6] 6))

(fn identify-add [intervals])

(fn intervals->suffix [intervals]
  (let [interval-obj {:str-seq (map tostring intervals)
                      :discovered []}
        triad (if (is-power interval-obj)
                  :power
                  (or (identify-triad interval-obj)
                      (error "Chord can't be identified")))
        ext (identify-ext interval-obj)
        seventh (when (and ext (not= 6 ext))
                  (-?> intervals (. 3) quality->string))
        undiscovered (icollect [i e (ipairs interval-obj.str-seq)]
                       (when (not (. interval-obj.discovered i))
                         e))
        add (identify-add undiscovered)]
    {: triad : ext : seventh : add}))

{: intervals->suffix}
