(local {: apply : range : mapcat : inc : concat : into : vector
        : map : empty? : nth : sort : add : filter : merge-with} (require :cljlib))

(fn second [v]
  (. v 2))

(fn table? [v]
  (= (type v) :table))

(fn index-of [el coll]
  (var res nil)
  (var i 1)
  (while (not res)
    (when (= el (. coll i)) (set res i))
    (set i (+ i 1)))
  res)

(fn sort-transformed [coll comp]
  (sort #(< (comp $) (comp $2)) coll))

(fn sum-tables [a b]
  (apply merge-with add a b))

(fn slice [coll a b]
  (map #(nth coll $) (range a (inc b))))

(fn circular-index [coll i]
  (let [index (% i (length coll))]
    (. coll (if (= index 0) (length coll) index))))

(fn prepend [el t]
  (into (vector) (concat [el] t)))

(fn safe-prepend [el t]
  (if el (prepend el t) t))

(fn swap [[a b]]
  [b a])

(fn nested? [v]
  (not (empty? (filter table? v))))

(fn flatten-nested [coll]
  (mapcat
   (fn [x]
     (if (nested? x)        
         x [x]))
   coll))

{: sort-transformed : table?
 : second : slice : index-of
 : circular-index : sum-tables
 : safe-prepend : flatten-nested : swap}
