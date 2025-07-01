;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(local {: quality->string : Interval } (require :modest.basics))

(local {: map : head : empty? : concat!} (require :modest.utils))

(local unpack (or table.unpack _G.unpack))

(macro table-set [& seq]
  (collect [_ e (ipairs seq)]
    (values e true)))

(macro not-identified [] '(error "Chord can't be identified"))

(fn includes-sequence [t seq discovered]
  (let [discovered-temp (collect [i e (ipairs t) &until (empty? seq)]
                          (when (= e (head seq))
                            (set (. discovered i) true)
                            (table.remove seq 1)))]
    (when (empty? seq)
      (concat! discovered discovered-temp)
      true)))

(fn unidentifed-intervals [{: intervals : identified-intervals}]
  (collect [i e (ipairs intervals)]
    (when (not (. identified-intervals i))
      (values i e))))

(fn ensure-chord-identified [{: intervals : alteration-map : identified-intervals}]
  (each [i e (ipairs intervals)]
    (when (and (not (. identified-intervals i))
               (not (. alteration-map e.size)))
      (not-identified))))

(macro interval-cond [interval-obj intervals-field & rest]
  (let [cases (icollect [i e (ipairs rest)]
                (if (= (% i 2) 1)
                    `(includes-sequence
                      (map tostring (. ,interval-obj ,intervals-field))
                      ,e
                      (. ,interval-obj :identified-intervals))
                    e))]
    `(if ,(unpack cases))))

(fn identify-power [{: intervals : identified-intervals }]
  (let [[first & rest] intervals
        power (and (= first.size 5)
                   (= first.quality 0)
                   (= (length rest) 0))]
    (when power
      (set (. identified-intervals 1) true)
      :power)))

(fn identify-altered-triad [{: alteration-map &as interval-obj}]
  (let [triad
        (interval-cond interval-obj :intervals
                       [:m3 :d5] :dim
                       [:M3 :A5] :aug)]
    (when triad
      (set (. alteration-map 5) nil)
      triad)))

(fn identify-triad* [interval-obj]
  (interval-cond interval-obj :normalized-intervals
                 [:m3 :P5] :min
                 [:M3 :P5] :maj
                 [:M2 :P5] [:sus 2]
                 [:P4 :P5] [:sus 4]))

(fn identify-triad [interval-obj]
  (or
   (identify-power interval-obj)
   (identify-altered-triad interval-obj)
   (identify-triad* interval-obj)
   (not-identified)))

(fn identify-ext* [interval-obj]
  (interval-cond interval-obj :normalized-intervals
                 [:m7 :M9 :P11 :M13] 13
                 [:m7 :M9 :P11] 11
                 [:m7 :M9] 9
                 [:m7] 7
                 [:M7] 7
                 [:d7] 7
                 [:M6] 6))

(fn identify-seventh [ext intervals]
  (when (and ext (not= 6 ext))
    (-?> intervals (. 3) quality->string)))

(fn identify-ext [{: alteration-map &as interval-obj}]
  (fn trim-ext [ext]
    (if (. alteration-map ext)
        (if (and (not= 7 ext) (not= 6 ext))
            (trim-ext (- ext 2))
            nil)
        ext))
  (let [ext (identify-ext* interval-obj)]
    (trim-ext ext)))

(fn identify-add [{: identified-intervals &as interval-obj}]
  (let [add-intervals (table-set 2 4 9 11 13)]
    (var res nil)
    (each [i interval (pairs (unidentifed-intervals interval-obj)) &until res]
      (when (and (. add-intervals interval.size)
                 (= interval.quality 0))
        (do (set (. identified-intervals i) true)
            (set res interval.size))))
    res))

(fn handle-alterations [intervals]
  (let [alteration-interevals (table-set 4 5 6 9 11 13)
        alterations {}
        intervals (icollect [_ interval (ipairs intervals)]
                    (if (and (. alteration-interevals interval.size)
                             (not= interval.quality 0))
                        (do
                          (set (. alterations interval.size) interval.quality)
                          (Interval.new interval.size 0))
                        interval))]
    (values intervals alterations)))

(fn alterations->seq [alteration-map]
  (when (next alteration-map)
      (icollect [size quality (pairs alteration-map)]
        [quality size])))

(fn intervals->suffix [intervals]
  (let [(normalized-intervals alteration-map) (handle-alterations intervals)
        interval-obj {: normalized-intervals
                      : intervals
                      : alteration-map
                      :identified-intervals []}
        triad (identify-triad interval-obj)
        ext (identify-ext interval-obj)
        seventh (identify-seventh ext intervals)
        add (identify-add interval-obj)]
    (ensure-chord-identified interval-obj)
    {: triad : ext : seventh : add
     :alterations (alterations->seq alteration-map)}))

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
