;; public interface of the library

(local b (require :src.basics))
(local (Interval Note) (values b.Interval b.Note))
(local Chord (require :src.chord))

(local u (require :utils))
(local apply u.apply)

(local grammars (require :src.grammars))

;; macro to monkey-patch a sequential table of functions
(macro defadvice [foos advice]
  (icollect [_ foo (ipairs foos)]
    `(let [bar# ,foo]
       (fn ,foo [...]
         ((partial ,advice bar#) ...)))))

;; luajit support
(when _G.unpack
  (tset table :unpack _G.unpack))

(fn parse [grammar str]
  (or (grammar:match str)
      (error (.. "Can't parse: " str))))

(fn parse-if-strings [grammar args]
  (icollect [_ arg (ipairs args)]
    (if (= (type arg) :string) (parse grammar arg) arg)))

(fn Note.fromstring [str]
  (parse grammars.note str)) 

(fn Interval.fromstring [str]
  (parse grammars.interval str))

(defadvice
 [Note.transpose Note.transpose_down Chord.transpose Chord.transpose_down]
 (fn [foo self & args]
   (apply (partial foo self) 
          (parse-if-strings grammars.interval args))))

(defadvice
 [Interval.identify]
 (fn [foo & args]
   (apply foo (parse-if-strings grammars.note args))))

(fn Chord.fromstring [str]
  (let [t (parse grammars.chord str)]
    (Chord.transform t)))

{: Note : Interval : Chord}
