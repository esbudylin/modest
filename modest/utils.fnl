;; Any copyright is dedicated to the Public Domain.
;; https://creativecommons.org/publicdomain/zero/1.0/

;; luajit support
(local unpack
       (or _G.unpack table.unpack))

(fn inc [i]
  (+ 1 i))

(fn dec [i]
  (- i 1))

(fn nth [i coll]
  (. coll i))

(fn range [i j]
  (fcollect [n i j] n))

(fn apply [f args]
  (f (unpack args)))

(fn map [foo v]
  (icollect [_ i (ipairs v)]
    (foo i)))

;; map into associative table
(fn map-into-kv [foo v]
  (collect [_ i (ipairs v)]
    (foo i)))

(fn slice [coll a b]
  (map #(nth $ coll)
       (range a b)))

(fn filter [foo v]
  (icollect [_ i (ipairs v)]
    (when (foo i) i)))

(fn reduce [f acc coll]
  (accumulate [acc acc
               _ n (ipairs coll)]
    (f acc n)))

(fn head [v]
  (. v 1))

(fn second [v]
  (. v 2))

(fn tail [v]
  (slice 2 (length v)))

(fn table? [v]
  (= (type v) :table))

(fn sum [& nums]
  (reduce #(+ $ $2) 0 nums))

(fn sort-transformed! [coll comp]
  (table.sort coll #(< (comp $) (comp $2)))
  coll)

(fn circular-index [coll i]
  (let [index (% i (length coll))]
    (. coll (if (= index 0) (length coll) index))))

(fn prepend! [el t]
  (table.insert t 1 el)
  t)

(fn conj! [t v]
  (table.insert t v)
  t)

(fn safe-prepend! [el t]
  (if el (prepend! el t) t))

(fn swap [[a b]]
  [b a])

(fn empty? [coll]
  (= (nth 1 coll) nil))

(fn nested? [v]
  (not (empty? (filter table? v))))

(fn chain! [a b]
  (each [_ el (ipairs b)]
    (conj! a el))
  a)

(fn mapcat [f coll]
  (reduce chain! [] (map f coll)))

(fn flatten-nested [coll]
  (mapcat
   (fn [x]
     (if (nested? x)        
         x [x]))
   coll))

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

(fn dissoc! [t & keys]
  (each [_ k (ipairs keys)]
    (tset t k nil))
  t)

(fn assoc! [t k v]
  (tset t k v)
  t)

(fn parse [grammar str]
  (or (grammar:match str)
      (error (.. "Can't parse: " str))))

(fn string? [str]
  (= (type str) :string))

(fn parse-if-string [grammar n]
  (if (string? n)
      (parse grammar n)
      n))

{: sort-transformed! : table?
 : second : slice : dec
 : circular-index : conj!
 : safe-prepend! : flatten-nested : swap
 : apply : inc : map-into-kv
 : sum : copy : keys : vals
 : assoc! : dissoc! : parse : parse-if-string
 : map : slice : range : reduce : head} 
