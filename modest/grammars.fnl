;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(local {: P} (require :lpeg))

(local re (require :re))

(local common "
    tone <- { [A-G] }
    accidental <- (double_flat / flat / sharp / double_sharp) -> tosemitones
    
    flat <- ( 'b' / '♭' ) -> 'flat'
    sharp <- ( '#' / '♯' ) -> 'sharp'

    double_flat <- ( 'bb' / '𝄫') -> 'double-flat'
    double_sharp <- ( 'x' / '𝄪' ) -> 'double-sharp'
")

(local chord "
    chord <- {| root (power_chord / alt_chord / sus_chord / base_chord) |}

    base_chord <- quality? extended? add? chord_tail
    power_chord <- power bass_note?
    alt_chord <- (diminished / half_diminished / aug) extended_seventh? chord_tail
    sus_chord <- sus_ext? {:triad: sus :} chord_tail

    chord_tail <- alterations? bass_note?

    root <- {:root: note :}
    note <- {| tone accidental? |} -> tonote

    quality <- min_maj_quality /
               {:triad: maj :} maj_ext_capture &seventh / -- maj can notate major 7
               {:triad: min / maj / '' -> 'maj' :}

    maj <- ('maj' / 'ma' / 'Maj' / 'M' / triangle) -> 'maj'
    triangle <- '∆' / '∆' / 'Δ'
    min <- ('min' / 'mi' / 'm' !'aj' / '-') -> 'min'

    min_maj_quality <- {:triad: min_maj :} maj_ext_capture
    maj_ext_capture <- {:seventh: '' -> 'maj' => seventh :}

    min_maj <- min maj_extension
    maj_extension <- (maj / '(' maj ')' / '/' maj) &seventh

    maj_7 <- maj maj_ext_capture
    sus_ext <- maj_7? extended_seventh

    power <- {:triad: '5' -> 'power' :}

    diminished <- {:triad: ('dim' / 'o') -> 'dim':} (&seventh {:seventh: '' -> 'dim' => seventh :})?

    -- half-diminished chord is a seventh chord even if 7 isn't notated
    half_diminished <- {:triad: crossed_o -> 'dim':} (&seventh / {:ext: '' -> toseven :}) {:seventh: '' -> 'min' => seventh :}

    crossed_o <- '⌀' / 'Ø' / 'ø'
    aug <- {:triad: ('+' / 'aug') -> 'aug' :} (maj_7 &extended_seventh)?

    sixth <- {:ext: '6' -> tonumber :}
    seventh <- ('7' / '9' / '11' / '13') -> tonumber

    extended_seventh <- {:ext: seventh :} {:seventh: '' -> 'min' => seventh :}

    extended_sixth <- sixth (sixth_add9 !add)?
    sixth_add9 <- '/' {:add: '9' -> tonumber :} -- matches 6/9 chords

    extended <- extended_seventh / extended_sixth

    sus <- {| { 'sus' } ('2' / '4' / '' -> '4') -> tonumber |}

    add_interval <- ('2' / '4' / '9' / '11' / '13') -> tonumber
    add <- 'add' {:add: add_interval:}

    alteration_interval <- ('4' / '5' / '6' / '9' / '11' / '13') -> tonumber
    alteration <- {| accidental alteration_interval |}
    alterations <- {:alterations: ('(' {| alteration+ |} ')' / {| alteration+ |}) :}

    bass_note <- '/' {:bass: note :}
")

(local note "
    note <- {| tone (accidental / ('' -> tozero)) octave? |} -> tonote
    octave <- [0-9] -> tonumber
")

(local interval "
    interval <- {| quality steps |} -> tointerval
    quality <- 'M' -> 'maj' /
               'm' -> 'min' /
               'A' -> 'aug' /
               'd' -> 'dim' /
               'P' -> 'perfect'
    steps <- ([1-9] [0-9]*) -> tonumber
")

(fn define-grammar [grammar transformers]
  (let [pattern (* (re.compile (.. grammar common)
                               transformers)
                   (- (P 1)))] ;; (- (P 1)) ensures that the entire input string matches
    (fn [s]
      (pattern:match s))))

(fn define-chord-grammar [transformers]
  (var seventh-quality nil)
  
  ;; This function ensures that the quality of the seventh
  ;; ("maj", "min", "dim") is only set once.
  ;; If the seventh quality has already been matched, it returns the first matched quality
  ;; instead of overwriting it with a subsequent match.
  (fn seventh [_ pos new-quality]
    (if (not seventh-quality)
        (do (set seventh-quality new-quality)
            (values pos new-quality))
        (values pos seventh-quality)))
  
  (set transformers.seventh seventh)
  
  (let [chord (define-grammar chord transformers)]
    (fn [s]
      (set seventh-quality nil)
      (chord s))))

;; transforming functions are passed as arguments to avoid circular dependency
(fn grammars [tonote tointerval tosemitones]
  (let [transformers {: tonote
                      : tonumber
                      : tosemitones
                      : tointerval
                      :toseven (fn [] 7)
                      :totrue (fn [] true)
                      :tozero (fn [] 0)}]
  {:chord (define-chord-grammar transformers)
   :interval (define-grammar interval transformers)
   :note (define-grammar note transformers)}))

grammars

