;; luajit support
(local unpack
       (or _G.unpack table.unpack))

(local {: range : map : nth : reduce : chain
        : filter : totable : head : tail} (require :fun))

(fn apply [f args]
  (f (unpack args)))

(fn second [v]
  (. v 2))

(fn table? [v]
  (= (type v) :table))

(fn inc [i]
  (+ 1 i))

(fn dec [i]
  (- i 1))

(fn sum [& nums]
  (reduce #(+ $ $2) 0 nums))

(fn sort-transformed [coll comp]
  (table.sort coll #(< (comp $) (comp $2)))
  coll)

(fn slice [coll a b]
  (map #(nth $ coll)
       (range a b)))

(fn circular-index [coll i]
  (let [index (% i (length coll))]
    (. coll (if (= index 0) (length coll) index))))

(fn prepend [el t]
  (table.insert t 1 el)
  t)

(fn conj [t v]
  (table.insert t v)
  t)

(fn safe-prepend [el t]
  (if el (prepend el t) t))

(fn swap [[a b]]
  [b a])

(fn empty? [coll]
  (= (nth 1 coll) nil))

(fn nested? [v]
  (not (empty? (filter table? v))))

(fn mapcat [f coll]
  (reduce chain [] (map f coll)))

(fn flatten-nested [coll]
  (mapcat
   (fn [x]
     (if (nested? x)        
         x [x]))
   coll))

(fn index-of [el coll]
  (fn u [coll acc]
    (if (empty? coll) nil
        (= (head coll) el) acc
        (u (tail coll) (+ acc 1))))
  (u coll 1))

(fn contains? [coll el]
  (not= (index-of el coll) nil))

(fn mapv [foo coll]
  (totable (map foo coll)))

(fn copy [t]
  (local res {})
  (each [k v (pairs t)]
    (tset res k
          (if (= (type v) :table) (copy v) v)))
  res)

(fn keys [m]
  (icollect [k _ (pairs m)] k))

(fn vals [m]
  (icollect [_ v (pairs m)] v))

(fn dissoc [t & keys]
  (each [_ k (ipairs keys)]
    (tset t k nil))
  t)

(fn assoc [t k v]
  (tset t k v)
  t)

{: sort-transformed : table?
 : second : slice : index-of : dec
 : circular-index : conj
 : safe-prepend : flatten-nested : swap
 : apply : inc : mapv : contains?
 : sum : copy : keys : vals
 : assoc : dissoc } 
