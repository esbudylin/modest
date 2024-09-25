(fn parameterized [name params func]
  (icollect [i p (ipairs params)]
    `(tset _G ,(.. :test_ name "_" i)
             #(,func ((or _G.unpack table.unpack) ,p)))))

{: parameterized}
