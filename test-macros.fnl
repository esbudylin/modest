;; fennel-ls: macro-file

;; Any copyright is dedicated to the Public Domain.
;; https://creativecommons.org/publicdomain/zero/1.0/

(fn parameterized [name params func]
  (icollect [i p (ipairs params)]
    `(let [fennel# (require :fennel)
           unpack# (or _G.unpack table.unpack)
           param-view# (fennel#.view ,p)
           foo# (fn []
                  (case (pcall #(,func (unpack# ,p)))
                    (where (_# err#) (not= err# nil))
                    (error (.. err#
                               "\n"
                               :parameters " "
                               param-view#))))]
       (tset _G ,(.. :test_ name "_" i) foo#))))

{: parameterized}
