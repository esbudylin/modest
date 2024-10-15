;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; public interface of the library

(local {: Interval : Note} (require :modest.basics))
(local Chord (require :modest.chord))

{: Note : Interval : Chord}
