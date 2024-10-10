;;; reduced

(set package.preload.reduced
  (or package.preload.reduced
      ;; https://gitlab.com/andreyorst/reduced.lua
      #(let [Reduced
             {:__fennelview
              (fn [[x] view options indent]
                (.. "#<reduced: " (view x options (+ 11 indent)) ">"))
              :__index {:unbox (fn [[x]] x)}
              :__name :reduced
              :__tostring (fn [[x]] (.. "reduced: " (tostring x)))}]
         (fn reduced [value]
           "Wrap `value` as an instance of the Reduced object.
Reduced will terminate the `reduce` function, if it supports this kind
of termination."
           (setmetatable [value] Reduced))
         (fn reduced? [value]
           "Check if `value` is an instance of Reduced."
           (rawequal (getmetatable value) Reduced))
         {:is_reduced reduced? : reduced :reduced? reduced?})))

;;; itable

(set package.preload.itable
  (or package.preload.itable
      (fn []
(local {:sort t/sort
        :concat t/concat
        :remove t/remove
        :move t/move
        :insert t/insert}
  table)

(local t/unpack (or table.unpack _G.unpack))
(local t/pack #(doto [$...] (tset :n (select "#" $...))))

(fn pairs* [t]
  "A variant of `pairs` function that gets correct `__pairs` metamethod from `t`.

Note, both `pairs', `ipairs', and `length' should only be needed on
Lua 5.1 and LuaJIT where there's no direct support for such
metamethods."
  ((match (getmetatable t)
     {:__pairs p} p
     _ pairs) t))

(fn ipairs* [t]
  "A variant of `ipairs` function that gets correct `__ipairs` metamethod from `t`."
  ((match (getmetatable t)
     {:__ipairs i} i
     _ ipairs) t))

(fn length* [t]
  "A variant of `length` function that gets correct `__len` metamethod from `t`."
  ((match (getmetatable t)
     {:__len l} l
     _ (partial length)) t))

(fn copy [t]
  ;; Shallow copy the given table.  Intentionally returns mutable copy
  ;; with no metatable copied.
  (when t
    (collect [k v (pairs* t)]
      (values k v))))

(fn eq [...]
  "Deep comparison.

Works on table keys that itself are tables.  Accepts any amount of
elements.

``` fennel
(assert-is (eq 42 42))
(assert-is (eq [1 2 3] [1 2 3]))
```

Deep comparison is used for tables:

``` fennel
(assert-is (eq {[1 2 3] {:a [1 2 3]} {:a 1} {:b 2}}
               {{:a 1} {:b 2} [1 2 3] {:a [1 2 3]}}))
(assert-is (eq {{{:a 1} {:b 1}} {{:c 3} {:d 4}} [[1] [2 [3]]] {:a 2}}
               {[[1] [2 [3]]] {:a 2} {{:a 1} {:b 1}} {{:c 3} {:d 4}}}))
```"
  (match (values (select :# ...) ...)
    (where (or (0) (1)))
    true
    (2 ?a ?b)
    (if (= ?a ?b)
        true
        (= (type ?a) (type ?b) :table)
        (do (var (res count-a count-b) (values true 0 0))
            (each [k v (pairs* ?a) :until (not res)]
              (set res (eq v (do (var res nil)
                                 (each [k* v (pairs* ?b) :until res]
                                   (when (eq k* k)
                                     (set res v)))
                                 res)))
              (set count-a (+ count-a 1)))
            (when res
              (each [_ _ (pairs* ?b)]
                (set count-b (+ count-b 1)))
              (set res (= count-a count-b)))
            res)
        false)
    (_ ?a ?b)
    (and (eq ?a ?b) (eq (select 2 ...)))))

(fn deep-index [tbl key]
  ;; This function uses the `eq` function to compare keys of the given
  ;; table `tbl` and the given `key`.
  (accumulate [res nil
               k v (pairs* tbl)
               :until res]
    (when (eq k key)
      v)))

(fn deep-newindex [tbl key val]
  ;; This function uses the `eq` function to compare keys of the given
  ;; table `tbl` and the given `key`. If the key is found it's being
  ;; set, if not a new key is set.
  (var done false)
  (when (= :table (type key))
    (each [k _ (pairs* tbl) :until done]
      (when (eq k key)
        (rawset tbl k val)
        (set done true))))
  (when (not done)
    (rawset tbl key val)))

(fn immutable [t opts]
  ;; Return a proxy table with precalculated `__len`, and `__newindex`
  ;; metamethod that ensures immutability.  `__pairs` metamethod
  ;; operates on a shallow copy, to prevent mutable table leaking.
  ;; Tables can be called with one argument to lookup keys.
  (let [t (if (and opts opts.fast-index?)
              t
              (setmetatable t {:__index deep-index
                               :__newindex deep-newindex}))
        len (length* t)
        proxy {}
        __len #len
        __index #(. t $2) ; avoid exposing closure via `debug.getmetatable`
        __newindex #(error (.. (tostring proxy) " is immutable") 2)
        __pairs #(values (fn [_ k] (next t k)) nil nil) ; avoid exposing closure via `pairs`
        __ipairs #(fn [_ k] (next t k)) ; Lua 5.2-5.3 compat
        __call #(. t $2)
        __fennelview #($2 t $3 $4)
        __fennelrest #(immutable [(t/unpack t $2)])]
    (setmetatable proxy
                  {: __index
                   : __newindex
                   : __len
                   : __pairs
                   : __ipairs
                   : __call
                   ;; metatable impostor that acts as a public
                   ;; metatable for LuaJIT to work.  Deliberately
                   ;; doesn't expose __index and __newindex
                   ;; metamethods.
                   :__metatable {: __len
                                 : __pairs
                                 : __ipairs
                                 : __call
                                 : __fennelrest
                                 : __fennelview
                                 :itable/type :immutable}})))

;;; Default functions

(fn insert [t ...]
  "Inserts element at position `pos` into sequential table,
shifting up the elements.  The default value for `pos` is table length
plus 1, so that a call with just two arguments will insert the value
at the end of the table.  Returns a new immutable table.

# Examples

Original table is not modified, when element is inserted:

``` fennel
(local t1 [1 2 3])
(assert-eq [1 2 3 4] (itable.insert t1 4))
(assert-eq [1 2 3] t1)
```

New table is immutable:

``` fennel
(local t1 [1 2 3])
(local t2 (itable.insert t1 4))
(assert-not (pcall table.insert t2 5))
```"
  (let [t (copy t)]
    (match (values (select :# ...) ...)
      (0) (error "wrong number of arguments to 'insert'")
      (1 ?v) (t/insert t ?v)
      (_ ?k ?v) (t/insert t ?k ?v))
    (immutable t)))


(local move
  (when t/move
    (fn [src start end tgt dest]
      "Move elements from `src` table to `dest` starting at `start` to `end`,
placing elements from `tgt` and up.  The default for `dest` is `src`.
The destination range can overlap with the `src` range.  The number of
elements to be moved must fit in a Lua integer.  Returns new immutable
table.

# Examples

Move elements from 3 to 5 to another table's end:

``` fennel
(local t1 [1 2 3 4 5 6 7])
(local t2 [10 20])
(assert-eq [10 20 3 4 5] (itable.move t1 3 5 3 t2))
(assert-eq t1 [1 2 3 4 5 6 7])
(assert-eq t2 [10 20])
```"
      (let [src (copy src)
            dest (copy dest)]
        (-> src
            (t/move start end tgt dest)
            immutable)))))

;; portable table.pack implementation
(fn pack [...]
  "Pack values into immutable table with size indication."
  (-> [...]
      (doto (tset :n (select :# ...)))
      immutable))


(fn remove [t key]
  "Remove `key` from table, and return a new immutable table and value
that was associated with the `key`.

# Examples

Remove element from the end of the table:


``` fennel
(local t1 [1 2 3])
(local (t2 v) (itable.remove t1))

(assert-eq t1 [1 2 3])
(assert-eq t2 [1 2])
(assert-eq v 3)
```

The newly produced table is immutable:

``` fennel
(assert-not (pcall table.insert (itable.remove [1 2 3])))
```"
  (let [t (copy t)
        v (t/remove t key)]
    (values (immutable t) v)))


(fn concat [t sep start end serializer opts]
  "Concatenate each element of sequential table with separator `sep`.

Optionally supports `start` and `end` indexes, and a `serializer`
function, with a table `opts` for that serialization function.

If no serialization function is given, `tostring` is used.

``` fennel
(local {: view} (require :fennel))
(local t [1 2 {:a 1 :b 2}])
(assert-eq (itable.concat t \", \" nil nil view {:one-line? true})
           \"1, 2, {:a 1 :b 2}\")
```"

  (let [serializer (or serializer tostring)]
    (t/concat (icollect [_ v (ipairs* t)]
                (serializer v opts)) sep start end)))


(fn unpack [t ...]
  "Unpack immutable table.

Note, that this is needed only in LuaJit and Lua 5.2, because of how
metamethods work."
  (t/unpack (copy t) ...))


;;; Extras

(fn assoc [t key val ...]
  "Associate `val` under a `key`.
Accepts extra keys and values.

# Examples

``` fennel
(assert-eq {:a 1 :b 2} (itable.assoc {:a 1} :b 2))
(assert-eq {:a 1 :b 2} (itable.assoc {:a 1 :b 1} :b 2))
(assert-eq {:a 1 :b 2 :c 3} (itable.assoc {:a 1 :b 1} :b 2 :c 3))
```"
  (let [len (select :# ...)]
    (when (not= 0 (% len 2))
      (error (.. "no value supplied for key " (tostring (select len ...))) 2))
    (let [t (doto (copy t) (tset key val))]
      (for [i 1 len 2]
        (let [(k v) (select i ...)]
          (tset t k v)))
      (immutable t))))


(fn assoc-in [t [k & ks] val]
  "Associate `val` into set of immutable nested tables `t`, via given keys.
Returns a new immutable table.  Returns a new immutable table.

# Examples

Replace value under nested keys:

``` fennel
(assert-eq
 {:a {:b {:c 1}}}
 (itable.assoc-in {:a {:b {:c 0}}} [:a :b :c] 1))
```

Create new entries as you go:

``` fennel
(assert-eq
 {:a {:b {:c 1}} :e 2}
 (itable.assoc-in {:e 2} [:a :b :c] 1))
```"
  (let [t (or t {})]
    (if (next ks)
        (assoc t  k (assoc-in (or (. t k) {}) ks val))
        (assoc t  k val))))


(fn update [t key f]
  "Update table value stored under `key` by calling a function `f` on
that value. `f` must take one argument, which will be a value stored
under the key in the table.

# Examples

Same as `assoc' but accepts function to produce new value based on key value.

``` fennel
(assert-eq
 {:data \"THIS SHOULD BE UPPERCASE\"}
 (itable.update {:data \"this should be uppercase\"} :data string.upper))
```"
  (immutable (doto (copy t) (tset key (f (. t key))))))


(fn update-in [t [k & ks] f]
  "Update table value stored under set of immutable nested tables, via
given keys by calling a function `f` on the value stored under the
last key.  `f` must take one argument, which will be a value stored
under the key in the table.  Returns a new immutable table.

# Examples

Same as `assoc-in' but accepts function to produce new value based on key value.

``` fennel
(fn capitalize-words [s]
  (pick-values 1
    (s:gsub \"(%a)([%w_']*)\" #(.. ($1:upper) ($2:lower)))))

(assert-eq
 {:user {:name \"John Doe\"}}
 (itable.update-in {:user {:name \"john doe\"}} [:user :name] capitalize-words))
```"
  (let [t (or t [])]
    (if (next ks)
        (assoc t k (update-in (. t k) ks f))
        (update t k f))))


(fn deepcopy [x]
  "Create a deep copy of a given table, producing immutable tables for nested tables.
Copied table can't contain self references."
  (fn deepcopy* [x seen]
    (match (type x)
      :table (match (. seen x)
               true (error "immutable tables can't contain self reference" 2)
               _ (do (tset seen x true)
                     (-> (collect [k v (pairs* x)]
                           (values (deepcopy* k seen)
                                   (deepcopy* v seen)))
                         immutable)))
      _ x))
  (deepcopy* x {}))


(fn first [[x]]
  "Return the first element from the table."
  x)


(fn rest [t]
  "Return all but the first elements from the table `t` as a new immutable
table."
  (pick-values 1 (remove t 1)))


(fn nthrest [t n]
  "Return all elements from `t` starting from `n`.  Returns immutable
table."
  (let [t* []]
    (for [i (+ n 1) (length* t)]
      (t/insert t* (. t i)))
    (immutable t*)))


(fn last [t]
  "Return the last element from the table."
  (. t (length* t)))


(fn butlast [t]
  "Return all elements but the last one from the table as a new
immutable table."
  (pick-values 1 (remove t (length* t))))


(fn join [...]
  "Join arbitrary amount of tables, and return a new immutable table.

# Examples

``` fennel
(local t1 [1 2 3])
(local t2 [4])
(local t3 [5 6])

(assert-eq [1 2 3 4 5 6] (itable.join t1 t2 t3))
(assert-eq t1 [1 2 3])
(assert-eq t2 [4])
(assert-eq t3 [5 6])
```"
  (match (values (select :# ...) ...)
    (0) nil
    (1 ?t) (immutable (copy ?t))
    (2 ?t1 ?t2) (let [to (copy ?t1)
                      from (or ?t2 [])]
                  (each [_ v (ipairs* from)]
                    (t/insert to v))
                  (immutable to))
    (_ ?t1 ?t2) (join (join ?t1 ?t2) (select 3 ...))))


(fn take [n t]
  "Take first `n` elements from table `t` and return a new immutable
table.

# Examples

Take doesn't modify original table:

```fennel
(local t1 [1 2 3 4 5])

(assert-eq [1 2 3] (itable.take 3 t1))
(assert-eq t1 [1 2 3 4 5])
```"
  (let [t* []]
    (for [i 1 n]
      (t/insert t* (. t i)))
    (immutable t*)))


(fn drop [n t]
  "Drop first `n` elements from table `t` and return a new immutable
table.

# Examples

Take doesn't modify original table:

```fennel
(local t1 [1 2 3 4 5])

(assert-eq [4 5] (itable.drop 3 t1))
(assert-eq t1 [1 2 3 4 5])
```"
  (nthrest t n))


(fn partition [...]
  "Returns a immutable table of tables of `n` elements, at `step`
offsets.  `step defaults to `n` if not specified.  Additionally
accepts a `pad` collection to complete last partition if it doesn't
have sufficient amount of elements.

# Examples
Partition table into sub-tables of size 3:

``` fennel
(assert-eq (itable.partition 3 [1 2 3 4 5 6])
           [[1 2 3] [4 5 6]])
```

When table doesn't have enough elements to form full partition,
`partition` will not include those:

``` fennel
(assert-eq (itable.partition 2 [1 2 3 4 5]) [[1 2] [3 4]])
```

Partitions can overlap if step is supplied:

``` fennel
(assert-eq (itable.partition 2 1 [1 2 3 4]) [[1 2] [2 3] [3 4]])
```

Additional padding can be used to supply insufficient elements:

``` fennel
(assert-eq (itable.partition 3 3 [-1 -2 -3] [1 2 3 4 5 6 7])
           [[1 2 3] [4 5 6] [7 -1 -2]])
```"
  (let [res []]
    (fn partition* [...]
      (match (values (select :# ...) ...)
        (where (or (0) (1))) (error "wrong amount arguments to 'partition'")
        (2 ?n ?t) (partition* ?n ?n ?t)
        (3 ?n ?step ?t) (let [p (take ?n ?t)]
                          (when (= ?n (length* p))
                            (t/insert res p)
                            (partition* ?n ?step [(t/unpack ?t (+ ?step 1))])))
        (_ ?n ?step ?pad ?t) (let [p (take ?n ?t)]
                               (if (= ?n (length* p))
                                   (do (t/insert res p)
                                       (partition* ?n ?step ?pad [(t/unpack ?t (+ ?step 1))]))
                                   (t/insert res (take ?n (join p ?pad)))))))
    (partition* ...)
    (immutable res)))


(fn keys [t]
  "Return all keys from table `t` as an immutable table."
  (-> (icollect [k _ (pairs* t)] k)
      immutable))


(fn vals [t]
  "Return all values from table `t` as an immutable table."
  (-> (icollect [_ v (pairs* t)] v)
      immutable))


(fn group-by [f t]
  "Group table items in an associative table under the keys that are
results of calling `f` on each element of sequential table `t`.
Elements that the function call resulted in `nil` returned in a
separate table.

# Examples

Group rows by their date:

``` fennel
(local rows
  [{:date \"2007-03-03\" :product \"pineapple\"}
   {:date \"2007-03-04\" :product \"pizza\"}
   {:date \"2007-03-04\" :product \"pineapple pizza\"}
   {:date \"2007-03-05\" :product \"bananas\"}])

(assert-eq (itable.group-by #(. $ :date) rows)
           {\"2007-03-03\"
            [{:date \"2007-03-03\" :product \"pineapple\"}]
            \"2007-03-04\"
            [{:date \"2007-03-04\" :product \"pizza\"}
             {:date \"2007-03-04\" :product \"pineapple pizza\"}]
            \"2007-03-05\"
            [{:date \"2007-03-05\" :product \"bananas\"}]})
```"
  (let [res {}
        ungroupped []]
    (each [_ v (pairs* t)]
      (let [k (f v)]
        (if (not= nil k)
            (match (. res k)
              t* (t/insert t* v)
              _ (tset res k [v]))
            (t/insert ungroupped v))))
    (values (-> (collect [k t (pairs* res)]
                  (values k (immutable t)))
                immutable)
            (immutable ungroupped))))


(fn frequencies [t]
  "Return a table of unique entries from table `t` associated to amount
of their appearances.

# Examples

Count each entry of a random letter:

``` fennel
(let [fruits [:banana :banana :apple :strawberry :apple :banana]]
  (assert-eq (itable.frequencies fruits)
             {:banana 3
              :apple 2
              :strawberry 1}))
```"
  (let [res (setmetatable {} {:__index deep-index
                              :__newindex deep-newindex})]
    (each [_ v (pairs* t)]
      (match (. res v)
        a (tset res v (+ a 1))
        _ (tset res v 1)))
    (immutable res)))


(local itable
  {:sort (fn [t f]
           "Return new immutable table of sorted elements from `t`.  Optionally
accepts sorting function `f`. "
           (-> t copy (doto (t/sort f)) immutable))
   : pack
   : unpack
   : concat
   : insert
   : move
   : remove
   ;; LuaJIT compat
   :pairs pairs*
   :ipairs ipairs*
   :length length*
   ;; extras
   : eq
   : deepcopy
   : assoc
   : assoc-in
   : update
   : update-in
   : keys
   : vals
   : group-by
   : frequencies
   ;; sequential extras
   : first
   : rest
   : nthrest
   : last
   : butlast
   : join
   : partition
   : take
   : drop})

(setmetatable
 itable
 {:__call (fn [_ t opts]
            (match (getmetatable t)
              {:itable/type :immutable} t
              _ (-> t copy (immutable opts))))})
;; LocalWords:  metatable precalculated metamethod
        )))

;;; lazy-seq

(set package.preload.lazy-seq
  (or package.preload.lazy-seq
      (fn []
;; macros

(eval-compiler
(local lib-name (or :lazy-seq))

  (fn lazy-seq [...]
    "Create lazy sequence from the result provided by running the `body'.
Delays the execution until the resulting sequence is consumed.

Same as `lazy-seq`, but doesn't require wrapping the body into an
anonymous function.

# Examples

Infinite* sequence of Fibonacci numbers:

```fennel
(local fib ((fn fib [a b] (lazy-seq (cons a (fib b (+ a b))))) 0 1))

(assert-eq [0 1 1 2 3 5 8]
           [(unpack (take 7 fib))])
```

*Sequence itself is infinite, but the numbers are limited to Lua's VM
number representation.  For true infinite Fibonacci number sequence
arbitrary precision math libraries like lbc or lmapm:

``` fennel
(local (ok? bc) (pcall require :bc))
(when ok?
  (local fib ((fn fib [a b] (lazy-seq (cons a (fib b (+ a b))))) (bc.new 0) (bc.new 1)))
  (assert-eq (bc.new (.. \"4106158863079712603335683787192671052201251086373692524088854309269055842741\"
                         \"1340373133049166085004456083003683570694227458856936214547650267437304544685216\"
                         \"0486606292497360503469773453733196887405847255290082049086907512622059054542195\"
                         \"8897580311092226708492747938595391333183712447955431476110732762400667379340851\"
                         \"9173181099320170677683893476676477873950217447026862782091855384222585830640830\"
                         \"1661862900358266857238210235802504351951472997919676524004784236376453347268364\"
                         \"1526483462458405732142414199379172429186026398100978669423920154046201538186714\"
                         \"25739835074851396421139982713640679581178458198658692285968043243656709796000\"))
             (first (drop 3000 fib))))

```"
    {:fnl/arglist [& body]}
    `(let [{:lazy-seq lazy-seq#} (require ,lib-name)]
       (lazy-seq# (fn [] ,...))))

  (fn lazy-cat [...]
    "Concatenate arbitrary amount of lazy `sequences'.

# Examples

Lazily concatenate finite sequence with infinite:

```fennel
(local r (lazy-cat (take 10 (range)) (drop 10 (range))))
(assert-eq [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14]
           (take 15 r))
```

Another Fibonacci sequence variant:

```fennel
(global fib (lazy-cat [0 1] (map #(+ $1 $2) (rest fib) fib)))

(assert-eq [0 1 1 2 3 5 8]
           (take 7 fib))
```"
    {:fnl/arglist [& sequences]}
    `(let [{:concat concat# :lazy-seq lazy-seq#} (require ,lib-name)]
       (concat# ,(unpack (icollect [_ s (ipairs [...])]
                           `(lazy-seq# (fn [] ,s)))))))


  ;; TODO: implement `doseq'
  ;; TODO: implement Clojure's `for' as a way to produce lazy sequences

  (tset macro-loaded lib-name
        {: lazy-seq
         : lazy-cat}))

;; reduced

(set package.preload.reduced
  (or package.preload.reduced
      ;; https://gitlab.com/andreyorst/reduced.lua
      #(let [Reduced
             {:__fennelview
              (fn [[x] view options indent]
                (.. "#<reduced: " (view x options (+ 11 indent)) ">"))
              :__index {:unbox (fn [[x]] x)}
              :__name :reduced
              :__tostring (fn [[x]] (.. "reduced: " (tostring x)))}]
         (fn reduced [value]
           "Wrap `value` as an instance of the Reduced object.
Reduced will terminate the `reduce` function, if it supports this kind
of termination."
           (setmetatable [value] Reduced))
         (fn reduced? [value]
           "Check if `value` is an instance of Reduced."
           (rawequal (getmetatable value) Reduced))
         {:is_reduced reduced? : reduced :reduced? reduced?})))

;;; Lua 5.1 compatibility layer

(global utf8 _G.utf8)

(fn pairs* [t]
  (let [mt (getmetatable t)]
    (if (and (= :table mt) mt.__pairs)
        (mt.__pairs t)
        (pairs t))))

(fn ipairs* [t]
  (let [mt (getmetatable t)]
    (if (and (= :table mt) mt.__ipairs)
        (mt.__ipairs t)
        (ipairs t))))

(fn rev-ipairs [t]
  (values (fn next [t i]
            (let [i (- i 1)]
              (match i
                0 nil
                _ (values i (. t i)))))
          t
          (+ 1 (length t))))

(fn length* [t]
  (let [mt (getmetatable t)]
    (if (and (= :table mt) mt.__len)
        (mt.__len t)
        (length t))))

(fn table-pack [...]
  (doto [...] (tset :n (select "#" ...))))

(local table-unpack
  (or table.unpack _G.unpack))

;; seq

(var seq nil)
(var cons-iter nil)

(fn first [s]
  "Return first element of a sequence."
  (match (seq s)
    s* (s* true)
    _ nil))

(fn empty-cons-view []
  ;; __fennelview metamethods for empty conses
  "@seq()")

(fn empty-cons-len []
  ;; __len metamethods for empty conses
  0)

(fn empty-cons-index []
  ;; __index metamethods for empty conses
  nil)

(fn cons-newindex []
  ;; __newindex metamethod for sequences
  (error "cons cell is immutable"))

(fn empty-cons-next [s]
  nil)

(fn empty-cons-pairs [s]
  (values empty-cons-next nil s))

(fn gettype [x]
  (match (?. (getmetatable x) :__lazy-seq/type)
    t t
    _ (type x)))

(fn realize [c]
  ;; force realize single cons cell
  (when (= :lazy-cons (gettype c))
    (c))
  c)

(local empty-cons [])

(fn empty-cons-call [tf]
  (if tf nil empty-cons))

(fn empty-cons-fennelrest []
  empty-cons)

(fn empty-cons-eq [_ s]
  (rawequal (getmetatable empty-cons) (getmetatable (realize s))))

(setmetatable empty-cons {:__call empty-cons-call
                          :__len empty-cons-len
                          :__fennelview empty-cons-view
                          :__fennelrest empty-cons-fennelrest
                          :__lazy-seq/type :empty-cons
                          :__newindex cons-newindex
                          :__index empty-cons-index
                          :__name "cons"
                          :__eq empty-cons-eq
                          :__pairs empty-cons-pairs})

(fn rest [s]
  "Return the tail of a sequence.

If the sequence is empty, returns empty sequence."
  (match (seq s)
    s* (s* false)
    _ empty-cons))

(fn seq? [x]
  "Check if object is a sequence."
  (let [tp (gettype x)]
    (or (= tp :cons)
        (= tp :lazy-cons)
        (= tp :empty-cons))))

(fn empty? [x]
  "Check if sequence is empty."
  (not (seq x)))

(fn next [s]
  "Return the tail of a sequence.

If the sequence is empty, returns nil."
  (seq (realize (rest (seq s)))))

;;; Cons cell

(fn view-seq [list options view indent elements]
  (table.insert elements (view (first list) options indent))
  (let [tail (next list)]
    (when (= :cons (gettype tail))
      (view-seq tail options view indent elements)))
  elements)

(fn pp-seq [list view options indent]
  (let [items (view-seq list options view (+ indent 5) [])
        lines (icollect [i line (ipairs items)]
                (if (= i 1) line (.. "     " line)))]
    (doto lines
      (tset 1 (.. "@seq(" (or (. lines 1) "")))
      (tset (length lines) (.. (. lines (length lines)) ")")))))

(var drop nil)

(fn cons-fennelrest [c i]
  (drop (- i 1) c))

(local allowed-types
  {:cons true
   :empty-cons true
   :lazy-cons true
   :nil true
   :string true
   :table true})

(fn cons-next [_ s]
  ;; stateless iterator over a sequence for __pairs metamethod
  (if (not= empty-cons s)
      (let [tail (next s)]
        (match (gettype tail)
          :cons (values tail (first s))
          _ (values empty-cons (first s))))
      nil))

(fn cons-pairs [s]
  ;; __pairs metamethod for sequences
  (values cons-next nil s))

(fn cons-eq [s1 s2]
  ;; __eq metamethod for sequences
  (if (rawequal s1 s2)
      true
      (if (and (not (rawequal s2 empty-cons))
               (not (rawequal s1 empty-cons)))
          (do (var (s1 s2 res) (values s1 s2 true))
              (while (and res s1 s2)
                (set res (= (first s1) (first s2)))
                (set s1 (next s1))
                (set s2 (next s2)))
              res)
          false)))

(fn cons-len [s]
  ;; __len metamethod for sequences
  (var (s len) (values s 0))
  (while s
    (set (s len) (values (next s) (+ len 1))))
  len)

(fn cons-index [s i]
  ;; __index metamethod for sequences
  (if (> i 0)
      (do (var (s i*) (values s 1))
          (while (and (not= i* i) s)
            (set (s i*) (values (next s) (+ i* 1))))
          (first s))
      nil))

(fn cons [head tail]
  "Construct a cons cell.
Prepends new `head' to a `tail', which must be either a table,
sequence, or nil.

# Examples

``` fennel
(assert-eq [0 1] (cons 0 [1]))
(assert-eq (list 0 1 2 3) (cons 0 (cons 1 (list 2 3))))
```"
  :fnl/arglist [head tail]
  (let [tp (gettype tail)]
    (assert (. allowed-types tp)
            (: "expected nil, cons, table, or string as a tail, got: %s" :format tp))
    (setmetatable [] {:__call #(if $2 head (match tail s s nil empty-cons))
                      :__lazy-seq/type :cons
                      :__index cons-index
                      :__newindex cons-newindex
                      :__len cons-len
                      :__pairs cons-pairs
                      :__name "cons"
                      :__eq cons-eq
                      :__fennelview pp-seq
                      :__fennelrest cons-fennelrest})))

(set seq
     (fn [s]
       "Construct a sequence out of a table, string or another sequence `s`.
Returns `nil` if given an empty sequence or an empty table.

Sequences are immutable and persistent, but their contents are not
immutable, meaning that if a sequence contains mutable references, the
contents of a sequence can change.  Unlike iterators, sequences are
non-destructive, and can be shared.

Sequences support two main operations: `first`, and `rest`.  Being a
single linked list, sequences have linear access time complexity..

# Examples

Transform sequential table to a sequence:

``` fennel
(local nums [1 2 3 4 5])
(local num-seq (seq nums))

(assert-eq nums num-seq)
```

Iterating through a sequence:

```fennel
(local s (seq [1 2 3 4 5]))

(fn reverse [s]
  ((fn reverse [s res]
     (match (seq s)
       s* (reverse (rest s*) (cons (first s*) res))
       _ res))
   s nil))

(assert-eq [5 4 3 2 1]
           (reverse s))
```


Sequences can also be created manually by using `cons` function."
       (match (gettype s)
         :cons s
         :lazy-cons (seq (realize s))
         :empty-cons nil
         :nil nil
         :table (cons-iter s)
         :string (cons-iter s)
         _ (error (: "expected table, string or sequence, got %s" :format _) 2))))

(fn lazy-seq [f]
  "Create lazy sequence from the result of calling a function `f`.
Delays execution of `f` until sequence is consumed.

See `lazy-seq` macro from init-macros.fnl for more convenient usage."
  (let [lazy-cons (cons nil nil)
        realize (fn []
                  (let [s (seq (f))]
                    (if (not= nil s)
                        (setmetatable lazy-cons (getmetatable s))
                        (setmetatable lazy-cons (getmetatable empty-cons)))))]
    (setmetatable lazy-cons {:__call #((realize) $2)
                             :__index #(. (realize) $2)
                             :__newindex cons-newindex
                             :__fennelview #(do (realize) (pp-seq $...))
                             :__fennelrest cons-fennelrest
                             :__len #(length* (realize))
                             :__pairs #(pairs* (realize))
                             :__name "lazy cons"
                             :__eq #(= (realize) $2)
                             :__lazy-seq/type :lazy-cons})))

(fn list [...]
  "Create eager sequence of provided `args'.

# Examples

``` fennel
(local l (list 1 2 3 4 5))
(assert-eq [1 2 3 4 5] l)
```"
  {:fnl/arglist [& args]}
  (let [args (table-pack ...)]
    (var l empty-cons)
    (for [i args.n 1 -1]
      (set l (cons (. args i) l)))
    l))

(fn spread [arglist]
  (let [arglist (seq arglist)]
    (if (= nil arglist) nil
        (= nil (next arglist)) (seq (first arglist))
        :else (cons (first arglist) (spread (next arglist))))))

(fn list* [...]
  "Creates a new sequence containing the `args' prepended to the rest,
the last of which will be treated as a sequence.

# Examples

``` fennel
(local l (list* 1 2 3 [4 5]))
(assert-eq [1 2 3 4 5] l)
```"
  {:fnl/arglist [& args]}
  (match (values (select "#" ...) ...)
    (1 ?args) (seq ?args)
    (2 ?a ?args) (cons ?a (seq ?args))
    (3 ?a ?b ?args) (cons ?a (cons ?b (seq ?args)))
    (4 ?a ?b ?c ?args) (cons ?a (cons ?b (cons ?c (seq ?args))))
    _ (spread (list ...))))

(fn kind [t]
  ;; A best effor at getting a kind of a given table.  Kind here means
  ;; if a table is an assotiatice, sequential or empty. Also applies
  ;; to string. If kind is unknown, returns `:else'.
  (match (type t)
    :table (let [len (length* t)
                 (nxt t* k) (pairs* t)]
             (if (not= nil (nxt t* (if (= len 0) k len))) :assoc
                 (> len 0) :seq
                 :empty))
    :string (let [len (if utf8 (utf8.len t) (length t))]
              (if (> len 0) :string :empty))
    _ :else))

(fn rseq [rev]
  "Returns, in possibly-constant time, a seq of the items in `rev` in reverse order.
Input must be traversable with `ipairs`.  Doesn't work in constant
time if `rev` implements a linear-time `__len` metamethod, or invoking
Lua `#` operator on `rev` takes linar time.  If `t` is empty returns
`nil`.

# Examples

``` fennel
(local v [1 2 3])
(local r (rseq v))

(assert-eq (reverse v) r)
```"
  (match (gettype rev)
    :table
    (match (kind rev)
      :seq ((fn wrap [nxt t i]
              (let [(i v) (nxt t i)]
                (if (not= nil i)
                    (cons v (lazy-seq #(wrap nxt t i)))
                    empty-cons)))
            (rev-ipairs rev))
      :empty nil
      _ (error (.. "can't create an rseq from a non-sequential table")))
    _ (error (.. "can't create an rseq from a " _))))

(set cons-iter
     (fn [t]
       (match (kind t)
         :assoc ((fn wrap [nxt t k]
                   (let [(k v) (nxt t k)]
                     (if (not= nil k)
                         (cons [k v] (lazy-seq #(wrap nxt t k)))
                         empty-cons)))
                 (pairs* t))
         :seq ((fn wrap [nxt t i]
                 (let [(i v) (nxt t i)]
                   (if (not= nil i)
                       (cons v (lazy-seq #(wrap nxt t i)))
                       empty-cons)))
               (ipairs* t))
         :string (let [char (if utf8 utf8.char string.char)]
                   ((fn wrap [nxt t i]
                      (let [(i v) (nxt t i)]
                        (if (not= nil i)
                            (cons (char v) (lazy-seq #(wrap nxt t i)))
                            empty-cons)))
                    (if utf8
                        (utf8.codes t)
                        (ipairs* [(string.byte t 1 (length t))]))))
         :empty nil)))

(fn every? [pred coll]
  "Check if `pred` is true for every element of a sequence `coll`."
  (match (seq coll)
    s (if (pred (first s))
          (match (next s)
            r (every? pred r)
            _ true)
          false)
    _ false))

(fn some? [pred coll]
  "Check if `pred` returns logical true for any element of a sequence
`coll`."
  (match (seq coll)
    s (or (pred (first s))
          (match (next s)
            r (some? pred r)
            _ nil))
    _ nil))

(fn pack [s]
  "Pack sequence into sequential table with size indication."
  (let [res []]
    (var n 0)
    (match (seq s)
      s* (each [_ v (pairs* s*)]
           (set n (+ n 1))
           (tset res n v)))
    (doto res (tset :n n))))

(fn count [s]
  "Count amount of elements in the sequence."
  (match (seq s)
    s* (length* s*)
    _ 0))

(fn unpack [s]
  "Unpack sequence items to multiple values."
  (let [t (pack s)]
    (table-unpack t 1 t.n)))

(fn concat [...]
  "Return a lazy sequence of concatenated sequences."
  {:fnl/arglist [([x]) ([x y]) ([x y & zs])]}
  (match (select "#" ...)
    0 empty-cons
    1 (let [(x) ...]
        (lazy-seq #x))
    2 (let [(x y) ...]
        (lazy-seq #(match (seq x)
                     s (cons (first s) (concat (rest s) y))
                     nil y)))
    _ (concat (concat (pick-values 2 ...)) (select 3 ...))))

(fn reverse [s]
  "Returns an eager reversed sequence."
  ((fn helper [s res]
     (match (seq s)
       s* (helper (rest s*) (cons (first s*) res))
       _ res)) s empty-cons))

(fn map [f ...]
  "Map function `f` over every element of a collection `col`.
`f` should accept as many arguments as there are collections supplied to `map`.
Returns a lazy sequence.

# Examples

```fennel
(map #(+ $ 1) [1 2 3]) ;; => @seq(2 3 4)
(map #(+ $1 $2) [1 2 3] [4 5 6]) ;; => @seq(5 7 9)
(local res (map #(+ $ 1) [:a :b :c])) ;; will raise an error only when realized
```"
  (match (select "#" ...)
    0 nil                               ; TODO: transducers?
    1 (let [(col) ...]
        (lazy-seq #(match (seq col)
                     x (cons (f (first x)) (map f (seq (rest x))))
                     _ nil)))
    2 (let [(s1 s2) ...]
        (lazy-seq #(let [s1 (seq s1) s2 (seq s2)]
                     (if (and s1 s2)
                         (cons (f (first s1) (first s2)) (map f (rest s1) (rest s2)))
                         nil))))
    3 (let [(s1 s2 s3) ...]
        (lazy-seq #(let [s1 (seq s1) s2 (seq s2) s3 (seq s3)]
                     (if (and s1 s2 s3)
                         (cons (f (first s1) (first s2) (first s3))
                               (map f (rest s1) (rest s2) (rest s3)))
                         nil))))
    _ (let [s (list ...)]
        (lazy-seq #(if (every? #(not= nil (seq $)) s)
                       (cons (f (unpack (map first s)))
                             (map f (unpack (map rest s))))
                       nil)))))

(fn map-indexed [f coll]
  "Returns a lazy sequence consisting of the result of applying `f` to 1
and the first item of `coll`, followed by applying `f` to 2 and the second
item in `coll`, etc, until `coll` is exhausted."
  (let [mapi (fn mapi [idx coll]
               (lazy-seq
                #(match (seq coll)
                   s (cons (f idx (first s)) (mapi (+ idx 1) (rest s)))
                   _ nil)))]
    (mapi 1 coll)))

(fn mapcat [f ...]
  "Apply `concat` to the result of calling `map` with `f` and
collections."
  (let [step (fn step [colls]
               (lazy-seq
                #(match (seq colls)
                   s (let [c (first s)]
                       (concat c (step (rest colls))))
                   _ nil)))]
    (step (map f ...))))

(fn take [n coll]
  "Take `n` elements from the collection `coll`.
Returns a lazy sequence of specified amount of elements.

# Examples

Take 10 element from a sequential table

```fennel
(take 10 [1 2 3]) ;=> @seq(1 2 3)
(take 5 [1 2 3 4 5 6 7 8 9 10]) ;=> @seq(1 2 3 4 5)
```"
  (lazy-seq #(if (> n 0)
                 (match (seq coll)
                   s (cons (first s) (take (- n 1) (rest s)))
                   _ nil)
                 nil)))

(fn take-while [pred coll]
  "Take the elements from the collection `coll` until `pred` returns logical
false for any of the elemnts.  Returns a lazy sequence."
  (lazy-seq #(match (seq coll)
               s (let [v (first s)]
                   (if (pred v)
                       (cons v (take-while pred (rest s)))
                       nil))
               _ nil)))

(set drop
     (fn [n coll]
       "Drop `n` elements from collection `coll`, returning a lazy sequence
of remaining elements."
       (let [step (fn step [n coll]
                    (let [s (seq coll)]
                      (if (and (> n 0) s)
                          (step (- n 1) (rest s))
                          s)))]
         (lazy-seq #(step n coll)))))

(fn drop-while [pred coll]
  "Drop the elements from the collection `coll` until `pred` returns logical
false for any of the elemnts.  Returns a lazy sequence."
  (let [step (fn step [pred coll]
               (let [s (seq coll)]
                 (if (and s (pred (first s)))
                     (step pred (rest s))
                     s)))]
    (lazy-seq #(step pred coll))))

(fn drop-last [...]
  "Return a lazy sequence from `coll` without last `n` elements."
  {:fnl/arglist [([]) ([coll]) ([n coll])]}
  (match (select "#" ...)
    0 empty-cons
    1 (drop-last 1 ...)
    _ (let [(n coll) ...]
        (map (fn [x] x) coll (drop n coll)))))

(fn take-last [n coll]
  "Return a sequence of last `n` elements of the `coll`."
  ((fn loop [s lead]
     (if lead
         (loop (next s) (next lead))
         s)) (seq coll) (seq (drop n coll))))

(fn take-nth [n coll]
  "Return a lazy sequence of every `n` item in `coll`."
  (lazy-seq
   #(match (seq coll)
      s (cons (first s) (take-nth n (drop n s))))))

(fn split-at [n coll]
  "Return a table with sequence `coll` being split at `n`"
  [(take n coll) (drop n coll)])

(fn split-with [pred coll]
  "Return a table with sequence `coll` being split with `pred`"
  [(take-while pred coll) (drop-while pred coll)])


(fn filter [pred coll]
  "Returns a lazy sequence of the items in the `coll` for which `pred`
returns logical true."
  (lazy-seq
   #(match (seq coll)
      s (let [x (first s) r (rest s)]
          (if (pred x)
              (cons x (filter pred r))
              (filter pred r)))
      _ nil)))

(fn keep [f coll]
  "Returns a lazy sequence of the non-nil results of calling `f` on the
items of the `coll`."
  (lazy-seq #(match (seq coll)
               s (match (f (first s))
                   x (cons x (keep f (rest s)))
                   nil (keep f (rest s)))
               _ nil)))

(fn keep-indexed [f coll]
  "Returns a lazy sequence of the non-nil results of (f index item) in
the `coll`.  Note, this means false return values will be included.
`f` must be free of side-effects."
  (let [keepi (fn keepi [idx coll]
                (lazy-seq
                 #(match (seq coll)
                    s (let [x (f idx (first s))]
                        (if (= nil x)
                            (keepi (+ 1 idx) (rest s))
                            (cons x (keepi (+ 1 idx) (rest s))))))))]
    (keepi 1 coll)))

(fn remove [pred coll]
  "Returns a lazy sequence of the items in the `coll` without elements
for wich `pred` returns logical true."
  (filter #(not (pred $)) coll))

(fn cycle [coll]
  "Create a lazy infinite sequence of repetitions of the items in the
`coll`."
  (lazy-seq #(concat (seq coll) (cycle coll))))

(fn repeat [x]
  "Takes a value `x` and returns an infinite lazy sequence of this value.

# Examples

``` fennel
(assert-eq 10 (accumulate [res 0
                           _ x (pairs (take 10 (repeat 1)))]
                (+ res x)))
```"
  ((fn step [x] (lazy-seq #(cons x (step x)))) x))

(fn repeatedly [f ...]
  "Takes a function `f` and returns an infinite lazy sequence of
function applications.  Rest arguments are passed to the function."
  (let [args (table-pack ...)
        f (fn [] (f (table-unpack args 1 args.n)))]
    ((fn step [f] (lazy-seq #(cons (f) (step f)))) f)))

(fn iterate [f x]
  "Returns an infinete lazy sequence of x, (f x), (f (f x)) etc."
  (let [x* (f x)]
    (cons x (lazy-seq #(iterate f x*)))))

(fn nthnext [coll n]
  "Returns the nth next of `coll`, (seq coll) when `n` is 0."
  ((fn loop [n xs]
     (match xs
       (where xs* (> n 0)) (loop (- n 1) (next xs*))
       _ xs))
   n (seq coll)))

(fn nthrest [coll n]
  "Returns the nth rest of `coll`, `coll` when `n` is 0."
  ((fn loop [n xs]
     (match (seq xs)
       (where xs* (> n 0)) (loop (- n 1) (rest xs*))
       _ xs))
   n coll))

(fn dorun [s]
  "Realize whole sequence for side effects.

Walks whole sequence, realizing each cell.  Use at your own risk on
infinite sequences."
  (match (seq s)
    s* (dorun (next s*))
    _ nil))

(fn doall [s]
  "Realize whole lazy sequence.

Walks whole sequence, realizing each cell.  Use at your own risk on
infinite sequences."
  (doto s (dorun)))

(fn partition [...]
  "Given a `coll' returns a lazy sequence of lists of `n` items each, at
offsets `step`apart. If `step` is not supplied, defaults to `n`,
i.e. the partitions do not overlap. If a `pad` collection is supplied,
use its elements as necessary to complete last partition upto `n`
items. In case there are not enough padding elements, return a
partition with less than `n` items."
  {:fnl/arglist [([n coll]) ([n step coll]) ([n step pad coll])]}
  (match (select "#" ...)
    2 (let [(n coll) ...]
        (partition n n coll))
    3 (let [(n step coll) ...]
        (lazy-seq
         #(match (seq coll)
            s (let [p (take n s)]
                (if (= n (length* p))
                    (cons p (partition n step (nthrest s step)))
                    nil))
            _ nil)))
    4 (let [(n step pad coll) ...]
        (lazy-seq
         #(match (seq coll)
            s (let [p (take n s)]
                (if (= n (length* p))
                    (cons p (partition n step pad (nthrest s step)))
                    (list (take n (concat p pad)))))
            _ nil)))
    _ (error "wrong amount arguments to 'partition'")))

(fn partition-by [f coll]
  "Applies `f` to each value in `coll`, splitting it each time `f`
   returns a new value.  Returns a lazy seq of partitions."
  (lazy-seq
   #(match (seq coll)
      s (let [v (first s)
              fv (f v)
              run (cons v (take-while #(= fv (f $)) (next s)))]
          (cons run (partition-by f (lazy-seq #(drop (length* run) s))))))))

(fn partition-all [...]
  "Given a `coll' returns a lazy sequence of lists like `partition`, but
may include partitions with fewer than `n' items at the end. Optional
`step' argument is accepted similarly to `partition`."
  {:fnl/arglist [([n coll]) ([n step coll])]}
  (match (select "#" ...)
    2 (let [(n coll) ...]
        (partition-all n n coll))
    3 (let [(n step coll) ...]
        (lazy-seq
         #(match (seq coll)
            s (let [p (take n s)]
                (cons p (partition-all n step (nthrest s step))))
            _ nil)))
    _ (error "wrong amount arguments to 'partition-all'")))

(fn reductions [...]
  "Returns a lazy seq of the intermediate values of the reduction (as
per reduce) of `coll` by `f`, starting with `init`."
  {:fnl/arglist [([f coll]) ([f init coll])]}
  (match (select "#" ...)
    2 (let [(f coll) ...]
        (lazy-seq
         #(match (seq coll)
            s (reductions f (first s) (rest s))
            _ (list (f)))))
    3 (let [(f init coll) ...]
        (cons init
              (lazy-seq
               #(match (seq coll)
                  s (reductions f (f init (first s)) (rest s))))))
    _ (error "wrong amount arguments to 'reductions'")))

(fn contains? [coll elt]
  "Test if `elt` is in the `coll`.  May be a linear search depending on the type of the collection."
  (match (gettype coll)
    :table (match (kind coll)
             :seq (accumulate [res false _ v (ipairs* coll) :until res]
                    (if (= elt v) true false))
             :assoc (if (. coll elt) true false))
    _ ((fn loop [coll]
         (match (seq coll)
           s (if (= elt (first s))
                 true
                 (loop (rest s)))
           nil false)) coll)))

(fn distinct [coll]
  "Returns a lazy sequence of the elements of the `coll` without
duplicates.  Comparison is done by equality."
  ((fn step [xs seen]
     (let [loop (fn loop [[f &as xs] seen]
                  (match (seq xs)
                    s (if (. seen f)
                          (loop (rest s) seen)
                          (cons f (step (rest s) (doto seen (tset f true)))))
                    _ nil))]
       (lazy-seq #(loop xs seen))))
   coll {}))

(fn inf-range [x step]
  ;; infinite lazy range builder
  (lazy-seq #(cons x (inf-range (+ x step) step))))

(fn fix-range [x end step]
  ;; fixed lazy range builder
  (lazy-seq #(if (or (and (>= step 0) (< x end))
                     (and (< step 0) (> x end)))
                 (cons x (fix-range (+ x step) end step))
                 (and (= step 0) (not= x end))
                 (cons x (fix-range x end step))
                 nil)))

(fn range [...]
  "Create a possibly infinite sequence of numbers.

If `end' argument is specified, returns a finite sequence from 0 up to
this argument.  If two arguments `start' and `end' were specified,
returns a finite sequence from lower to, but not included, upper
bound.  A third argument `step' provides a step interval.

If no arguments were specified, returns an infinite sequence starting at 0.

# Examples

Various ranges:

```fennel
(range 10) ;; => @seq(0 1 2 3 4 5 6 7 8 9)
(range 4 8) ;; => @seq(4 5 6 7)
(range 0 -5 -2) ;; => @seq(0 -2 -4)
(take 10 (range)) ;; => @seq(0 1 2 3 4 5 6 7 8 9)
```"
  {:fnl/arglist [([]) ([end]) ([start end]) ([start end step])]}
  (match (select "#" ...)
    0 (inf-range 0 1)
    1 (let [(end) ...]
        (fix-range 0 end 1))
    2 (let [(x end) ...]
        (fix-range x end 1))
    _ (fix-range ...)))

(fn realized? [s]
  "Check if sequence's first element is realized."
  (match (gettype s)
    :lazy-cons false
    :empty-cons true
    :cons true
    _ (error (: "expected a sequence, got: %s" :format _))))

(fn line-seq [file]
  "Accepts a `file` handle, and creates a lazy sequence of lines using
`lines` metamethod.

# Examples

Lazy sequence of file lines may seem similar to an iterator over a
file, but the main difference is that sequence can be shared onve
realized, and iterator can't.  Lazy sequence can be consumed in
iterator style with the `doseq` macro.

Bear in mind, that since the sequence is lazy it should be realized or
truncated before the file is closed:

```fennel
(let [lines (with-open [f (io.open \"init.fnl\" :r)]
              (line-seq f))]
  ;; this errors because only first line was realized, but the file
  ;; was closed before the rest of lines were cached
  (assert-not (pcall next lines)))
```

Sequence is realized with `doall` before file was closed and can be shared:

``` fennel
(let [lines (with-open [f (io.open \"init.fnl\" :r)]
              (doall (line-seq f)))]
  (assert-is (pcall next lines)))
```

Infinite files can't be fully realized, but can be partially realized
with `take`:

``` fennel
(let [lines (with-open [f (io.open \"/dev/urandom\" :r)]
              (doall (take 3 (line-seq f))))]
  (assert-is (pcall next lines)))
```"
  (let [next-line (file:lines)]
    ((fn step [f]
       (let [line (f)]
         (if (= :string (type line))
             (cons line (lazy-seq #(step f)))
             nil)))
     next-line)))

(fn tree-seq [branch? children root]
  "Returns a lazy sequence of the nodes in a tree, via a depth-first walk.

`branch?` must be a function of one arg that returns true if passed a
node that can have children (but may not).  `children` must be a
function of one arg that returns a sequence of the children.  Will
only be called on nodes for which `branch?` returns true.  `root` is
the root node of the tree.

# Examples

For the given tree `[\"A\" [\"B\" [\"D\"] [\"E\"]] [\"C\" [\"F\"]]]`:

        A
       / \\
      B   C
     / \\   \\
    D   E   F

Calling `tree-seq` with `next' as the `branch?` and `rest' as the
`children` returns a flat representation of a tree:

``` fennel
(assert-eq (map first (tree-seq next rest [\"A\" [\"B\" [\"D\"] [\"E\"]] [\"C\" [\"F\"]]]))
           [\"A\" \"B\" \"D\" \"E\" \"C\" \"F\"])
```"
  ((fn walk [node]
     (lazy-seq
      #(cons node
             (if (branch? node)
                 (mapcat walk (children node))))))
   root))

(fn interleave [...]
  "Returns a lazy sequence of the first item in each sequence, then the
second one, until any sequence exhausts."
  {:fnl/arglist [([]) ([s]) ([s1 s2]) ([s1 s2 & ss])]}
  (match (values (select "#" ...) ...)
    (0) empty-cons
    (1 ?s) (lazy-seq #?s)
    (2 ?s1 ?s2)
    (lazy-seq #(let [s1 (seq ?s1)
                     s2 (seq ?s2)]
                 (if (and s1 s2)
                     (cons (first s1)
                           (cons (first s2)
                                 (interleave (rest s1) (rest s2))))
                     nil)))
    (_)
    (let [cols (list ...)]
      (lazy-seq #(let [seqs (map seq cols)]
                   (if (every? #(not= nil (seq $)) seqs)
                       (concat (map first seqs)
                               (interleave (unpack (map rest seqs))))))))))

(fn interpose [separator coll]
  "Returns a lazy sequence of the elements of `coll` separated by `separator`."
  (drop 1 (interleave (repeat separator) coll)))

(fn keys [t]
  "Return a sequence of keys in table `t`."
  (assert (= :assoc (kind t)) "expected an associative table")
  (map #(. $ 1) t))

(fn vals [t]
  "Return a sequence of values in table `t`."
  (assert (= :assoc (kind t)) "expected an associative table")
  (map #(. $ 2) t))

(fn zipmap [keys vals]
  "Return an associative table with the `keys` mapped to the
corresponding `vals`."
  (let [t {}]
    ((fn loop [s1 s2]
       (when (and s1 s2)
         (tset t (first s1) (first s2))
         (loop (next s1) (next s2))))
     (seq keys) (seq vals))
    t))

(local {: reduced : reduced?} (require :reduced))

(fn reduce [f ...]
  "`f` should be a function of 2 arguments. If `val` is not supplied,
returns the result of applying `f` to the first 2 items in `coll`,
then applying `f` to that result and the 3rd item, etc. If `coll`
contains no items, f must accept no arguments as well, and reduce
returns the result of calling `f` with no arguments.  If `coll` has
only 1 item, it is returned and `f` is not called.  If `val` is
supplied, returns the result of applying `f` to `val` and the first
item in `coll`, then applying `f` to that result and the 2nd item,
etc. If `coll` contains no items, returns `val` and `f` is not
called. Early termination is supported via `reduced`.

# Examples

``` fennel
(fn add [...]
  \"Addition function with multiple arities.\"
  (match (values (select \"#\" ...) ...)
    (0) 0
    (1 ?a) ?a
    (2 ?a ?b) (+ ?a ?b)
    (3 ?a ?b) (add (+ ?a ?b) (select 3 ...))))
;; no initial value
(assert-eq 10 (reduce add [1 2 3 4]))
;; initial value
(assert-eq 10 (reduce add 1 [2 3 4]))
;; empty collection - function is called with 0 args
(assert-eq 0 (reduce add []))
(assert-eq 10.3 (reduce math.floor 10.3 []))
;; collection with a single element doesn't call a function unless the
;; initial value is supplied
(assert-eq 10.3 (reduce math.floor [10.3]))
(assert-eq 7 (reduce add 3 [4]))
```"
  {:fnl/arglist [([f coll]) ([f val coll])]}
  (match (values (select "#" ...) ...)
    0 (error "expected a collection")
    (1 ?coll)
    (match (count ?coll)
      0 (f)
      1 (first ?coll)
      _ (reduce f (first ?coll) (rest ?coll)))
    (2 ?val ?coll)
    (match (seq ?coll)
      coll (do (var done? false)
               (accumulate [res ?val
                            _ v (pairs* coll)
                            :until done?]
                 (let [res (f res v)]
                   (if (reduced? res)
                       (do (set done? true)
                           (res:unbox))
                       res))))
      _ ?val)))

{: first                                ; tested
 : rest                                 ; tested
 : nthrest                              ; tested
 : next                                 ; tested
 : nthnext                              ; tested
 : cons                                 ; tested
 : seq                                  ; tested
 : rseq                                 ; tested
 : seq?                                 ; tested
 : empty?                               ; tested
 : lazy-seq                             ; tested
 : list                                 ; tested
 : list*                                ; tested
 : every?                               ; tested
 : some?                                ; tested
 : pack                                 ; tested
 : unpack                               ; tested
 : count                                ; tested
 : concat                               ; tested
 : map                                  ; tested
 : map-indexed                          ; tested
 : mapcat                               ; tested
 : take                                 ; tested
 : take-while                           ; tested
 : take-last                            ; tested
 : take-nth                             ; tested
 : drop                                 ; tested
 : drop-while                           ; tested
 : drop-last                            ; tested
 : remove                               ; tested
 : split-at                             ; tested
 : split-with                           ; tested
 : partition                            ; tested
 : partition-by                         ; tested
 : partition-all                        ; tested
 : filter                               ; tested
 : keep                                 ; tested
 : keep-indexed                         ; tested
 : contains?                            ; tested
 : distinct                             ; tested
 : cycle                                ; tested
 : repeat                               ; tested
 : repeatedly                           ; tested
 : reductions                           ; tested
 : iterate                              ; tested
 : range                                ; tested
 : realized?                            ; tested
 : dorun                                ; tested
 : doall                                ; tested
 : line-seq                             ; tested
 : tree-seq                             ; tested
 : reverse                              ; tested
 : interleave                           ; tested
 : interpose                            ; tested
 : keys                                 ; tested
 : vals                                 ; tested
 : zipmap                               ; tested
 : reduce                               ; tested
 : reduced                              ; tested
 : reduced?                             ; tested
 }
        )))

;;; cljlib

(eval-compiler
  (local lib-name (or ... :cljlib))

  (fn string? [x]
    (= :string (type x)))

  (fn has? [tbl sym]
    ;; searches for the given symbol in a table.
    (var has false)
    (each [_ elt (ipairs tbl) :until has]
      (set has (= sym elt)))
    has)

  ;; ns

  (local cljlib-namespaces
    {}
    ;; A map of files and their respective namespaces.  Each entry is a
    ;; filename followed by a table with two keys: `:current` and
    ;; `:known`.  The second one holds all namespaces that were defined
    ;; for the file via the `ns` macro, and thus are available to switch
    ;; with the `in-ns` macro. The `:current` key represents currently
    ;; active namespace that is used for binding via the `def` macro and
    ;; its derivatives.
    )

  (fn current-file [ast]
    (. (ast-source ast) :filename))

  (fn create-ns [name]
    (let [file (current-file name)]
      (when (not (. cljlib-namespaces file))
        (tset cljlib-namespaces file {:known {}}))
      (tset cljlib-namespaces file :current name)
      (tset cljlib-namespaces file :known (tostring name) true))
    `(setmetatable
      {}
      {:__name "namespace"
       :__fennelview #(do ,(: "#<namespace: %s>" :format (tostring name)))}))

  (fn known-ns? [name]
    (let [file (current-file name)]
      (?. cljlib-namespaces file :known (tostring name))))

  (fn current-ns [ast]
    (?. cljlib-namespaces (current-file ast) :current))

  (fn in-ns [name]
    "Sets the compile-time variable `cljlib-namespaces` to the given `name`.
Affects such macros as `def`, `defn`, which will bind names to the
specified namespace.

# Examples
Creating several namespaces in the file, and defining functions in each:

``` fennel
(ns a)
(defn f [] \"f from a\")
(ns b)
(defn f [] \"f from b\")
(in-ns a)
(defn g [] \"g from a\")
(in-ns b)
(defn g [] \"g from b\")

(assert-eq (a.f) \"f from a\")
(assert-eq (b.f) \"f from b\")
(assert-eq (a.g) \"g from a\")
(assert-eq (b.g) \"g from b\")
```

Note, switching namespaces in the REPL doesn't affect non-namespaced
local bindings.  In other words, when defining a local with `def`, a
bot a local binding and a namespaced binding are created, and
switching current namespace won't change the local binding:

``` fennel :skip-test
>> (ns foo)
nil
>> (def x 42)
nil
>> (ns bar)
nil
>> (def x 1337)
nil
>> (in-ns foo)
#<namespace: foo>
>> x ; user might have expected to see 42 here
1337
>> foo.x
42
>> bar.x
1337
```

Sadly, Fennel itself has no support for namespace switching in REPL,
so this feature can be only partially emulated by the cljlib library.
"
    (assert-compile (known-ns? name)
                    (: "no such namespace: %s" :format (tostring name))
                    name)
    (tset cljlib-namespaces (current-file name) :current name)
    name)

  (fn ns [name commentary requirements]
    "Namespace declaration macro.
Accepts the `name` of the generated namespace, and creates a local
variable with this name holding a table. Optionally accepts
`commentary` describing what namespace is about and a `requirements`
spec, specifying what libraries should be required.

The `requirements` spec is a list that consists of vectors, specifying
library name and a possible alias or a vector of names to refer to
without a prefix:

``` fennel :skip-test
(ns some-namespace
  \"Description of the some-namespace.\"
  (:require [some.lib]
            [some.other.lib :as lib2]
            [another.lib :refer [foo bar baz]]))

(defn inc [x] (+ x 1))
```

Which is equivalent to:

``` fennel :skip-test
(local some-namespace {})
(local lib (require :some.lib))
(local lib2 (require :some.other.lib))
(local {:bar bar :baz baz :foo foo} (require :another.lib))
(comment \"Description of the some-namespace.\")
```

Note that when no `:as` alias is given, the library will be named
after the innermost part of the require path, i.e. `some.lib` is
transformed to `lib`.

See `in-ns` on how to switch namespaces."
    (let [bind-table [name]
          require-table [(create-ns name)]
          requirements (if (string? commentary)
                           requirements
                           commentary)]
      (match requirements
        [:require & requires]
        (each [_ spec (ipairs requires)]
          (match spec
            (where (or [module :as alias :refer names]
                       [module :refer names :as alias]))
            (do (table.insert bind-table (collect [_ name (ipairs names) :into {'&as alias}]
                                           (values (tostring name) name)))
                (table.insert require-table `(require ,(tostring module))))
            [module :as alias]
            (do (table.insert bind-table alias)
                (table.insert require-table `(require ,(tostring module))))
            [module :refer names]
            (do (table.insert bind-table (collect [_ name (ipairs names)]
                                           (values (tostring name) name)))
                (table.insert require-table `(require ,(tostring module))))
            [module]
            (do (->> (string.gsub (tostring module) ".+%.(.-)$" "%1")
                     (pick-values 1)
                     sym
                     (table.insert bind-table))
                (table.insert require-table `(require ,(tostring module))))
            _ (assert-compile false "wrong require syntax" name)))
        nil nil
        _ (assert-compile false "wrong require syntax" name))
      (if (string? commentary)
          `(local ,bind-table
             (values ,require-table (comment ,commentary)))
          `(local ,bind-table ,require-table))))

  ;; def

  (fn def [...]
    "Name binding macro similar to `local` but acts in terms of current
namespace set with the `ns` macro, unless `:private` was passed before
the binding name. Accepts the `name` to be bound and the `initializer`
expression. `meta` can be either an associative table where keys are
strings, or a string representing a key from the table. If a sole
string is given, its value is set to `true` in the meta table."
    {:fnl/arglist [([name initializer]) ([meta name initializer])]}
    (match [...]
      (where (or [:private name val]
                 [{:private true} name val]))
      `(local ,name ,val)
      [name val]
      (let [namespace (current-ns name)]
        (if (in-scope? namespace)
            `(local ,name
               (let [v# ,val]
                 (tset ,namespace ,(tostring name) v#)
                 v#))
            `(local ,name ,val)))))

  ;; defn

  (local errors
    {:vararg "... is't allowed in the arglist, use & destructuring"
     :same-arity "Can't have 2 overloads with same arity"
     :arity-order "Overloads must be sorted by arities"
     :amp-arity "Variadic overload must be the last overload"
     :extra-rest-args "Only one argument allowed after &"
     :wrong-arg-amount "Wrong number of args (%s) passed to %s"
     :extra-amp "Can't have more than 1 variadic overload"})

  (fn first [[x]] x)
  (fn rest [[_ & xs]] xs)
  (fn vfirst [x] x)
  (fn vrest [_ ...] ...)

  (fn length* [arglist]
    ;; Gets "length" of variadic arglist, stopping at first & plus 1 arg.
    ;; Additionally checks whether there are more than one arg after &.
    (var (l amp? n) (values 0 false nil))
    (each [i arg (ipairs arglist) :until amp?]
      (if (= arg '&)
          (set (amp? n) (values true i))
          (set l (+ l 1))))
    (when n
      (assert-compile (= (length arglist) (+ n 1))
                      errors.extra-rest-args
                      (. arglist (length arglist))))
    (if amp? (+ l 1) l))

  (fn check-arglists [arglists]
    ;; performs a check that arglists are ordered correctly, and that
    ;; only one of multiarity arglists has the & symbol, additionally
    ;; checking for a presence of the multiple-values symbol.
    (var (size amp?) (values -1 false))
    (each [_ [arglist] (ipairs arglists)]
      (assert-compile (not (has? arglist '...)) errors.vararg arglist)
      (let [len (length* arglist)]
        (assert-compile (not= size len) errors.same-arity arglist)
        (assert-compile (< size len) errors.arity-order arglist)
        (assert-compile (not amp?) (if (has? arglist '&)
                                       errors.extra-amp
                                       errors.amp-arity) arglist)
        (set size len)
        (set amp? (has? arglist '&)))))

  (fn with-immutable-rest [arglist body]
    `(let [core# (require ,lib-name)
           ,arglist (core#.list ...)]
       ,(unpack body)))

  (fn add-missing-arities! [arglists name]
    "Adds missing arity overloads for given `arglists`.
For example, given the [[[a] body] [[a b c] body]], will generate
[[[] error]
 [[a] body]
 [[arg_1_ arg_2_] error]
 [[a b c] body]]

Because inital arglist didn't specify arities of 0 and 2."
    (for [i (- (length* arglists) 1) 1 -1]
      (let [current-args (first (. arglists i))
            current-len (length* current-args)
            next-args (first (. arglists (+ i 1)))
            next-len (length* next-args)
            next-len (if (has? next-args '&) (- next-len 1) next-len)]
        (when (not= (+ current-len 1) next-len)
          (for [len (- next-len 1) (+ current-len 1) -1]
            (table.insert arglists (+ i 1) [(fcollect [i 1 len :into {:fake true}] (gensym :arg))
                                            `(error (: ,errors.wrong-arg-amount :format ,len ,(tostring name)))])))))
    (while (not= 0 (length* (first (first arglists))))
      (let [len (- (length* (first (first arglists))) 1)]
        (table.insert arglists 1 [(fcollect [i 1 len :into {:fake true}] (gensym :arg))
                                  `(error (: ,errors.wrong-arg-amount :format ,len ,(tostring name)))]))))

  ;; TODO: implement pre-post conditions
  (fn gen-match-fn [name doc arglists]
    ;; automated multi-arity dispatch generator
    (check-arglists arglists)
    (add-missing-arities! arglists name)
    (let [match-body `(match (select :# ...))]
      (var variadic? false)
      (each [_ [arglist & body] (ipairs arglists)]
        (table.insert match-body (if (has? arglist '&)
                                     (do (set variadic? true) (sym :_))
                                     (length arglist)))
        (table.insert match-body (if variadic?
                                     (with-immutable-rest arglist body)
                                     (if (and (> (length arglist) 0) (not arglist.fake))
                                         `(let [(,(unpack arglist)) (values ...)]
                                            ,(if (> (length body) 0)
                                                 (unpack body)
                                                 'nil))
                                         `(do ,(unpack body))))))
      (when (not variadic?)
        (table.insert match-body (sym :_))
        (table.insert match-body
                      `(error (: ,errors.wrong-arg-amount :format ,(sym :_) ,(tostring name)))))
      `(fn ,name [...]
         {:fnl/docstring ,doc
          :fnl/arglist ,(icollect [_ [arglist] (ipairs arglists)]
                          (when (not arglist.fake)
                            (list (sequence (unpack arglist)))))}
         ,match-body)))

  ;; TODO: implement pre-post conditions
  (fn gen-fn [name doc arglist _pre-post body]
    (check-arglists [[arglist]])
    `(fn ,name [...]
       {:fnl/docstring ,doc
        :fnl/arglist ,(sequence arglist)}
       ,(if (has? arglist '&)
            (with-immutable-rest arglist [body])
            `(let ,(if (> (length arglist) 0)
                       `[(,(unpack arglist)) (values ...)]
                       `[])
                  (let [cnt# (select "#" ...)]
                    (when (not= ,(length arglist) cnt#)
                      (error (: ,errors.wrong-arg-amount :format cnt# ,(tostring name)))))
                  ,body))))

  (fn fn* [...]
    "Clojure-inspired `fn' macro for defining functions.
Accepts an optional `name` and `docstring?`, followed by the binding
list containing function's `params*`. The `body` is wrapped in an
implicit `do`.  The `doc-string?` argument specifies an optional
documentation for the function.  Supports multi-arity dispatching via
the following syntax:

(fn* optional-name
  optional-docstring
  ([arity1] body1)
  ([other arity2] body2))

Accepts `pre-post?` conditions in a form of a table after argument
list:

(fn* optional-name
  optional-docstring
  [arg1 arg2]
  {:pre  [(check1 arg1 arg2) (check2 arg1)]
   :post [(check1 $) ... (checkN $)]}
  body)

The same syntax applies to multi-arity version.

(pre- and post-checks are not yet implemented)"
    {:fnl/arglist [([name doc-string? [params*] pre-post? body])
                   ([name doc-string? ([params*] pre-post? body)+])]}
    (let [{: name? : doc? : args : pre-post? : body : multi-arity?}
          ;; descent into maddness
          (match (values ...)
            (where (name docstring [[] &as arity])
                   (and (sym? name)
                        (string? docstring)
                        (list? arity)))
            {:pat '(fn* foo "bar" ([baz]) ...)
             :name? name
             :doc? docstring
             :args [arity (select 4 ...)]
             :multi-arity? true}
            (where (name [[] &as arity])
                   (and (sym? name)
                        (list? arity)))
            {:pat '(fn* foo ([baz]) ...)
             :name? name
             :args [arity (select 3 ...)]
             :multi-arity? true}
            (where (docstring [[] &as arity])
                   (and (string? docstring)
                        (list? arity)))
            {:pat '(fn* "bar" ([baz]) ...)
             :name? (gensym :fn)
             :doc? docstring
             :args [arity (select 3 ...)]
             :multi-arity? true}
            (where ([[] &as arity])
                   (list? arity))
            {:pat '(fn* ([baz]) ...)
             :name? (gensym :fn)
             :args [arity (select 2 ...)]
             :multi-arity? true}
            (where (name docstring args {&as pre-post})
                   (and (sym? name)
                        (string? docstring)
                        (sequence? args)
                        (or (not= nil pre-post.pre)
                            (not= nil pre-post.post))))
            {:pat '(fn* foo "foo" [baz] {:pre qux :post quux} ...)
             :name? name
             :doc? docstring
             :args args
             :pre-post? pre-post
             :body [(select 5 ...)]}
            (where (name docstring args)
                   (and (sym? name)
                        (string? docstring)
                        (sequence? args)))
            {:pat '(fn* foo "foo" [baz] ...)
             :name? name
             :doc? docstring
             :args args
             :body [(select 4 ...)]}
            (where (name args {&as pre-post})
                   (and (sym? name)
                        (sequence? args)
                        (or (not= nil pre-post.pre)
                            (not= nil pre-post.post))))
            {:pat '(fn* foo [baz] {:pre qux :post quux} ...)
             :name? name
             :args args
             :pre-post? pre-post
             :body [(select 4 ...)]}
            (where (name args)
                   (and (sym? name) (sequence? args)))
            {:pat '(fn* foo [baz] ...)
             :name? name
             :args args
             :body [(select 3 ...)]}
            (where (docstring args {&as pre-post})
                   (and (string? docstring)
                        (sequence? args)
                        (or (not= nil pre-post.pre)
                            (not= nil pre-post.post))))
            {:pat '(fn* "bar" [baz] {:pre qux :post quux} ...)
             :name? (gensym :fn)
             :doc? docstring
             :args args
             :pre-post? pre-post
             :body [(select 4 ...)]}
            (where (docstring args)
                   (and (string? docstring)
                        (sequence? args)))
            {:pat '(fn* "bar" [baz] ...)
             :name? (gensym :fn)
             :doc? docstring
             :args args
             :body [(select 3 ...)]}
            (where (args {&as pre-post})
                   (and (sequence? args)
                        (or (not= nil pre-post.pre)
                            (not= nil pre-post.post))))
            {:pat '(fn* [baz] {:pre qux :post quux} ...)
             :name? (gensym :fn)
             :args args
             :pre-post? pre-post
             :body [(select 3 ...)]}
            (where (args)
                   (sequence? args))
            {:pat '(fn* [baz] ...)
             :name? (gensym :fn)
             :args args
             :body [(select 2 ...)]}
            _ (assert-compile (string.format
                               "Expression %s didn't match any pattern."
                               (view `(fn* ,...)))))]
      (if multi-arity?
          (gen-match-fn name? doc? args)
          (gen-fn name? doc? args pre-post? `(do ,(unpack body))))))

  (fn defn [name ...]
    "Same as `(def name (fn* name docstring? [params*] pre-post? exprs*))`
or `(def name (fn* name docstring? ([params*] pre-post? exprs*)+))`
with any doc-string or attrs added to the function metadata.  Accepts
`name` which will be used to refer to a function in the current
namespace, and optional `doc-string?`, a vector of function's
`params*`, `pre-post?` conditions, and the `body` of the function.
The body is wrapped in an implicit do.  See `fn*` for more info."
    {:fnl/arglist [([name doc-string? [params*] pre-post? body])
                   ([name doc-string? ([params*] pre-post? body)+])]}
    (assert-compile (sym? name) "expected a function name, use `fn*` for anonymous functions" name)
    (def name (fn* name ...)))

  (fn defn- [name ...]
    "Same as `(def :private name (fn* name docstring? [params*] pre-post?
exprs*))` or `(def :private name (fn* name docstring? ([params*]
pre-post?  exprs*)+))` with any doc-string or attrs added to the
function metadata. Accepts `name` which will be used to refer to a
function, and optional `doc-string?`, a vector of function's
`params*`, `pre-post?` conditions, and the `body` of the function.
The body is wrapped in an implicit do. See `fn*` for more info."
    {:fnl/arglist [([name doc-string? [params*] pre-post? body])
                   ([name doc-string? ([params*] pre-post? body)+])]}
    (assert-compile (sym? name) "expected a function name, use `fn*` for anonymous functions" name)
    (def :private name (fn* name ...)))

  ;; Time

  (fn time [expr]
    "Measure the CPU time spent executing `expr`."
    `(let [c# os.clock
           pack# #(doto [$...] (tset :n (select "#" $...)))
           s# (c#)
           res# (pack# ,expr)
           e# (c#)]
       (print (.. "Elapsed time: " (* (- e# s#) 1000) " msecs"))
       ((or table.unpack _G.unpack) res# 1 res#.n)))

  ;; let variants

  (fn when-let [[name test] ...]
    "When `test` is logical `true`, evaluates the `body` with `name` bound
to the value of `test`."
    {:fnl/arglist [[name test] & body]}
    `(let [val# ,test]
       (if val#
           (let [,name val#]
             ,...))))

  (fn if-let [[name test] if-branch else-branch ...]
    "When `test` is logical `true`, evaluates the `if-branch` with `name`
bound to the value of `test`. Otherwise, evaluates the `else-branch`"
    {:fnl/arglist [[name test] if-branch else-branch]}
    (assert-compile (= 0 (select "#" ...)) "too many arguments to if-let" ...)
    `(let [val# ,test]
       (if val#
           (let [,name val#]
             ,if-branch)
           ,else-branch)))

  (fn when-some [[name test] ...]
    "When `test` is not `nil`, evaluates the `body` with `name` bound to
the value of `test`."
    {:fnl/arglist [[name test] & body]}
    `(let [val# ,test]
       (if (not= nil val#)
           (let [,name val#]
             ,...))))

  (fn if-some [[name test] if-branch else-branch ...]
    "When `test` is not `nil`, evaluates the `if-branch` with `name`
bound to the value of `test`. Otherwise, evaluates the `else-branch`"
    {:fnl/arglist [[name test] if-branch else-branch]}
    (assert-compile (= 0 (select "#" ...)) "too many arguments to if-some" ...)
    `(let [val# ,test]
       (if (not= nil val#)
           (let [,name val#]
             ,if-branch)
           ,else-branch)))

  ;; Multimethods

  (fn defmulti [...]
    "Create multifunction `name' with runtime dispatching based on results
from `dispatch-fn'.  Returns a proxy table with `__call` metamethod,
that calls `dispatch-fn' on its arguments.  Amount of arguments
passed, should be the same as accepted by `dispatch-fn'.  Looks for
multimethod based on result from `dispatch-fn'.

Accepts optional `docstring?', and `options*' arguments, where
`options*' is a sequence of key value pairs representing additional
attributes.  Supported options:

`:default` - the default dispatch value, defaults to `:default`.

By default, multifunction has no multimethods, see
`defmethod' on how to add one."
    {:fnl/arglist [name docstring? dispatch-fn options*]}
    (let [[name & options] (if (> (select :# ...) 0) [...]
                               (error "wrong argument amount for defmulti"))
          docstring (if (string? (first options)) (first options))
          options (if docstring (rest options) options)
          dispatch-fn (first options)
          options* (rest options)]
      (assert (= (% (length options*) 2) 0) "wrong argument amount for defmulti")
      (let [options {}]
        (for [i 1 (length options*) 2]
          (tset options (. options* i) (. options* (+ i 1))))
        (def name
          `(let [pairs# (fn [t#]
                          (match (getmetatable t#)
                            {:__pairs p#} (p# t#)
                            ,(sym :_) (pairs t#)))
                 {:eq eq#} (require ,lib-name)]
             (setmetatable
              {}
              {:__index (fn [t# key#]
                          (accumulate [res# nil
                                       k# v# (pairs# t#)
                                       :until res#]
                            (when (eq# k# key#)
                              v#)))
               :__call
               (fn [t# ...]
                 ,docstring
                 (let [dispatch-value# (,dispatch-fn ...)
                       view# (match (pcall require :fennel)
                               (true fennel#) #(fennel#.view $ {:one-line true})
                               ,(sym :_) tostring)]
                   ((or (. t# dispatch-value#)
                        (. t# (or (. ,options :default) :default))
                        (error (.. "No method in multimethod '"
                                   ,(tostring name)
                                   "' for dispatch value: "
                                   (view# dispatch-value#))
                               2)) ...)))
               :__name (.. "multifn " ,(tostring name))
               :__fennelview tostring
               :cljlib/type :multifn}))))))

  (fn defmethod [multifn dispatch-val ...]
    "Attach new method to multi-function dispatch value. Accepts the
`multi-fn' as its first argument, the `dispatch-value' as second, and
`fnspec' - a function tail starting from argument list, followed by
function body as in `fn*'.

# Examples
Here are some examples how multimethods can be used.

## Factorial example
Key idea here is that multimethods can call itself with different
values, and will dispatch correctly.  Here, `fac' recursively calls
itself with less and less number until it reaches `0` and dispatches
to another multimethod:

``` fennel
(ns test)

(defmulti fac (fn [x] x))

(defmethod fac 0 [_] 1)
(defmethod fac :default [x] (* x (fac (- x 1))))

(assert-eq (fac 4) 24)
```

`:default` is a special method which gets called when no other methods
were found for given dispatch value.

## Multi-arity dispatching
Multi-arity function tails are also supported:

``` fennel
(ns test)

(defmulti foo (fn* ([x] [x]) ([x y] [x y])))

(defmethod foo [10] [_] (print \"I knew I'll get 10\"))
(defmethod foo [10 20] [_ _] (print \"I knew I'll get both 10 and 20\"))
(defmethod foo :default ([x] (print (.. \"Umm, got\" x)))
                        ([x y] (print (.. \"Umm, got both \" x \" and \" y))))
```

Calling `(foo 10)` will print `\"I knew I'll get 10\"`, and calling
`(foo 10 20)` will print `\"I knew I'll get both 10 and 20\"`.
However, calling `foo' with any other numbers will default either to
`\"Umm, got x\"` message, when called with single value, and `\"Umm, got
both x and y\"` when calling with two values.

## Dispatching on object's type
We can dispatch based on types the same way we dispatch on values.
For example, here's a naive conversion from Fennel's notation for
tables to Lua's one:

``` fennel
(ns test)

(defmulti to-lua-str (fn [x] (type x)))

(defmethod to-lua-str :number [x] (tostring x))
(defmethod to-lua-str :table [x]
  (let [res []]
    (each [k v (pairs x)]
      (table.insert res (.. \"[\" (to-lua-str k) \"] = \" (to-lua-str v))))
    (.. \"{\" (table.concat res \", \") \"}\")))
(defmethod to-lua-str :string [x] (.. \"\\\"\" x \"\\\"\"))
(defmethod to-lua-str :default [x] (tostring x))

(assert-eq (to-lua-str {:a {:b 10}}) \"{[\\\"a\\\"] = {[\\\"b\\\"] = 10}}\")

(assert-eq (to-lua-str [:a :b :c [:d {:e :f}]])
           \"{[1] = \\\"a\\\", [2] = \\\"b\\\", [3] = \\\"c\\\", [4] = {[1] = \\\"d\\\", [2] = {[\\\"e\\\"] = \\\"f\\\"}}}\")
```

And if we call it on some table, we'll get a valid Lua table, which we
can then reformat as we want and use in Lua.

All of this can be done with functions, and single entry point
function, that uses if statement and branches on the type, however one
of the additional features of multimethods, is that separate libraries
can extend such multimethod by adding additional claues to it without
needing to patch the source of the function.  For example later on
support for userdata or coroutines can be added to `to-lua-str'
function as a separate multimethods for respective types."
    {:fnl/arglist [multi-fn dispatch-value fnspec]}
    (when (= (select :# ...) 0) (error "wrong argument amount for defmethod"))
    `(let [dispatch# ,dispatch-val
           multifn# ,multifn]
       (and (not (. multifn# dispatch#))
            (doto multifn#
              (tset dispatch# ,(fn* ...))))))

  ;; loop

  (fn assert-tail [tail-sym body]
    "Asserts that the passed in tail-sym function is a tail-call position of the
passed-in body.

Throws an error if it is in a position to be returned or if the function is
situated to be called from a position other than the tail of the passed-in
body."
    (fn last-arg? [form i]
      (= (- (length form) 1) i))

    ;; Tail in special forms are (After macroexpanding):
    ;;
    ;; - Every second form in an if, or the last form
    ;; (if ... (sym ...) (sym ...))
    ;;
    ;; - Last form in a let
    ;; (let [] (sym ...))
    ;;
    ;; - Last form in a do
    ;; (do ... (sym ...))
    ;;
    ;; Anything else fails the assert
    (fn path-tail? [op i form]
      (if (= op 'if) (and (not= 1 i) (or (last-arg? form i) (= 0 (% i 2))))
          (= op 'let) (last-arg? form i)
          (= op 'do) (last-arg? form i)
          false))

    ;; Check the current form for the tail-sym, and if it's in a bad
    ;; place, error out. If we run into other forms, we recurse with the
    ;; comprehension if this is the tail form or not
    (fn walk [body ok]
      (let [[op & operands] body]
        (if (list? op) (walk op true)
            (assert-compile (not (and (= tail-sym op) (not ok)))
                            (.. (tostring tail-sym) " must be in tail position")
                            op)
            (each [i v (ipairs operands)]
              (if (list? v) (walk v (and ok (path-tail? op i body)))
                  (assert-compile (not= tail-sym v)
                                  (.. (tostring tail-sym) " must not be passed")
                                  v))))))

    (walk `(do ,(macroexpand body)) true))


  (fn loop [binding-vec ...]
    "Recursive loop macro.

Similar to `let`, but binds a special `recur` call that will reassign
the values of the `binding-vec` and restart the loop `body*`.  Unlike
`let`, doesn't support multiple-value destructuring.

The first argument is a binding table with alternating symbols (or destructure
forms), and the values to bind to them.

For example:

``` fennel
(loop [[first & rest] [1 2 3 4 5]
       i 0]
  (if (= nil first)
      i
      (recur rest (+ 1 i))))
```

This would destructure the first table argument, with the first value inside it
being assigned to `first` and the remainder of the table being assigned to
`rest`. `i` simply gets bound to 0.

The body of the form executes for every item in the table, calling `recur` each
time with the table lacking its head element (thus consuming one element per
iteration), and with `i` being called with one value greater than the previous.

When the loop terminates (When the user doesn't call `recur`) it will return the
number of elements in the passed in table. (In this case, 5)

# Limitations

In order to only evaluate expressions once and support sequential
bindings, the binding table has to be transformed like this:

``` fennel :skip-test
(loop [[x & xs] (foo)
       y (+ x 1)]
  ...)

(let [_1_ (foo)
      [x & xs] _1_
      _2_ (+ x 1)
      y _2_]
  ((fn recur [[x & xs] y] ...) _1_ _2_)
```

This ensures that `foo` is called only once, its result is cached in a
`sym1#` binding, and that `y` can use the destructured value, obtained
from that binding.  The value of this binding is later passed to the
function to begin the first iteration.

This has two unfortunate consequences.  One is that the initial
destructuring happens twice - first, to make sure that later bindings
can be properly initialized, and second, when the first looping
function call happens.  Another one is that as a result, `loop` macro
can't work with multiple-value destructuring, because these can't be
cached as described above.  E.g. this will not work:

``` fennel :skip-test
(loop [(x y) (foo)] ...)
```

Because it would be transformed to:

``` fennel :skip-test
(let [_1_ (foo)
      (x y) _1_]
  ((fn recur [(x y)] ...) _1_)
```

`x` is correctly set, but `y` is completely lost.  Therefore, this
macro checks for lists in bindings."
    {:fnl/arglist [binding-vec body*]}
    (let [recur (sym :recur)
          keys []
          gensyms []
          bindings []]
      (assert-tail recur ...)
      (each [i v (ipairs binding-vec)]
        (when (= 0 (% i 2))
          (let [key (. binding-vec (- i 1))
                gs (gensym (tostring i))]
            (assert-compile (not (list? key)) "loop macro doesn't support multiple-value destructuring" key)
            ;; [sym1# sym2# etc...], for the function application below
            (table.insert gensyms gs)

            ;; let bindings
            (table.insert bindings gs)  ;; sym1#
            (table.insert bindings v)   ;; (expression)
            (table.insert bindings key) ;; [first & rest]
            (table.insert bindings gs)  ;; sym1#

            ;; The gensyms we use for function application
            (table.insert keys key))))
      `(let ,bindings
         ((fn ,recur ,keys
            ,...)
          ,(table.unpack gensyms)))))

  ;; Try catch finally

  (fn catch? [[fun]]
    "Test if expression is a catch clause."
    (= (tostring fun) :catch))

  (fn finally? [[fun]]
    "Test if expression is a finally clause."
    (= (tostring fun) :finally))

  (fn add-finally [finally form]
    "Stores `form' as body of `finally', which will be injected into
`match' branches at places appropriate for it to run.

Checks if there already was `finally' clause met, which can be only
one."
    (assert-compile (= (length finally) 0)
                    "Only one finally clause can exist in try expression"
                    [])
    (table.insert finally (list 'do ((or table.unpack _G.unpack) form 2))))

  (fn add-catch [finally catches form]
    "Appends `catch' body to a sequence of catch bodies that will later
be used in `make-catch-clauses' to produce AST.

Checks if there already was `finally' clause met."
    (assert-compile (= (length finally) 0)
                    "finally clause must be last in try expression"
                    [])
    (table.insert catches (list 'do ((or table.unpack _G.unpack) form 2))))

  (fn make-catch-clauses [catches finally]
    "Generates AST of error branches for `match' macro."
    (let [clauses []]
      (var add-catchall? true)
      (each [_ [_ binding-or-val & body] (ipairs catches)]
        (when (sym? binding-or-val)
          (set add-catchall? false))
        (table.insert clauses `(false ,binding-or-val))
        (table.insert clauses `(let [res# ((or table.pack #(doto [$...] (tset :n (select :# $...))))
                                           (do ,((or table.unpack _G.unpack) body)))]
                                 ,(. finally 1)
                                 (table.unpack res# 1 res#.n))))
      (when add-catchall?
        ;; implicit catchall which retrows error further is added only
        ;; if there were no catch clause that used symbol as catch value
        (table.insert clauses `(false _#))
        (table.insert clauses `(do ,(. finally 1) (error _#))))
      ((or table.unpack _G.unpack) clauses)))

  (fn add-to-try [finally catches try form]
    "Append form to the try body.  There must be no `catch' of `finally'
clauses when we push body epression."
    (assert-compile (and (= (length finally) 0)
                         (= (length catches) 0))
                    "Only catch or finally clause can follow catch in try expression"
                    [])
    (table.insert try form))

  (fn try [...]
    "General purpose try/catch/finally macro.
Wraps its body in `pcall' and checks the return value with `match'
macro.

Catch clause is written either as `(catch symbol body*)`, thus acting
as catch-all, or `(catch value body*)` for catching specific errors.
It is possible to have several `catch' clauses.  If no `catch' clauses
specified, an implicit catch-all clause is created.  `body*', and
inner expressions of `catch-clause*', and `finally-clause?' are
wrapped in implicit `do'.

The `finally` clause is optional, and written as (finally body*).  If
present, it must be the last clause in the `try' form, and the only
`finally' clause.  Note that `finally' clause is for side effects
only, and runs either after succesful run of `try' body, or after any
`catch' clause body, before returning the result.  If no `catch'
clause is provided `finally' runs in implicit catch-all clause, and
trows error to upper scope using `error' function.

To throw error from `try' to catch it with `catch' clause use `error'
or `assert' functions.

# Examples
Catch all errors, ignore those and return fallback value:

``` fennel
(fn add [x y]
  (try
    (+ x y)
    (catch _ 0)))

(assert-eq (add nil 1) 0)
```

Catch error and do cleanup:

``` fennel
(local tbl [])

(try
  (table.insert tbl \"a\")
  (table.insert tbl \"b\" \"c\")
  (catch _
    (each [k _ (pairs tbl)]
      (tset tbl k nil))))

(assert-eq (length tbl) 0)

```

Always run some side effect action:

``` fennel
(local t [])
(local res (try 10 (finally (table.insert t :finally))))
(assert-eq (. t 1) :finally)
(assert-eq res 10)

(local res (try (error 10) (catch 10 nil) (finally (table.insert t :again))))
(assert-eq (. t 2) :again)
(assert-eq res nil)
```"
    {:fnl/arglist [body* catch-clause* finally-clause?]}
    (let [try '(do)
          catches []
          finally []]
      (each [_ form (ipairs [...])]
        (if (list? form)
            (if (catch? form) (add-catch finally catches form)
                (finally? form) (add-finally finally form)
                (add-to-try finally catches try form))
            (add-to-try finally catches try form)))
      `(match (pcall (fn [] ((or table.pack #(doto [$...] (tset :n (select :# $...)))) ,try)))
         (true _#) (do ,(. finally 1) ((or table.unpack _G.unpack) _# 1 _#.n))
         ,(make-catch-clauses catches finally))))

  ;; Misc

  (fn cond [...]
    "Takes a set of test expression pairs. It evaluates each test one at a
time.  If a test returns logical true, `cond` evaluates and returns
the value of the corresponding expression and doesn't evaluate any of
the other tests or exprs. `(cond)` returns nil."
    (assert-compile (= 0 (% (select "#" ...) 2))
                    "cond requires an even number of forms"
                    ...)
    (if (= 0 (select "#" ...))
        `nil
        `(if ,...)))

  ;; Lazy seq

  (fn lazy-seq [...]
    "Takes a `body` of expressions that returns a sequence, table or nil,
and yields a lazy sequence that will invoke the body only the first
time `seq` is called, and will cache the result and return it on all
subsequent `seq` calls. See also - `realized?`"
    {:fnl/arglist [& body]}
    `(do
       (import-macros
        {:lazy-seq lazy-seq#}
        (doto :lazy-seq require))
       (let [core# (require ,lib-name)
             res# (lazy-seq# ,...)]
         (match (getmetatable res#)
           mt# (doto mt#
                 (tset :cljlib/type :seq)
                 (tset :cljlib/conj
                       (fn [s# v#] (core#.cons v# s#)))
                 (tset :cljlib/empty #(core#.list))))
         res#)))

  (fn lazy-cat [...]
    "Expands to code which yields a lazy sequence of the concatenation of
`colls` - expressions returning collections.  Each expression is not
evaluated until it is needed."
    {:fnl/arglist [& colls]}
    `(do
       (import-macros
        {:lazy-cat lazy-cat#}
        (doto :lazy-seq require))
       (let [core# (require ,lib-name)
             res# (lazy-cat# ,...)]
         (match (getmetatable res#)
           mt# (doto mt#
                 (tset :cljlib/type :seq)
                 (tset :cljlib/conj
                       (fn [s# v#] (core#.cons v# s#)))
                 (tset :cljlib/empty #(core#.list))))
         res#)))

  (tset macro-loaded lib-name
        {: fn*
         : defn
         : defn-
         : in-ns
         : ns
         : def
         : time
         : when-let
         : when-some
         : if-let
         : if-some
         : defmulti
         : defmethod
         : cond
         : loop
         : try
         : lazy-seq
         : lazy-cat}))

(import-macros
 {: defn
  : defn-
  : ns
  : def
  : fn*
  : if-let
  : if-some
  : cond}
 (or ... :cljlib))

(ns core
  "MIT License

Copyright (c) 2022 Andrey Listopadov

Permission is hereby granted‚ free of charge‚ to any person obtaining a copy
of this software and associated documentation files (the “Software”)‚ to deal
in the Software without restriction‚ including without limitation the rights
to use‚ copy‚ modify‚ merge‚ publish‚ distribute‚ sublicense‚ and/or sell
copies of the Software‚ and to permit persons to whom the Software is
furnished to do so‚ subject to the following conditions：

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”‚ WITHOUT WARRANTY OF ANY KIND‚ EXPRESS OR
IMPLIED‚ INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY‚
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM‚ DAMAGES OR OTHER
LIABILITY‚ WHETHER IN AN ACTION OF CONTRACT‚ TORT OR OTHERWISE‚ ARISING FROM‚
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."
  (:require [lazy-seq :as lazy]
            [itable :as itable]))

;;; Utility functions

(fn unpack* [x ...]
  (if (core.seq? x)
      (lazy.unpack x)
      (itable.unpack x ...)))

(fn pack* [...]
  (doto [...] (tset :n (select "#" ...))))

(fn pairs* [t]
  (match (getmetatable t)
    {:__pairs p} (p t)
    _ (pairs t)))

(fn ipairs* [t]
  (match (getmetatable t)
    {:__ipairs i} (i t)
    _ (ipairs t)))

(fn length* [t]
  (match (getmetatable t)
    {:__len l} (l t)
    _ (length t)))

(defn apply
  "Apply `f` to the argument list formed by prepending intervening
arguments to `args`, and `f` must support variadic amount of
arguments.

# Examples
Applying `add` to different amount of arguments:

``` fennel
(assert-eq (apply add [1 2 3 4]) 10)
(assert-eq (apply add 1 [2 3 4]) 10)
(assert-eq (apply add 1 2 3 4 5 6 [7 8 9]) 45)
```"
  ([f args] (f (unpack* args)))
  ([f a args] (f a (unpack* args)))
  ([f a b args] (f a b (unpack* args)))
  ([f a b c args] (f a b c (unpack* args)))
  ([f a b c d & args]
   (let [flat-args []
         len (- (length* args) 1)]
     (for [i 1 len]
       (tset flat-args i (. args i)))
     (each [i a (pairs* (. args (+ len 1)))]
       (tset flat-args (+ i len) a))
     (f a b c d (unpack* flat-args)))))

(defn add
  "Sum arbitrary amount of numbers."
  ([] 0)
  ([a] a)
  ([a b] (+ a b))
  ([a b c] (+ a b c))
  ([a b c d] (+ a b c d))
  ([a b c d & rest] (apply add (+ a b c d) rest)))

(defn sub
  "Subtract arbitrary amount of numbers."
  ([] 0)
  ([a] (- a))
  ([a b] (- a b))
  ([a b c] (- a b c))
  ([a b c d] (- a b c d))
  ([a b c d & rest] (apply sub (- a b c d) rest)))

(defn mul
  "Multiply arbitrary amount of numbers."
  ([] 1)
  ([a] a)
  ([a b] (* a b))
  ([a b c] (* a b c))
  ([a b c d] (* a b c d))
  ([a b c d & rest] (apply mul (* a b c d) rest)))

(defn div
  "Divide arbitrary amount of numbers."
  ([a] (/ 1 a))
  ([a b] (/ a b))
  ([a b c] (/ a b c))
  ([a b c d] (/ a b c d))
  ([a b c d & rest] (apply div (/ a b c d) rest)))

(defn le
  "Returns true if nums are in monotonically non-decreasing order"
  ([a] true)
  ([a b] (<= a b))
  ([a b & [c d & more]]
   (if (<= a b)
       (if d (apply le b c d more)
           (<= b c))
       false)))

(defn lt
  "Returns true if nums are in monotonically decreasing order"
  ([a] true)
  ([a b] (< a b))
  ([a b & [c d & more]]
   (if (< a b)
       (if d (apply lt b c d more)
           (< b c))
       false)))

(defn ge
  "Returns true if nums are in monotonically non-increasing order"
  ([a] true)
  ([a b] (>= a b))
  ([a b & [c d & more]]
   (if (>= a b)
       (if d (apply ge b c d more)
           (>= b c))
       false)))

(defn gt
  "Returns true if nums are in monotonically increasing order"
  ([a] true)
  ([a b] (> a b))
  ([a b & [c d & more]]
   (if (> a b)
       (if d (apply gt b c d more)
           (> b c))
       false)))

(defn inc
  "Increase number `x` by one"
  [x]
  (+ x 1))

(defn dec
  "Decrease number `x` by one"
  [x]
  (- x 1))

(defn class
  "Return cljlib type of the `x`, or lua type."
  [x]
  (match (type x)
    :table (match (getmetatable x)
             {:cljlib/type t} t
             _ :table)
    t t))

(defn constantly
  "Returns a function that takes any number of arguments and returns `x`."
  [x]
  (fn [] x))

(defn complement
  "Takes a function `f` and returns the function that takes the same
amount of arguments as `f`, has the same effect, and returns the
opposite truth value."
  [f]
  (fn*
    ([] (not (f)))
    ([a] (not (f a)))
    ([a b] (not (f a b)))
    ([a b & cs] (not (apply f a b cs)))))

(defn identity
  "Returns its argument."
  [x]
  x)

(defn comp
  "Compose functions."
  ([] identity)
  ([f] f)
  ([f g]
   (fn*
     ([] (f (g)))
     ([x] (f (g x)))
     ([x y] (f (g x y)))
     ([x y z] (f (g x y z)))
     ([x y z & args] (f (apply g x y z args)))))
  ([f g & fs]
   (core.reduce comp (core.cons f (core.cons g fs)))))

(defn eq
  "Comparison function.

Accepts arbitrary amount of values, and does the deep comparison.  If
values implement `__eq` metamethod, tries to use it, by checking if
first value is equal to second value, and the second value is equal to
the first value.  If values are not equal and are tables does the deep
comparison.  Tables as keys are supported."
  ([] true)
  ([_] true)
  ([a b]
   (if (and (= a b) (= b a))
       true
       (= :table (type a) (type b))
       (do (var (res count-a) (values true 0))
           (each [k v (pairs* a) :until (not res)]
             (set res (eq v (do (var (res done) (values nil nil))
                                (each [k* v (pairs* b) :until done]
                                  (when (eq k* k)
                                    (set (res done) (values v true))))
                                res)))
             (set count-a (+ count-a 1)))
           (when res
             (let [count-b (accumulate [res 0 _ _ (pairs* b)]
                             (+ res 1))]
               (set res (= count-a count-b))))
           res)
       false))
  ([a b & cs]
   (and (eq a b) (apply eq b cs))))

(fn deep-index [tbl key]
  "This function uses the `eq` function to compare keys of the given
table `tbl` and the given `key`.  Several other functions also reuse
this indexing method, such as sets."
  (accumulate [res nil
               k v (pairs* tbl)
               :until res]
    (when (eq k key)
      v)))

(fn deep-newindex [tbl key val]
  "This function uses the `eq` function to compare keys of the given
table `tbl` and the given `key`. If the key is found it's being
set, if not a new key is set."
  (var done false)
  (when (= :table (type key))
    (each [k _ (pairs* tbl) :until done]
      (when (eq k key)
        (rawset tbl k val)
        (set done true))))
  (when (not done)
    (rawset tbl key val)))

(defn memoize
  "Returns a memoized version of a referentially transparent function.
The memoized version of the function keeps a cache of the mapping from
arguments to results and, when calls with the same arguments are
repeated often, has higher performance at the expense of higher memory
use."
  [f]
  (let [memo (setmetatable {} {:__index deep-index})]
    (fn* [& args]
      (match (. memo args)
        res (unpack* res 1 res.n)
        _ (let [res (pack* (f ...))]
            (tset memo args res)
            (unpack* res 1 res.n))))))

(defn deref
  "Dereference an object."
  [x]
  (match (getmetatable x)
    {:cljlib/deref f} (f x)
    _ (error "object doesn't implement cljlib/deref metamethod" 2)))

(defn empty
  "Get an empty variant of a given collection."
  [x]
  (match (getmetatable x)
    {:cljlib/empty f} (f)
    _ (match (type x)
        :table []
        :string ""
        _ (error (.. "don't know how to create empty variant of type " _)))))

;;;Tests and predicates

(defn nil?
  "Test if `x` is nil."
  ([] true)
  ([x] (= x nil)))

(defn zero?
  "Test if `x` is equal to zero."
  [x]
  (= x 0))

(defn pos?
  "Test if `x` is greater than zero."
  [x]
  (> x 0))

(defn neg?
  "Test if `x` is less than zero."
  [x]
  (< x 0))

(defn even?
  "Test if `x` is even."
  [x]
  (= (% x 2) 0))

(defn odd?
  "Test if `x` is odd."
  [x]
  (not (even? x)))

(defn string?
  "Test if `x` is a string."
  [x]
  (= (type x) :string))

(defn boolean?
  "Test if `x` is a Boolean"
  [x]
  (= (type x) :boolean))

(defn true?
  "Test if `x` is `true`"
  [x]
  (= x true))

(defn false?
  "Test if `x` is `false`"
  [x]
  (= x false))

(defn int?
  "Test if `x` is a number without floating point data.

Number is rounded with `math.floor` and compared with original number."
  [x]
  (and (= (type x) :number)
       (= x (math.floor x))))

(defn pos-int?
  "Test if `x` is a positive integer."
  [x]
  (and (int? x)
       (pos? x)))

(defn neg-int?
  "Test if `x` is a negative integer."
  [x]
  (and (int? x)
       (neg? x)))

(defn double?
  "Test if `x` is a number with floating point data."
  [x]
  (and (= (type x) :number)
       (not= x (math.floor x))))

(defn empty?
  "Check if collection is empty."
  [x]
  (match (type x)
    :table
    (match (getmetatable x)
      {:cljlib/type :seq}
      (nil? (core.seq x))
      (where (or nil {:cljlib/type nil}))
      (let [(next*) (pairs* x)]
        (= (next* x) nil)))
    :string (= x "")
    :nil true
    _ (error "empty?: unsupported collection")))

(defn not-empty
  "If `x` is empty, returns `nil`, otherwise `x`."
  [x]
  (if (not (empty? x))
      x))

(defn map?
  "Check whether `x` is an associative table.

Non-empty tables are tested by calling `next`. If the length of the
table is greater than zero, the last integer key is passed to the
`next`, and if `next` returns a key, the table is considered
associative. If the length is zero, `next` is called with what `paris`
returns for the table, and if the key is returned, table is considered
associative.

Empty tables can't be analyzed with this method, and `map?` will
always return `false`.  If you need this test pass for empty table,
see `hash-map` for creating tables that have additional metadata
attached for this test to work.

# Examples
Non-empty map:

``` fennel
(assert-is (map? {:a 1 :b 2}))
```

Empty tables don't pass the test:

``` fennel
(assert-not (map? {}))
```

Empty tables created with `hash-map` will pass the test:

``` fennel
(assert-is (map? (hash-map)))
```"
  [x]
  (if (= :table (type x))
      (match (getmetatable x)
        {:cljlib/type :hash-map} true
        {:cljlib/type :sorted-map} true
        (where (or nil {:cljlib/type nil}))
        (let [len (length* x)
              (nxt t k) (pairs* x)]
          (not= nil (nxt t (if (= len 0) k len))))
        _ false)
      false))

(defn vector?
  "Check whether `tbl` is a sequential table.

Non-empty sequential tables are tested for two things:
- `next` returns the key-value pair,
- key, that is returned by the `next` is equal to `1`.

Empty tables can't be analyzed with this method, and `vector?` will
always return `false`.  If you need this test pass for empty table,
see `vector` for creating tables that have additional
metadata attached for this test to work.

# Examples
Non-empty vector:

``` fennel
(assert-is (vector? [1 2 3 4]))
```

Empty tables don't pass the test:

``` fennel
(assert-not (vector? []))
```

Empty tables created with `vector` will pass the test:

``` fennel
(assert-is (vector? (vector)))
```"
  [x]
  (if (= :table (type x))
      (match (getmetatable x)
        {:cljlib/type :vector} true
        (where (or nil {:cljlib/type nil}))
        (let [len (length* x)
              (nxt t k) (pairs* x)]
          (if (not= nil (nxt t (if (= len 0) k len))) false
              (> len 0) true
              false))
        _ false)
      false))

(defn set?
  "Check if object is a set."
  [x]
  (match (getmetatable x)
    {:cljlib/type :hash-set} true
    _ false))

(defn seq?
  "Check if object is a sequence."
  [x]
  (lazy.seq? x))

(defn some?
  "Returns true if x is not nil, false otherwise."
  [x]
  (not= x nil))

;;; Vector

(fn vec->transient [immutable]
  (fn [vec]
    (var len (length vec))
    (->> {:__index (fn [_ i]
                     (if (<= i len)
                         (. vec i)))
          :__len #len
          :cljlib/type :transient
          :cljlib/conj #(error "can't `conj` onto transient vector, use `conj!`")
          :cljlib/assoc #(error "can't `assoc` onto transient vector, use `assoc!`")
          :cljlib/dissoc #(error "can't `dissoc` onto transient vector, use `dissoc!`")
          :cljlib/conj! (fn [tvec v]
                          (set len (+ len 1))
                          (doto tvec (tset len v)))
          :cljlib/assoc! (fn [tvec ...]
                           (let [len (length tvec)]
                             (for [i 1 (select "#" ...) 2]
                               (let [(k v) (select i ...)]
                                 (if (<= 1 i len)
                                     (tset tvec i v)
                                     (error (.. "index " i " is out of bounds"))))))
                           tvec)
          :cljlib/pop! (fn [tvec]
                         (if (= len 0)
                             (error "transient vector is empty" 2)
                             (let [val (table.remove tvec)]
                               (set len (- len 1))
                               tvec)))
          :cljlib/dissoc! #(error "can't `dissoc!` with a transient vector")
          :cljlib/persistent! (fn [tvec]
                                (let [v (fcollect [i 1 len] (. tvec i))]
                                  (while (> len 0)
                                    (table.remove tvec)
                                    (set len (- len 1)))
                                  (setmetatable tvec
                                                {:__index #(error "attempt to use transient after it was persistet")
                                                 :__newindex #(error "attempt to use transient after it was persistet")})
                                  (immutable (itable v))))}
         (setmetatable {}))))

(fn vec* [v len]
  (match (getmetatable v)
    mt (doto mt
         (tset :__len (constantly (or len (length* v))))
         (tset :cljlib/type :vector)
         (tset :cljlib/editable true)
         (tset :cljlib/conj
               (fn [t v]
                 (let [len (length* t)]
                   (vec* (itable.assoc t (+ len 1) v) (+ len 1)))))
         (tset :cljlib/pop
               (fn [t]
                 (let [len (- (length* t) 1)
                       coll []]
                   (when (< len 0)
                     (error "can't pop empty vector" 2))
                   (for [i 1 len]
                     (tset coll i (. t i)))
                   (vec* (itable coll) len))))
         (tset :cljlib/empty
               (fn [] (vec* (itable []))))
         (tset :cljlib/transient (vec->transient vec*))
         (tset :__fennelview (fn [coll view inspector indent]
                               (if (empty? coll)
                                   "[]"
                                   (let [lines (fcollect [i 1 (length* coll)]
                                                 (.. " " (view (. coll i) inspector indent)))]
                                     (tset lines 1 (.. "[" (string.gsub (or (. lines 1) "") "^%s+" "")))
                                     (tset lines (length lines) (.. (. lines (length lines)) "]"))
                                     lines)))))
    nil (vec* (setmetatable v {})))
  v)

(defn vec
  "Coerce collection `coll` to a vector."
  [coll]
  (cond (empty? coll) (vec* (itable []) 0)
        (vector? coll) (vec* (itable coll) (length* coll))
        :else (let [packed (-> coll core.seq lazy.pack)
                    len packed.n]
                (-> packed
                    (doto (tset :n nil))
                    (itable {:fast-index? true})
                    (vec* len)))))

(defn vector
  "Constructs sequential table out of its arguments.

Sets additional metadata for function `vector?` to work.

# Examples

``` fennel
(def :private v (vector 1 2 3 4))
(assert-eq v [1 2 3 4])
```"
  [& args]
  (vec args))

(defn nth
  "Returns the value at the `index`. `get` returns `nil` if `index` out
of bounds, `nth` raises an error unless `not-found` is supplied.
`nth` also works for strings and sequences."
  ([coll i]
   (if (vector? coll)
       (if (or (< i 1) (< (length* coll) i))
           (error (string.format "index %d is out of bounds" i))
           (. coll i))
       (string? coll)
       (nth (vec coll) i)
       (seq? coll)
       (nth (vec coll) i)
       :else
       (error "expected an indexed collection")))
  ([coll i not-found]
   (assert (int? i) "expected an integer key")
   (if (vector? coll)
       (or (. coll i) not-found)
       (string? coll)
       (nth (vec coll) i not-found)
       (seq? coll)
       (nth (vec coll) i not-found)
       :else
       (error "expected an indexed collection"))))

;;; Sequences

(defn- seq*
  "Add cljlib sequence meta-info."
  [x]
  (match (getmetatable x)
    mt (doto mt
         (tset :cljlib/type :seq)
         (tset :cljlib/conj
               (fn [s v] (core.cons v s)))
         (tset :cljlib/empty #(core.list))))
  x)

(defn seq
  "Construct a sequence from the given collection `coll`.  If `coll` is
an associative table, returns sequence of vectors with key and value.
If `col` is sequential table, returns its shallow copy.  If `col` is
string, return sequential table of its codepoints.

# Examples
Sequential tables are transformed to sequences:

``` fennel
(seq [1 2 3 4]) ;; @seq(1 2 3 4)
```

Associative tables are transformed to format like this `[[key1 value1]
... [keyN valueN]]` and order is non-deterministic:

``` fennel
(seq {:a 1 :b 2 :c 3}) ;; @seq([:b 2] [:a 1] [:c 3])
```"
  [coll]
  (seq* (match (getmetatable coll)
          {:cljlib/seq f} (f coll)
          _ (cond (lazy.seq? coll) (lazy.seq coll)
                  (map? coll) (lazy.map vec coll)
                  :else (lazy.seq coll)))))

(defn rseq
  "Returns, in possibly-constant time, a seq of the items in `rev` in reverse order.
Input must be traversable with `ipairs`.  Doesn't work in constant
time if `rev` implements a linear-time `__len` metamethod, or invoking
Lua `#` operator on `rev` takes linar time.  If `t` is empty returns
`nil`.

# Examples

``` fennel
(def :private v [1 2 3])
(def :private r (rseq v))

(assert-eq (reverse v) r)
```"
  [rev]
  (seq* (lazy.rseq rev)))

(defn lazy-seq*
  "Create lazy sequence from the result of calling a function `f`.
Delays execution of `f` until sequence is consumed.  `f` must return a
sequence or a vector.  There's a convenience macro `lazy-seq'
automates the process of function creation."
  [f]
  (seq* (lazy.lazy-seq f)))

(defn first
  "Return first element of a `coll`. Calls `seq` on its argument."
  [coll]
  (lazy.first (seq coll)))

(defn rest
  "Returns a sequence of all elements of a `coll` but the first one.
Calls `seq` on its argument."
  [coll]
  (seq* (lazy.rest (seq coll))))

(defn- next*
  "Return the tail of a sequence.

If the sequence is empty, returns nil."
  [s]
  (seq* (lazy.next s)))

(doto core (tset :next next*)) ; luajit doesn't like next redefinition

(defn count
  "Count amount of elements in the sequence."
  [s]
  (match (getmetatable s)
    {:cljlib/type :vector} (length* s)
    _ (lazy.count s)))

(defn cons
  "Construct a cons cell.
Prepends new `head` to a `tail`, which must be either a table,
sequence, or nil.

# Examples

``` fennel
(assert-eq [0 1] (cons 0 [1]))
(assert-eq (list 0 1 2 3) (cons 0 (cons 1 (list 2 3))))
```"
  [head tail]
  (seq* (lazy.cons head tail)))

(fn list
  [...]
  "Create eager sequence of provided values.

# Examples

``` fennel
(local l (list 1 2 3 4 5))
(assert-eq [1 2 3 4 5] l)
```"
  (seq* (lazy.list ...)))

(set core.list list)

(defn list*
  "Creates a new sequence containing the items prepended to the rest,
the last of which will be treated as a sequence.

# Examples

``` fennel
(local l (list* 1 2 3 [4 5]))
(assert-eq [1 2 3 4 5] l)
```"
  [& args]
  (seq* (apply lazy.list* args)))

(defn last
  "Returns the last element of a `coll`. Calls `seq` on its argument."
  [coll]
  (match (next* coll)
    coll* (last coll*)
    _ (first coll)))

(defn butlast
  "Returns everything but the last element of the `coll` as a new
  sequence.  Calls `seq` on its argument."
  [coll]
  (seq (lazy.drop-last coll)))

(defn map
  "Returns a lazy sequence consisting of the result of applying `f` to
the set of first items of each `coll`, followed by applying `f` to the
set of second items in each `coll`, until any one of the `colls` is
exhausted.  Any remaining items in other `colls` are ignored. Function
`f` should accept number-of-colls arguments. Returns a transducer when
no collection is provided.

# Examples

``` fennel
(map #(+ $ 1) [1 2 3]) ;; => @seq(2 3 4)
(map #(+ $1 $2) [1 2 3] [4 5 6]) ;; => @seq(5 7 9)
(def :private res (map #(+ $ 1) [:a :b :c])) ;; will raise an error only when realized
```"
  ([f]
   (fn* [rf]
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (rf result (f input)))
       ([result input & inputs]
        (rf result (apply f input inputs))))))
  ([f coll]
   (seq* (lazy.map f coll)))
  ([f coll & colls]
   (seq* (apply lazy.map f coll colls))))

(defn mapv
  "Returns a vector consisting of the result of applying `f` to the
set of first items of each `coll`, followed by applying `f` to the set
of second items in each coll, until any one of the `colls` is
exhausted.  Any remaining items in other collections are ignored.
Function `f` should accept number-of-colls arguments."
  ([f coll]
   (->> coll
        (core.transduce (map f)
                        core.conj!
                        (core.transient (vector)))
        core.persistent!))
  ([f coll & colls] (vec (apply map f coll colls))))

(defn map-indexed
  "Returns a lazy sequence consisting of the result of applying `f` to 1
and the first item of `coll`, followed by applying `f` to 2 and the
second item in `coll`, etc., until `coll` is exhausted.  Returns a
transducer when no collection is provided."
  ([f]
   (fn* [rf]
     (var i -1)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (set i (+ i 1))
        (rf result (f i input))))))
  ([f coll]
   (seq* (lazy.map-indexed f coll))))

(defn mapcat
  "Apply `concat` to the result of calling `map` with `f` and
collections `colls`. Returns a transducer when no collection is
provided."
  ([f]
   (comp (map f) core.cat))
  ([f & colls]
   (seq* (apply lazy.mapcat f colls))))

(defn filter
  "Returns a lazy sequence of the items in `coll` for which
`pred` returns logical true. Returns a transducer when no collection
is provided."
  ([pred]
   (fn* [rf]
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (if (pred input)
            (rf result input)
            result)))))
  ([pred coll]
   (seq* (lazy.filter pred coll))))

(defn filterv
  "Returns a vector of the items in `coll` for which
`pred` returns logical true."
  [pred coll]
  (vec (filter pred coll)))

(defn every?
  "Test if every item in `coll` satisfies the `pred`."
  [pred coll]
  (lazy.every? pred coll))

(defn some
  "Test if any item in `coll` satisfies the `pred`."
  [pred coll]
  (lazy.some? pred coll))

(defn not-any?
  "Test if no item in `coll` satisfy the `pred`."
  [pred coll]
  (some #(not (pred $)) coll))

(defn range
  "Returns lazy sequence of numbers from `lower` to `upper` with optional
`step`."
  ([] (seq* (lazy.range)))
  ([upper] (seq* (lazy.range upper)))
  ([lower upper] (seq* (lazy.range lower upper)))
  ([lower upper step] (seq* (lazy.range lower upper step))))

(defn concat
  "Return a lazy sequence of concatenated `colls`."
  [& colls]
  (seq* (apply lazy.concat colls)))

(defn reverse
  "Returns a lazy sequence with same items as in `coll` but in reverse order."
  [coll]
  (seq* (lazy.reverse coll)))

(defn take
  "Returns a lazy sequence of the first `n` items in `coll`, or all items if
there are fewer than `n`."
  ([n]
   (fn* [rf]
     (var n n)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (let [result (if (< 0 n)
                         (rf result input)
                         result)]
          (set n (- n 1))
          (if (not (< 0 n))
              (core.ensure-reduced result)
              result))))))
  ([n coll]
   (seq* (lazy.take n coll))))

(defn take-while
  "Take the elements from the collection `coll` until `pred` returns logical
false for any of the elemnts.  Returns a lazy sequence. Returns a
transducer when no collection is provided."
  ([pred]
   (fn* [rf]
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (if (pred input)
            (rf result input)
            (core.reduced result))))))
  ([pred coll]
   (seq* (lazy.take-while pred coll))))

(defn drop
  "Drop `n` elements from collection `coll`, returning a lazy sequence
of remaining elements. Returns a transducer when no collection is
provided."
  ([n]
   (fn* [rf]
     (var nv n)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (let [n nv]
          (set nv (- nv 1))
          (if (pos? n)
              result
              (rf result input)))))))
  ([n coll]
   (seq* (lazy.drop n coll))))

(defn drop-while
  "Drop the elements from the collection `coll` until `pred` returns logical
false for any of the elemnts.  Returns a lazy sequence. Returns a
transducer when no collection is provided."
  ([pred]
   (fn* [rf]
     (var dv true)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (let [drop? dv]
          (if (and drop? (pred input))
              result
              (do
                (set dv nil)
                (rf result input))))))))
  ([pred coll]
   (seq* (lazy.drop-while pred coll))))

(defn drop-last
  "Return a lazy sequence from `coll` without last `n` elements."
  ([] (seq* (lazy.drop-last)))
  ([coll] (seq* (lazy.drop-last coll)))
  ([n coll] (seq* (lazy.drop-last n coll))))

(defn take-last
  "Return a sequence of last `n` elements of the `coll`."
  [n coll]
  (seq* (lazy.take-last n coll)))

(defn take-nth
  "Return a lazy sequence of every `n` item in `coll`. Returns a
transducer when no collection is provided."
  ([n]
   (fn* [rf]
     (var iv -1)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (set iv (+ iv 1))
        (if (= 0 (% iv n))
            (rf result input)
            result)))))
  ([n coll]
   (seq* (lazy.take-nth n coll))))

(defn split-at
  "Return a table with sequence `coll` being split at `n`"
  [n coll]
  (vec (lazy.split-at n coll)))

(defn split-with
  "Return a table with sequence `coll` being split with `pred`"
  [pred coll]
  (vec (lazy.split-with pred coll)))

(defn nthrest
  "Returns the nth rest of `coll`, `coll` when `n` is 0.

# Examples

``` fennel
(assert-eq (nthrest [1 2 3 4] 3) [4])
(assert-eq (nthrest [1 2 3 4] 2) [3 4])
(assert-eq (nthrest [1 2 3 4] 1) [2 3 4])
(assert-eq (nthrest [1 2 3 4] 0) [1 2 3 4])
```
"
  [coll n]
  (seq* (lazy.nthrest coll n)))

(defn nthnext
  "Returns the nth next of `coll`, (seq coll) when `n` is 0."
  [coll n]
  (lazy.nthnext coll n))

(defn keep
  "Returns a lazy sequence of the non-nil results of calling `f` on the
items of the `coll`. Returns a transducer when no collection is
provided."
  ([f]
   (fn* [rf]
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (let [v (f input)]
          (if (nil? v)
              result
              (rf result v)))))))
  ([f coll]
   (seq* (lazy.keep f coll))))

(defn keep-indexed
  "Returns a lazy sequence of the non-nil results of (f index item) in
the `coll`.  Note, this means false return values will be included.
`f` must be free of side effects. Returns a transducer when no
collection is provided."
  ([f]
   (fn* [rf]
     (var iv -1)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (set iv (+ iv 1))
        (let [v (f iv input)]
          (if (nil? v)
              result
              (rf result v)))))))
  ([f coll]
   (seq* (lazy.keep-indexed f coll))))

(defn partition
  "Given a collection `coll`, returns a lazy sequence of lists of `n`
items each, at offsets `step` apart. If `step` is not supplied,
defaults to `n`, i.e. the partitions do not overlap. If a `pad`
collection is supplied, use its elements as necessary to complete last
partition up to `n` items. In case there are not enough padding
elements, return a partition with less than `n` items."
  ([n coll] (map seq* (lazy.partition n coll)))
  ([n step coll] (map seq* (lazy.partition n step coll)))
  ([n step pad coll] (map seq* (lazy.partition n step pad coll))))

(fn array []
  (var len 0)
  (->> {:__len #len
        :__index {:clear (fn [self]
                           (while (not= 0 len)
                             (tset self len nil)
                             (set len (- len 1))
                             self))
                  :add (fn [self val]
                         (set len (+ len 1))
                         (tset self len val)
                         self)}}
       (setmetatable [])))

(defn partition-by
  "Applies `f` to each value in `coll`, splitting it each time `f`
returns a new value.  Returns a lazy seq of partitions.  Returns a
transducer, if collection is not supplied."
  ([f]
   (fn* [rf]
     (let [a (array)
           none {}]
       (var pv none)
       (fn*
         ([] (rf))
         ([result]
          (rf (if (empty? a)
                  result
                  (let [v (vec a)]
                    (a:clear)
                    (core.unreduced (rf result v))))))
         ([result input]
          (let [pval pv
                val (f input)]
            (set pv val)
            (if (or (= pval none)
                    (= val pval))
                (do
                  (a:add input)
                  result)
                (let [v (vec a)]
                  (a:clear)
                  (let [ret (rf result v)]
                    (when (not (core.reduced? ret))
                      (a:add input))
                    ret)))))))))
  ([f coll]
   (map seq* (lazy.partition-by f coll))))

(defn partition-all
  "Given a collection `coll`, returns a lazy sequence of lists like
`partition`, but may include partitions with fewer than n items at the
end. Accepts addiitonal `step` argument, similarly to `partition`.
Returns a transducer, if collection is not supplied."
  ([n]
   (fn* [rf]
     (let [a (array)]
       (fn*
         ([] (rf))
         ([result]
          (rf (if (= 0 (length a))
                  result
                  (let [v (vec a)]
                    (a:clear)
                    (core.unreduced (rf result v))))))
         ([result input]
          (a:add input)
          (if (= n (length a))
              (let [v (vec a)]
                (a:clear)
                (rf result v))
              result))))))
  ([n coll]
   (map seq* (lazy.partition-all n coll)))
  ([n step coll]
   (map seq* (lazy.partition-all n step coll))))

(defn reductions
  "Returns a lazy seq of the intermediate values of the reduction (as
per reduce) of `coll` by `f`, starting with `init`."
  ([f coll] (seq* (lazy.reductions f coll)))
  ([f init coll] (seq* (lazy.reductions f init coll))))

(defn contains?
  "Test if `elt` is in the `coll`.  It may be a linear search depending
on the type of the collection."
  [coll elt]
  (lazy.contains? coll elt))

(defn distinct
  "Returns a lazy sequence of the elements of the `coll` without
duplicates.  Comparison is done by equality. Returns a transducer when
no collection is provided."
  ([]
   (fn* [rf]
     (let [seen (setmetatable {} {:__index deep-index})]
       (fn*
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (if (. seen input)
              result
              (do
                (tset seen input true)
                (rf result input))))))))
  ([coll]
   (seq* (lazy.distinct coll))))

(defn dedupe
  "Returns a lazy sequence removing consecutive duplicates in coll.
Returns a transducer when no collection is provided."
  ([]
   (fn* [rf]
     (let [none {}]
       (var pv none)
       (fn*
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [prior pv]
            (set pv input)
            (if (= prior input)
                result
                (rf result input))))))))
  ([coll] (core.sequence (dedupe) coll)))

(defn random-sample
  "Returns items from `coll` with random probability of `prob` (0.0 -
1.0).  Returns a transducer when no collection is provided."
  ([prob]
   (filter (fn [] (< (math.random) prob))))
  ([prob coll]
   (filter (fn [] (< (math.random) prob)) coll)))

(defn doall
  "Realize whole lazy sequence `seq`.

Walks whole sequence, realizing each cell.  Use at your own risk on
infinite sequences."
  [seq]
  (seq* (lazy.doall seq)))

(defn dorun
  "Realize whole sequence `seq` for side effects.

Walks whole sequence, realizing each cell.  Use at your own risk on
infinite sequences."
  [seq]
  (lazy.dorun seq))

(defn line-seq
  "Accepts a `file` handle, and creates a lazy sequence of lines using
`lines` metamethod.

# Examples

Lazy sequence of file lines may seem similar to an iterator over a
file, but the main difference is that sequence can be shared onve
realized, and iterator can't.  Lazy sequence can be consumed in
iterator style with the `doseq` macro.

Bear in mind, that since the sequence is lazy it should be realized or
truncated before the file is closed:

``` fennel
(let [lines (with-open [f (io.open \"cljlib.fnl\" :r)]
              (line-seq f))]
  ;; this will error because only first line was realized, but the
  ;; file was closed before the rest of lines were cached
  (assert-not (pcall next lines)))
```

Sequence is realized with `doall` before file was closed and can be shared:

``` fennel
(let [lines (with-open [f (io.open \"cljlib.fnl\" :r)]
              (doall (line-seq f)))]
  (assert-is (pcall next lines)))
```

Infinite files can't be fully realized, but can be partially realized
with `take`:

``` fennel
(let [lines (with-open [f (io.open \"/dev/urandom\" :r)]
              (doall (take 3 (line-seq f))))]
  (assert-is (pcall next lines)))
```"
  [file]
  (seq* (lazy.line-seq file)))

(defn iterate
  "Returns an infinete lazy sequence of x, (f x), (f (f x)) etc."
  [f x]
  (seq* (lazy.iterate f x)))

(defn remove
  "Returns a lazy sequence of the items in the `coll` without elements
for wich `pred` returns logical true. Returns a transducer when no
collection is provided."
  ([pred]
   (filter (complement pred)))
  ([pred coll]
   (seq* (lazy.remove pred coll))))

(defn cycle
  "Create a lazy infinite sequence of repetitions of the items in the
`coll`."
  [coll]
  (seq* (lazy.cycle coll)))

(defn repeat
  "Takes a value `x` and returns an infinite lazy sequence of this value.

# Examples

``` fennel
(assert-eq 20 (reduce add (take 10 (repeat 2))))
```"
  [x]
  (seq* (lazy.repeat x)))

(defn repeatedly
  "Takes a function `f` and returns an infinite lazy sequence of
function applications.  Rest arguments are passed to the function."
  [f & args]
  (seq* (apply lazy.repeatedly f args)))

(defn tree-seq
  "Returns a lazy sequence of the nodes in a tree, via a depth-first walk.

`branch?` must be a function of one arg that returns true if passed a
node that can have children (but may not).  `children` must be a
function of one arg that returns a sequence of the children.  Will
only be called on nodes for which `branch?` returns true.  `root` is
the root node of the tree.

# Examples

For the given tree `[\"A\" [\"B\" [\"D\"] [\"E\"]] [\"C\" [\"F\"]]]`:

        A
       / \\
      B   C
     / \\   \\
    D   E   F

Calling `tree-seq` with `next` as the `branch?` and `rest` as the
`children` returns a flat representation of a tree:

``` fennel
(assert-eq (map first (tree-seq next rest [\"A\" [\"B\" [\"D\"] [\"E\"]] [\"C\" [\"F\"]]]))
           [\"A\" \"B\" \"D\" \"E\" \"C\" \"F\"])
```"
  [branch? children root]
  (seq* (lazy.tree-seq branch? children root)))

(defn interleave
  "Returns a lazy sequence of the first item in each sequence, then the
second one, until any sequence exhausts."
  ([] (seq* (lazy.interleave)))
  ([s] (seq* (lazy.interleave s)))
  ([s1 s2] (seq* (lazy.interleave s1 s2)))
  ([s1 s2 & ss] (seq* (apply lazy.interleave s1 s2 ss))))

(defn interpose
  "Returns a lazy sequence of the elements of `coll` separated by
`separator`. Returns a transducer when no collection is provided."
  ([sep]
   (fn* [rf]
     (var started false)
     (fn*
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (if started
            (let [sepr (rf result sep)]
              (if (core.reduced? sepr)
                  sepr
                  (rf sepr input)))
            (do
              (set started true)
              (rf result input)))))))
  ([separator coll]
   (seq* (lazy.interpose separator coll))))

(defn halt-when
  "Returns a transducer that ends transduction when `pred` returns `true`
for an input. When `retf` is supplied it must be a `fn` of 2 arguments
- it will be passed the (completed) result so far and the input that
triggered the predicate, and its return value (if it does not throw an
exception) will be the return value of the transducer. If `retf` is
not supplied, the input that triggered the predicate will be
returned. If the predicate never returns `true` the transduction is
unaffected."
  ([pred]
   (halt-when pred nil))
  ([pred retf]
   (fn* [rf]
     (let [halt (setmetatable {} {:__fennelview #"#<halt>"})]
       (fn*
         ([] (rf))
         ([result]
          (if (and (map? result) (contains? result halt))
              result.value
              (rf result)))
         ([result input]
          (if (pred input)
              (core.reduced {halt true :value (if retf (retf (rf result) input) input)})
              (rf result input))))))))

(defn realized?
  "Check if sequence's first element is realized."
  [s]
  (lazy.realized? s))

(defn keys
  "Returns a sequence of the map's keys, in the same order as `seq`."
  [coll]
  (assert (or (map? coll) (empty? coll)) "expected a map")
  (if (empty? coll)
      (lazy.list)
      (lazy.keys coll)))

(defn vals
  "Returns a sequence of the table's values, in the same order as `seq`."
  [coll]
  (assert (or (map? coll) (empty? coll)) "expected a map")
  (if (empty? coll)
      (lazy.list)
      (lazy.vals coll)))

(defn find
  "Returns the map entry for `key`, or `nil` if key is not present in
`coll`."
  [coll key]
  (assert (or (map? coll) (empty? coll)) "expected a map")
  (match (. coll key)
    v [key v]))

(defn sort
  "Returns a sorted sequence of the items in `coll`. If no `comparator`
is supplied, uses `<`."
  ([coll]
   (match (seq coll)
     s (seq (itable.sort (vec s)))
     _ (list)))
  ([comparator coll]
   (match (seq coll)
     s (seq (itable.sort (vec s) comparator))
     _ (list))))

;;; Reduce

(defn reduce
  "`f` should be a function of 2 arguments. If `val` is not supplied,
returns the result of applying `f` to the first 2 items in `coll`,
then applying `f` to that result and the 3rd item, etc. If `coll`
contains no items, f must accept no arguments as well, and reduce
returns the result of calling `f` with no arguments.  If `coll` has
only 1 item, it is returned and `f` is not called.  If `val` is
supplied, returns the result of applying `f` to `val` and the first
item in `coll`, then applying `f` to that result and the 2nd item,
etc. If `coll` contains no items, returns `val` and `f` is not
called. Early termination is supported via `reduced`.

# Examples

``` fennel
(defn- add
  ([] 0)
  ([a] a)
  ([a b] (+ a b))
  ([a b & cs] (apply add (+ a b) cs)))
;; no initial value
(assert-eq 10 (reduce add [1 2 3 4]))
;; initial value
(assert-eq 10 (reduce add 1 [2 3 4]))
;; empty collection - function is called with 0 args
(assert-eq 0 (reduce add []))
(assert-eq 10.3 (reduce math.floor 10.3 []))
;; collection with a single element doesn't call a function unless the
;; initial value is supplied
(assert-eq 10.3 (reduce math.floor [10.3]))
(assert-eq 7 (reduce add 3 [4]))
```"
  ([f coll] (lazy.reduce f (seq coll)))
  ([f val coll] (lazy.reduce f val (seq coll))))

(defn reduced
  "Terminates the `reduce` early with a given `value`.

# Examples

``` fennel
(assert-eq :NaN
           (reduce (fn [acc x]
                     (if (not= :number (type x))
                         (reduced :NaN)
                         (+ acc x)))
                   [1 2 :3 4 5]))
```"
  [value]
  (doto (lazy.reduced value)
    (-> getmetatable (tset :cljlib/deref #($:unbox)))))

(defn reduced?
  "Returns true if `x` is the result of a call to reduced"
  [x]
  (lazy.reduced? x))

(defn unreduced
  "If `x` is `reduced?`, returns `(deref x)`, else returns `x`."
  [x]
  (if (reduced? x) (deref x) x))

(defn ensure-reduced
  "If x is already reduced?, returns it, else returns (reduced x)"
  [x]
  (if (reduced? x)
      x
      (reduced x)))

(defn- preserving-reduced [rf]
  (fn* [a b]
    (let [ret (rf a b)]
      (if (reduced? ret)
          (reduced ret)
          ret))))

(defn cat
  "A transducer which concatenates the contents of each input, which must be a
  collection, into the reduction. Accepts the reducing function `rf`."
  [rf]
  (let [rrf (preserving-reduced rf)]
    (fn*
      ([] (rf))
      ([result] (rf result))
      ([result input]
       (reduce rrf result input)))))

(defn reduce-kv
  "Reduces an associative table using function `f` and initial value `val`.

`f` should be a function of 3 arguments.  Returns the result of
applying `f` to `val`, the first key and the first value in `tbl`,
then applying `f` to that result and the 2nd key and value, etc.  If
`tbl` contains no entries, returns `val` and `f` is not called.  Note
that `reduce-kv` is supported on sequential tables and strings, where
the keys will be the ordinals.

Early termination is possible with the use of `reduced`
function.

# Examples
Reduce associative table by adding values from all keys:

``` fennel
(local t {:a1 1
          :b1 2
          :a2 2
          :b2 3})

(reduce-kv #(+ $1 $3) 0 t)
;; => 8
```

Reduce table by adding values from keys that start with letter `a`:

``` fennel
(local t {:a1 1
          :b1 2
          :a2 2
          :b2 3})

(reduce-kv (fn [res k v] (if (= (string.sub k 1 1) :a) (+ res v) res))
           0 t)
;; => 3
```"
  [f val s]
  (if (map? s)
      (reduce (fn [res [k v]] (f res k v)) val (seq s))
      (reduce (fn [res [k v]] (f res k v)) val (map vector (drop 1 (range)) (seq s)))))

(defn completing
  "Takes a reducing function `f` of 2 args and returns a function
suitable for transduce by adding an arity-1 signature that calls
`cf` (default - `identity`) on the result argument."
  ([f] (completing f identity))
  ([f cf]
   (fn*
     ([] (f))
     ([x] (cf x))
     ([x y] (f x y)))))

(defn transduce
  "`reduce` with a transformation of `f` (`xform`). If `init` is not
supplied, `f` will be called to produce it. `f` should be a reducing
step function that accepts both 1 and 2 arguments, if it accepts only
2 you can add the arity-1 with `completing`. Returns the result of
applying (the transformed) `xform` to `init` and the first item in
`coll`, then applying `xform` to that result and the 2nd item, etc. If
`coll` contains no items, returns `init` and `f` is not called. Note
that certain transforms may inject or skip items."
  ([xform f coll] (transduce xform f (f) coll))
  ([xform f init coll]
   (let [f (xform f)]
     (f (reduce f init (seq coll))))))

(defn sequence
  "Coerces coll to a (possibly empty) sequence, if it is not already
one. Will not force a lazy seq. `(sequence nil)` yields an empty list,
When a transducer `xform` is supplied, returns a lazy sequence of
applications of the transform to the items in `coll`, i.e. to the set
of first items of each `coll`, followed by the set of second items in
each `coll`, until any one of the `colls` is exhausted.  Any remaining
items in other `colls` are ignored. The transform should accept
number-of-colls arguments"
  ([coll]
   (if (seq? coll) coll
       (or (seq coll) (list))))
  ([xform coll]
   (let [f (xform (completing #(cons $2 $1)))]
     (or ((fn step [coll]
            (if-some [s (seq coll)]
              (let [res (f nil (first s))]
                (cond (reduced? res) (f (deref res))
                      (seq? res) (concat res (lazy-seq* #(step (rest s))))
                      :else (step (rest s))))
              (f nil)))
          coll)
         (list))))
  ([xform coll & colls]
   (let [f (xform (completing #(cons $2 $1)))]
     (or ((fn step [colls]
            (if (every? seq colls)
                (let [res (apply f nil (map first colls))]
                  (cond (reduced? res) (f (deref res))
                        (seq? res) (concat res (lazy-seq* #(step (map rest colls))))
                        :else (step (map rest colls))))
                (f nil)))
          (cons coll colls))
         (list)))))

;;; Hash map

(fn map->transient [immutable]
  (fn [map]
    (let [removed (setmetatable {} {:__index deep-index})]
      (->> {:__index (fn [_ k]
                       (if (not (. removed k))
                           (. map k)))
            :cljlib/type :transient
            :cljlib/conj #(error "can't `conj` onto transient map, use `conj!`")
            :cljlib/assoc #(error "can't `assoc` onto transient map, use `assoc!`")
            :cljlib/dissoc #(error "can't `dissoc` onto transient map, use `dissoc!`")
            :cljlib/conj! (fn [tmap [k v]]
                            (if (= nil v)
                                (tset removed k true)
                                (tset removed k nil))
                            (doto tmap (tset k v)))
            :cljlib/assoc! (fn [tmap ...]
                             (for [i 1 (select "#" ...) 2]
                               (let [(k v) (select i ...)]
                                 (tset tmap k v)
                                 (if (= nil v)
                                     (tset removed k true)
                                     (tset removed k nil))))
                             tmap)
            :cljlib/dissoc! (fn [tmap ...]
                              (for [i 1 (select "#" ...)]
                                (let [k (select i ...)]
                                  (tset tmap k nil)
                                  (tset removed k true)))
                              tmap)
            :cljlib/persistent! (fn [tmap]
                                  (let [t (collect [k v (pairs tmap)
                                                    :into (collect [k v (pairs map)]
                                                            (values k v))]
                                            (values k v))]
                                    (each [k (pairs removed)]
                                      (tset t k nil))
                                    (each [_ k (ipairs (icollect [k (pairs* tmap)] k))]
                                      (tset tmap k nil))
                                    (setmetatable tmap
                                                  {:__index #(error "attempt to use transient after it was persistet")
                                                   :__newindex #(error "attempt to use transient after it was persistet")})
                                    (immutable (itable t))))}
           (setmetatable {})))))

(fn hash-map* [x]
  "Add cljlib hash-map meta-info."
  (match (getmetatable x)
    mt (doto mt
         (tset :cljlib/type :hash-map)
         (tset :cljlib/editable true)
         (tset :cljlib/conj
               (fn [t [k v] ...]
                 (apply core.assoc
                        t k v
                        (accumulate [kvs [] _ [k v] (ipairs* [...])]
                          (doto kvs
                            (table.insert k)
                            (table.insert v))))))
         (tset :cljlib/transient (map->transient hash-map*))
         (tset :cljlib/empty #(hash-map* (itable {}))))
    _ (hash-map* (setmetatable x {})))
  x)

(defn assoc
  "Associate `val` under a `key`.
Accepts extra keys and values.

# Examples

``` fennel
(assert-eq {:a 1 :b 2} (assoc {:a 1} :b 2))
(assert-eq {:a 1 :b 2} (assoc {:a 1 :b 1} :b 2))
(assert-eq {:a 1 :b 2 :c 3} (assoc {:a 1 :b 1} :b 2 :c 3))
```"
  ([tbl]
   (hash-map* (itable {})))
  ([tbl k v]
   (assert (or (nil? tbl) (map? tbl) (empty? tbl)) "expected a map")
   (assert (not (nil? k)) "attempt to use nil as key")
   (hash-map* (itable.assoc (or tbl {}) k v)))
  ([tbl k v & kvs]
   (assert (or (nil? tbl) (map? tbl) (empty? tbl)) "expected a map")
   (assert (not (nil? k)) "attempt to use nil as key")
   (hash-map* (apply itable.assoc (or tbl {}) k v kvs))))

(defn assoc-in
  "Associate `val` into set of immutable nested tables `t`, via given `key-seq`.
Returns a new immutable table.  Returns a new immutable table.

# Examples

Replace value under nested keys:

``` fennel
(assert-eq
 {:a {:b {:c 1}}}
 (assoc-in {:a {:b {:c 0}}} [:a :b :c] 1))
```

Create new entries as you go:

``` fennel
(assert-eq
 {:a {:b {:c 1}} :e 2}
 (assoc-in {:e 2} [:a :b :c] 1))
```"
  [tbl key-seq val]
  (assert (or (nil? tbl) (map? tbl) (empty? tbl)) "expected a map or nil")
  (hash-map* (itable.assoc-in tbl key-seq val)))

(defn update
  "Update table value stored under `key` by calling a function `f` on
that value. `f` must take one argument, which will be a value stored
under the key in the table.

# Examples

Same as `assoc` but accepts function to produce new value based on key value.

``` fennel
(assert-eq
 {:data \"THIS SHOULD BE UPPERCASE\"}
 (update {:data \"this should be uppercase\"} :data string.upper))
```"
  [tbl key f]
  (assert (or (nil? tbl) (map? tbl) (empty? tbl)) "expected a map")
  (hash-map* (itable.update tbl key f)))


(defn update-in
  "Update table value stored under set of immutable nested tables, via
given `key-seq` by calling a function `f` on the value stored under the
last key.  `f` must take one argument, which will be a value stored
under the key in the table.  Returns a new immutable table.

# Examples

Same as `assoc-in` but accepts function to produce new value based on key value.

``` fennel
(fn capitalize-words [s]
  (pick-values 1
    (s:gsub \"(%a)([%w_`]*)\" #(.. ($1:upper) ($2:lower)))))

(assert-eq
 {:user {:name \"John Doe\"}}
 (update-in {:user {:name \"john doe\"}} [:user :name] capitalize-words))
```"
  [tbl key-seq f]
  (assert (or (nil? tbl) (map? tbl) (empty? tbl)) "expected a map or nil")
  (hash-map* (itable.update-in tbl key-seq f)))

(defn hash-map
  "Create associative table from `kvs` represented as sequence of keys
and values"
  [& kvs]
  (apply assoc {} kvs))

(defn get
  "Get value from the table by accessing it with a `key`.
Accepts additional `not-found` as a marker to return if value wasn't
found in the table."
  ([tbl key] (get tbl key nil))
  ([tbl key not-found]
   (assert (or (map? tbl) (empty? tbl)) "expected a map")
   (or (. tbl key) not-found)))

(defn get-in
  "Get value from nested set of tables by providing key sequence.
Accepts additional `not-found` as a marker to return if value wasn't
found in the table."
  ([tbl keys] (get-in tbl keys nil))
  ([tbl keys not-found]
   (assert (or (map? tbl) (empty? tbl)) "expected a map")
   (var (res t done) (values tbl tbl nil))
   (each [_ k (ipairs* keys) :until done]
     (match (. t k)
       v (set (res t) (values v v))
       _ (set (res done) (values not-found true))))
   res))

(defn dissoc
  "Remove `key` from table `tbl`.  Optionally takes more `keys`."
  ([tbl] tbl)
  ([tbl key]
   (assert (or (map? tbl) (empty? tbl)) "expected a map")
   (hash-map* (doto tbl (tset key nil))))
  ([tbl key & keys]
   (apply dissoc (dissoc tbl key) keys)))

(defn merge
  "Merge `maps` rght to left into a single hash-map."
  [& maps]
  (when (some identity maps)
    (->> maps
         (reduce (fn [a b] (collect [k v (pairs* b) :into a]
                             (values k v)))
                 {})
         itable
         hash-map*)))

(defn frequencies
  "Return a table of unique entries from table `t` associated to amount
of their appearances.

# Examples

Count each entry of a random letter:

``` fennel
(let [fruits [:banana :banana :apple :strawberry :apple :banana]]
  (assert-eq (frequencies fruits)
             {:banana 3
              :apple 2
              :strawberry 1}))
```"
  [t]
  (hash-map* (itable.frequencies t)))

(defn group-by
  "Group table items in an associative table under the keys that are
results of calling `f` on each element of sequential table `t`.
Elements that the function call resulted in `nil` returned in a
separate table.

# Examples

Group rows by their date:

``` fennel
(local rows
  [{:date \"2007-03-03\" :product \"pineapple\"}
   {:date \"2007-03-04\" :product \"pizza\"}
   {:date \"2007-03-04\" :product \"pineapple pizza\"}
   {:date \"2007-03-05\" :product \"bananas\"}])

(assert-eq (group-by #(. $ :date) rows)
           {\"2007-03-03\"
            [{:date \"2007-03-03\" :product \"pineapple\"}]
            \"2007-03-04\"
            [{:date \"2007-03-04\" :product \"pizza\"}
             {:date \"2007-03-04\" :product \"pineapple pizza\"}]
            \"2007-03-05\"
            [{:date \"2007-03-05\" :product \"bananas\"}]})
```"
  [f t]
  (hash-map* (pick-values 1 (itable.group-by f t))))

(defn zipmap
  "Return an associative table with the `keys` mapped to the
corresponding `vals`."
  [keys vals]
  (hash-map* (itable (lazy.zipmap keys vals))))

(defn replace
  "Given a map of replacement pairs and a vector/collection `coll`,
returns a vector/seq with any elements `=` a key in `smap` replaced
with the corresponding `val` in `smap`.  Returns a transducer when no
collection is provided."
  ([smap]
   (map #(if-let [e (find smap $)] (. e 2) $)))
  ([smap coll]
   (if (vector? coll)
       (->> coll
            (reduce (fn [res v]
                      (if-let [e (find smap v)]
                        (doto res (table.insert (. e 2)))
                        (doto res (table.insert v))))
                    [])
            itable
            vec*)
       (map #(if-let [e (find smap $)] (. e 2) $) coll))))

;;; Conj

(defn conj
  "Insert `x` as a last element of a table `tbl`.

If `tbl` is a sequential table or empty table, inserts `x` and
optional `xs` as final element in the table.

If `tbl` is an associative table, that satisfies `map?` test,
insert `[key value]` pair into the table.

Mutates `tbl`.

# Examples
Adding to sequential tables:

``` fennel
(conj [] 1 2 3 4)
;; => [1 2 3 4]
(conj [1 2 3] 4 5)
;; => [1 2 3 4 5]
```

Adding to associative tables:

``` fennel
(conj {:a 1} [:b 2] [:c 3])
;; => {:a 1 :b 2 :c 3}
```

Note, that passing literal empty associative table `{}` will not work:

``` fennel
(conj {} [:a 1] [:b 2])
;; => [[:a 1] [:b 2]]
(conj (hash-map) [:a 1] [:b 2])
;; => {:a 1 :b 2}
```

See `hash-map` for creating empty associative tables."
  ([] (vector))
  ([s] s)
  ([s x]
   (match (getmetatable s)
     {:cljlib/conj f} (f s x)
     _ (if (vector? s) (vec* (itable.insert s x))
           (map? s) (apply assoc s x)
           (nil? s) (cons x s)
           (empty? s) (vector x)
           (error "expected collection, got" (type s)))))
  ([s x & xs]
   (apply conj (conj s x) xs)))

(defn disj
  "Returns a new set type, that does not contain the
specified `key` or `keys`."
  ([Set] Set)
  ([Set key]
   (match (getmetatable Set)
     {:cljlib/type :hash-set :cljlib/disj f} (f Set key)
     _ (error (.. "disj is not supported on " (class Set)) 2)))
  ([Set key & keys]
   (match (getmetatable Set)
     {:cljlib/type :hash-set :cljlib/disj f} (apply f Set key keys)
     _ (error (.. "disj is not supported on " (class Set)) 2))))

(defn pop
  "If `coll` is a list returns a new list without the first
item. If `coll` is a vector, returns a new vector without the last
item. If the collection is empty, raises an error. Not the same as
`next` or `butlast`."
  [coll]
  (match (getmetatable coll)
    {:cljlib/type :seq} (match (seq coll)
                          s (drop 1 s)
                          _ (error "can't pop empty list" 2))
    {:cljlib/pop f} (f coll)
    _ (error (.. "pop is not supported on " (class coll)) 2)))

;;; Transients

(defn transient
  "Returns a new, transient version of the collection."
  [coll]
  (match (getmetatable coll)
    {:cljlib/editable true :cljlib/transient f} (f coll)
    _ (error "expected editable collection" 2)))

(defn conj!
  "Adds `x` to the transient collection, and return `coll`."
  ([] (transient (vec* [])))
  ([coll] coll)
  ([coll x]
   (match (getmetatable coll)
     {:cljlib/type :transient :cljlib/conj! f} (f coll x)
     {:cljlib/type :transient} (error "unsupported transient operation" 2)
     _ (error "expected transient collection" 2))
   coll))

(defn assoc!
  "Remove `k`from transient map, and return `map`."
  [map k & ks]
  (match (getmetatable map)
    {:cljlib/type :transient :cljlib/dissoc! f} (apply f map k ks)
    {:cljlib/type :transient} (error "unsupported transient operation" 2)
    _ (error "expected transient collection" 2))
  map)

(defn dissoc!
  "Remove `k`from transient map, and return `map`."
  [map k & ks]
  (match (getmetatable map)
    {:cljlib/type :transient :cljlib/dissoc! f} (apply f map k ks)
    {:cljlib/type :transient} (error "unsupported transient operation" 2)
    _ (error "expected transient collection" 2))
  map)

(defn disj!
  "disj[oin]. Returns a transient set of the same type, that does not
contain `key`."
  ([Set] Set)
  ([Set key & ks]
   (match (getmetatable Set)
     {:cljlib/type :transient :cljlib/disj! f} (apply f Set key ks)
     {:cljlib/type :transient} (error "unsupported transient operation" 2)
     _ (error "expected transient collection" 2))))

(defn pop!
  "Removes the last item from a transient vector. If the collection is
empty, raises an error Returns coll"
  [coll]
  (match (getmetatable coll)
    {:cljlib/type :transient :cljlib/pop! f} (f coll)
    {:cljlib/type :transient} (error "unsupported transient operation" 2)
    _ (error "expected transient collection" 2)))

(defn persistent!
  "Returns a new, persistent version of the transient collection. The
transient collection cannot be used after this call, any such use will
raise an error."
  [coll]
  (match (getmetatable coll)
    {:cljlib/type :transient :cljlib/persistent! f} (f coll)
    _ (error "expected transient collection" 2)))

;;; Into

(defn into
  "Returns a new coll consisting of `to` with all of the items of `from`
conjoined. A transducer `xform` may be supplied.

# Examples

Insert items of one collection into another collection:

```fennel
(assert-eq [1 2 3 :a :b :c] (into [1 2 3] \"abc\"))
(assert-eq {:a 2 :b 3} (into {:a 1} {:a 2 :b 3}))
```

Transform a hash-map into a sequence of key-value pairs:

``` fennel
(assert-eq [[:a 1]] (into (vector) {:a 1}))
```

You can also construct a hash-map from a sequence of key-value pairs:

``` fennel
(assert-eq {:a 1 :b 2 :c 3}
           (into (hash-map) [[:a 1] [:b 2] [:c 3]]))
```"
  ([] (vector))
  ([to] to)
  ([to from]
   (match (getmetatable to)
     {:cljlib/editable true}
     (persistent! (reduce conj! (transient to) from))
     _ (reduce conj to from)))
  ([to xform from]
   (match (getmetatable to)
     {:cljlib/editable true}
     (persistent! (transduce xform conj! (transient to) from))
     _ (transduce xform conj to from))))

;;; Hash Set

(fn viewset [Set view inspector indent]
  (if (. inspector.seen Set)
      (.. "@set" (. inspector.seen Set) "{...}")
      (let [prefix (.. "@set"
                       (if (inspector.visible-cycle? Set)
                           (. inspector.seen Set) "")
                       "{")
            set-indent (length prefix)
            indent-str (string.rep " " set-indent)
            lines (icollect [v (pairs* Set)]
                    (.. indent-str
                        (view v inspector (+ indent set-indent) true)))]
        (tset lines 1 (.. prefix (string.gsub (or (. lines 1) "") "^%s+" "")))
        (tset lines (length lines) (.. (. lines (length lines)) "}"))
        lines)))

(fn hash-set->transient [immutable]
  (fn [hset]
    (let [removed (setmetatable {} {:__index deep-index})]
      (->> {:__index (fn [_ k]
                       (if (not (. removed k)) (. hset k)))
            :cljlib/type :transient
            :cljlib/conj #(error "can't `conj` onto transient set, use `conj!`")
            :cljlib/disj #(error "can't `disj` a transient set, use `disj!`")
            :cljlib/assoc #(error "can't `assoc` onto transient set, use `assoc!`")
            :cljlib/dissoc #(error "can't `dissoc` onto transient set, use `dissoc!`")
            :cljlib/conj! (fn [thset v]
                            (if (= nil v)
                                (tset removed v true)
                                (tset removed v nil))
                            (doto thset (tset v v)))
            :cljlib/assoc! #(error "can't `assoc!` onto transient set")
            :cljlib/assoc! #(error "can't `dissoc!` a transient set")
            :cljlib/disj! (fn [thset ...]
                            (for [i 1 (select "#" ...)]
                              (let [k (select i ...)]
                                (tset thset k nil)
                                (tset removed k true)))
                            thset)
            :cljlib/persistent! (fn [thset]
                                  (let [t (collect [k v (pairs thset)
                                                    :into (collect [k v (pairs hset)]
                                                            (values k v))]
                                            (values k v))]
                                    (each [k (pairs removed)]
                                      (tset t k nil))
                                    (each [_ k (ipairs (icollect [k (pairs* thset)] k))]
                                      (tset thset k nil))
                                    (setmetatable thset
                                                  {:__index #(error "attempt to use transient after it was persistet")
                                                   :__newindex #(error "attempt to use transient after it was persistet")})
                                    (immutable (itable t))))}
           (setmetatable {})))))

(fn hash-set* [x]
  (match (getmetatable x)
    mt (doto mt
         (tset :cljlib/type :hash-set)
         (tset :cljlib/conj
               (fn [s v ...]
                 (hash-set*
                  (itable.assoc
                   s v v
                   (unpack* (let [res []]
                              (each [ _ v (ipairs [...])]
                                (table.insert res v)
                                (table.insert res v))
                              res))))))
         (tset :cljlib/disj
               (fn [s k ...]
                 (let [to-remove
                       (collect [_ k (ipairs [...])
                                 :into (->> {:__index deep-index}
                                            (setmetatable {k true}))]
                         k true)]
                   (hash-set*
                    (itable.assoc {}
                                  (unpack*
                                   (let [res []]
                                     (each [_ v (pairs s)]
                                       (when (not (. to-remove v))
                                         (table.insert res v)
                                         (table.insert res v)))
                                     res)))))))
         (tset :cljlib/empty #(hash-set* (itable {})))
         (tset :cljlib/editable true)
         (tset :cljlib/transient (hash-set->transient hash-set*))
         (tset :cljlib/seq (fn [s] (map #(if (vector? $) (. $ 1) $) s)))
         (tset :__fennelview viewset)
         (tset :__fennelrest (fn [s i]
                               (var j 1)
                               (let [vals []]
                                 (each [v (pairs* s)]
                                   (if (>= j i)
                                       (table.insert vals v)
                                       (set j (+ j 1))))
                                 (core.hash-set (unpack* vals))))))
    _ (hash-set* (setmetatable x {})))
  x)

(defn hash-set
  "Create hash set.

Set is a collection of unique elements, which sore purpose is only to
tell you if something is in the set or not."
  [& xs]
  (let [Set (collect [_ val (pairs* xs)
                      :into (->> {:__newindex deep-newindex}
                                 (setmetatable {}))]
              (values val val))]
    (hash-set* (itable Set))))

;;; Multimethods

(defn multifn?
  "Test if `mf' is an instance of `multifn'.

`multifn' is a special kind of table, created with `defmulti' macros
from `macros.fnl'."
  [mf]
  (match (getmetatable mf)
    {:cljlib/type :multifn} true
    _ false))

(defn remove-method
  "Remove method from `multimethod' for given `dispatch-value'."
  [multimethod dispatch-value]
  (if (multifn? multimethod)
      (tset multimethod dispatch-value nil)
      (error (.. (tostring multimethod) " is not a multifn") 2))
  multimethod)

(defn remove-all-methods
  "Removes all methods of `multimethod'"
  [multimethod]
  (if (multifn? multimethod)
      (each [k _ (pairs multimethod)]
        (tset multimethod k nil))
      (error (.. (tostring multimethod) " is not a multifn") 2))
  multimethod)

(defn methods
  "Given a `multimethod', returns a map of dispatch values -> dispatch fns"
  [multimethod]
  (if (multifn? multimethod)
      (let [m {}]
        (each [k v (pairs multimethod)]
          (tset m k v))
        m)
      (error (.. (tostring multimethod) " is not a multifn") 2)))

(defn get-method
  "Given a `multimethod' and a `dispatch-value', returns the dispatch
`fn' that would apply to that value, or `nil' if none apply and no
default."
  [multimethod dispatch-value]
  (if (multifn? multimethod)
      (or (. multimethod dispatch-value)
          (. multimethod :default))
      (error (.. (tostring multimethod) " is not a multifn") 2)))

core
