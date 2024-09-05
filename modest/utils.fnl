;; luajit support
(local unpack
       (or _G.unpack table.unpack))

(macro let-default [bindings & body]
  (let [tbl (icollect [i b (ipairs bindings)]
              (if (~= 0 (% i 2))
                  b
                  (let [val (. bindings (- i 1))]
                    `(if (= ,val nil) ,b ,val))))]
    `(let ,tbl ,(unpack body))))

(fn apply [f args]
  (f (unpack args)))

(fn map [foo v]
  (icollect [_ i (ipairs v)]
    (foo i)))

(fn filter [foo v]
  (icollect [_ i (ipairs v)]
    (when (foo i) i)))

(fn range [i]
  (fcollect [j 1 i] j))

(fn keys [m]
  (icollect [k _ (pairs m)] k))

(fn vals [m]
  (icollect [_ v (pairs m)] v))

(fn car [v]
  (. v 1))

(fn second [v]
  (. v 2))

(fn cdr [v]
  [(unpack v 2)])

(fn last [v]
  (. v (length v)))

(fn cons [a v]
  [a (unpack v)])

(fn conj [t v]
  (table.insert t v)
  t)

(fn concat [v1 v2]
  (each [_ e (ipairs v2)]
    (table.insert v1 e))
  v1)

(fn empty? [v]
  (= (next v) nil))

(fn table? [v]
  (= (type v) :table))

(fn find [coll el acc]
  (let-default
   [acc 1]
   (if (empty? coll) nil
       (= (car coll) el) acc
       (find (cdr coll) el (+ acc 1)))))

(fn contains? [coll el]
  (not= (find coll el) nil))

(fn sort [coll comp]
  (table.sort coll (when comp #(< (comp $1) (comp $2))))
  coll)

(fn flatten [v fcond acc]
  (let-default
   [acc [] fcond (fn [] true)]
   (if (empty? v) acc
       (and (table? (car v)) (fcond (car v)))
       (flatten (cdr v)
                fcond
                (concat acc (flatten (car v) fcond)))
       (flatten (cdr v)
                fcond
                (conj acc (car v))))))

(fn nested? [v]
  (not (empty? (filter #(= (type $1) :table) v))))

(fn flatten-nested [lol]
  (flatten lol #(nested? $1)))

(fn circular [t]
  (local n (length t))
  (var i 0)
  (fn []
    (set i (+ i 1))
    (let [pos (% i n)]
      (values i (. t (if (= pos 0) n pos))))))

(fn reduce [f coll acc]
  (if
   (empty? coll) acc
   (= acc nil) (reduce f (cdr coll) (car coll))
   (reduce f (cdr coll) (f acc (car coll)))))

(fn comp [& fs]
  (reduce
   (fn [f g]
     (fn [& args] (f (apply g args))))
   fs))

(fn sum-tables [a b]
  (local res {})
  (each [k v (pairs b)]
    (tset res k (+ v (. a k))))
  res)

(fn slice [coll a b]
  [(unpack coll a b)])

(fn sum [& nums]
  (accumulate [acc 0 _ n (ipairs nums)]
    (+ acc n)))

(fn circular-index [coll i]
  (let [index (% i (length coll))]
    (. coll (if (= index 0) (length coll) index))))

(fn index-by [coll foo]
  (collect [_ i (ipairs coll)]
    (foo i) i))

(fn safe-cons [el l]
  (if el (cons el l) l))

(fn remove-keys [t & keys]
  (each [_ k (ipairs keys)]
    (tset t k nil))
  t)

(fn copy [t]
  (local res {})
  (each [k v (pairs t)]
    (tset res k
          (if (= (type v) :table) (copy v) v)))
  res)

(fn swap [[a b]]
  [b a])

{: map : cons : conj : concat
 : flatten : car : cdr : contains?
 : sort : empty? : table? : filter
 : range : second : circular : find
 : comp : reduce : apply : last : slice
 : sum : circular-index : flatten-nested
 : keys : vals : sum-tables : index-by
 : safe-cons : remove-keys : copy
 : swap}
