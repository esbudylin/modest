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
    maj_ext_capture <- {:maj_ext: '' -> totrue:}
    
    min_maj <- min maj_extension
    maj_extension <- (maj / '(' maj ')' / '/' maj) &seventh

    maj_7 <- maj maj_ext_capture
    sus_ext <- maj_7? extended_seventh

    power <- {:triad: '5' -> 'power' :}

    diminished <- {:triad: ('dim' / 'o') -> 'dim':} 

    -- half-diminished chord is a seventh chord even if 7 isn't notated
    half_diminished <- {:triad: crossed_o -> 'half-dim':} (&seventh / {:ext: '' -> toseven :})

    crossed_o <- '⌀' / 'Ø' / 'ø'
    aug <- {:triad: ('+' / 'aug') -> 'aug' :} (maj_7 &extended_seventh)?

    sixth <- {:ext: '6' -> tonumber :}
    seventh <- ('7' / '9' / '11' / '13' / '15') -> tonumber

    extended_seventh <- {:ext: seventh :}

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

;; transforming functions are passed as arguments to avoid circular dependency
(fn grammars [tonote tointerval tosemitones]
  (let [transformers {: tointerval
                      : tonote
                      : tonumber
                      : tosemitones
                      :toseven (fn [] 7)
                      :totrue (fn [] true)
                      :tozero (fn [] 0)}
        ;; (- (P 1)) ensures that the entire input string matches
        grammar #(* (re.compile (.. $ common) transformers)
                    (- (P 1)))]
    {:chord (grammar chord)
     :interval (grammar interval)
     :note (grammar note)}))

grammars

