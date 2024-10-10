(local {: apply : range : keys : mapcat : inc : concat : into : vector
        : first : rest : map : empty? : contains? : reduce : nth : sort
        : add : last : filter : mapv : conj : dissoc : merge-with : vals} (require :cljlib))

(import-macros {: defn} (doto :cljlib require))

(fn second [v]
  (. v 2))

(fn table? [v]
  (= (type v) :table))

(defn index-of
  ([el coll] (index-of el coll 1))
  ([el coll acc] (if (empty? coll) nil
                     (= (first coll) el) acc
                     (index-of el (rest coll) (+ acc 1)))))

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
