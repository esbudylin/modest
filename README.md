# Modest

Musical harmony library for Lua.


## Features

-   [Chord Object](#orge083022). Supports a wide range of chords, from simple major/minor to complex jazz chords. Provides a flexible string parsing, can identify a chord based on its notes. Can transpose chords and retrieve individual notes.
-   [Note Object](#orgc496bdf). Handles alterations (sharps, flats, double accidentals), octaves, pitch classes.
-   [Interval Object](#org3ad98c3). Supports simple and compound intervals. Can identify the interval between two notes and represent it in semitones.


## Installation

The easiest way to install Modest is via [LuaRocks](https://luarocks.org/).

```sh
luarocks install modest-harmony
```


### Manual installation

If you want to avoid LuaRocks, you should consider two things about the project. First, Modest depends on [LPeg](https://www.inf.puc-rio.br/~roberto/lpeg/), a library partially written in C, which you will need to install separately. Second, the project is written in Fennel, a language that transpiles to Lua. To use Modest in your Lua code, you can either embed Fennel compiler in your project or perform ahead-of-time compilation of the Fennel files. I recommend the latter option. To do so, [install Fennel](https://fennel-lang.org/setup#downloading-fennel) and run the following command from the project's root directory:

```sh
fennel --require-as-include --skip-include re,lpeg --compile modest/init.fnl > modest.lua
```

After running the command, move the resulting modest.lua file into your project and require it as you would any other Lua module.


## General Information


### Lua version support

-   The library supports both Lua 5.4 and LuaJIT. It should also be compatible with older Lua 5.x versions.


### Immutability

-   Methods in the library do not mutate objects; instead, they return new instances. However, as these instances are regular Lua tables, they can still be modified after creation. It is strongly advised **not** to mutate them, as this could lead to unexpected behavior.


### String parsing

-   Each object provides a 'fromstring' method, allowing object construction through string parsing. While Interval and Note requires strings in a strict format, Chord can parse almost any notation that may be encountered in musical scores or chord charts.
-   Any method that requires one of the library objects as an argument can also accept a string, which will be parsed using the appropriate 'fromstring' method. For example, both of the following expressions are valid.
    
    ```lua
    note = Note.fromstring("C5")
    note:transpose("P5")
    note:transpose(Interval.fromstring("P5"))
    ```


### Representation of accidentals

-   The library supports two types of accidental representation: special Unicode symbols ('♯' for sharp, '♭' for flat, '𝄪' for double sharp, '𝄫' for double flat) and ASCII characters ('#', 'b', 'x', 'bb', respectively).
-   The parsers of the Note and Chord objects can handle both types. When transforming these objects into strings, different methods are available for each representation (see below).


### Metamethods

-   Each object implements '\_\_tostring' metamethod. In Lua, this metamethod is automatically called when an object needs to be represented as a string, such as during calls to 'print' or 'tostring' functions. The implementation uses Unicode symbols for accidentals.


### Trivia

-   Modest is named after Modest Petrovich Mussorgsky.


## Documentation

1.  [Chord](#orge083022)
    1.  [fromstring(string) -> Chord](#org3e1e1cd)
    2.  [identify(& notes) -> Chord](#orgf5219df)
    3.  [transpose(self, interval) -> Chord](#org306bfb8)
    4.  [transpose\_down(self, interval) -> Chord](#org881e81e)
    5.  [notes(self, octave=nil) -> [Note]](#org11ad2b2)
    6.  [numeric(self) -> [int]](#org8756318)
    7.  [tostring(self) -> string](#orgb363cd5)
    8.  [toascii(self) -> string](#org148bfd4)
2.  [Interval](#org3ad98c3)
    1.  [fromstring(string) -> Interval](#org0584552)
    2.  [new(size, quality="perfect") -> Note](#org69d502e)
    3.  [identify(note1, note2) -> Interval](#org2782435)
    4.  [semitones(self) -> int](#org95c7f9b)
    5.  [tostring(self) -> string](#org5daed0b)
3.  [Note](#orgc496bdf)
    1.  [fromstring(string) -> Note](#org61a9313)
    2.  [new(tone, accidental=0, octave=nil) -> Note](#orga039f43)
    3.  [transpose(self, interval) -> Note](#orgfe70cca)
    4.  [transpose\_down(self, interval) -> Note](#org6e87c5f)
    5.  [pitch\_class(self) -> int](#org33f3b89)
    6.  [tostring(self) -> string](#orgf02a9a1)
    7.  [toascii(self) -> string](#org6a1e579)


<a id="orge083022"></a>

### Chord


<a id="org3e1e1cd"></a>

#### fromstring(string) -> Chord

-   Parses a string and returns a Chord object. Supports most of the chord types (see table below). Aims to be as flexible as possible when parsing a chord suffix, allowing various synonymous notations.

| Supported chord type           | Examples             |
|------------------------------ |-------------------- |
| Basic triads                   | C, Cm                |
| Augmented chords               | Caug                 |
| Diminished and half-diminished | Cdim, C⌀7, Cdim7     |
| Suspended chords               | Csus2, C9sus4        |
| Seventh chords                 | C7, CM7, CminMaj7    |
| Extended chords up to the 13th | C9, C13              |
| Added sixth and 6/9 chords     | C6, Cm(♭6), C6/9     |
| Added tones                    | Cadd2, Cadd9, C(♯11) |
| Altered chords                 | C7♯5, C7♯5♭9         |
| Power chords                   | C5                   |
| Slash chords                   | C/G                  |

-   Example:
    
    ```lua
    CM7 = Chord.fromstring("Cmaj7")
    ```


<a id="orgf5219df"></a>

#### identify(& notes) -> Chord

-   Identifies a chord based on the given notes. Accepts a variable number of string representations (e.g., "C", "E", "G") or Note objects. Assumes the first argument for a chord root. If the octaves of the given notes are not specified, assumes they go in ascending order. Supports the same types of chords as the 'fromstring' method, except for slash chords. Does not support inversions. Raises an error if the notes do not form a recognizable chord.
-   Examples:
    
    ```lua
    Cadd9 = Chord.identify("C", "E", "G", "D")
    
    -- Can also accept note objects
    Daug = Chord.identify("D", "F#", Note.fromstring("A#"))
    ```


<a id="org306bfb8"></a>

#### transpose(self, interval) -> Chord

-   Returns a new Chord transposed by the given interval.
-   Example:
    
    ```lua
    Eb6_9 = Chord.fromstring("C6/9"):transpose("m3")
    ```


<a id="org881e81e"></a>

#### transpose\_down(self, interval) -> Chord

-   Similar to transpose, returns a chord transposed down by the given interval.
-   Example:
    
    ```lua
    Db9 = Chord.fromstring("Ab9"):transpose_down("P5")
    ```


<a id="org11ad2b2"></a>

#### notes(self, octave=nil) -> [Note]

-   Returns the notes that make up the chord. Optionally, specify the octave of the root note.
-   Example:
    
    ```lua
    notes = Chord.fromstring("F#"):notes(4)
    for _, note in ipairs(notes) do print(note) end
    ```


<a id="org8756318"></a>

#### numeric(self) -> [int]

-   Converts the chord into a numeric representation, with each note represented as the number of semitones from the C of the chord's root octave.
-   Examples:
    
    ```lua
    numeric = Chord.fromstring("C/Bb"):numeric()
    print(table.concat(numeric, ", "))
    ```
    
    ```lua
    numeric = Chord.fromstring("G9"):numeric()
    print(table.concat(numeric, ", "))
    ```


<a id="orgb363cd5"></a>

#### tostring(self) -> string

-   Converts the chord into a string. Accidentals will be represented with special Unicode characters.
-   Example:
    
    ```lua
    chord = Chord.fromstring("C#maj7")
    assert(chord:tostring() == "C♯M7")
    ```


<a id="org148bfd4"></a>

#### toascii(self) -> string

-   Returns the chord as a string with ASCII representations for accidentals.
-   Example:
    
    ```lua
    chord = Chord.fromstring("G7#11")
    assert(chord:toascii() == "G7(#11)")
    ```


<a id="org3ad98c3"></a>

### Interval


<a id="org0584552"></a>

#### fromstring(string) -> Interval

-   Parses a string and returns an Interval object. Examples:
    -   "m3" = minor third
    -   "P4" = perfect fourth
    -   "A5" = augmented fifth
    -   "d7" = diminished seventh
    -   "M6" = major sixth.
-   Example:
    
    ```lua
    P4 = Interval.fromstring("P4")
    ```


<a id="org69d502e"></a>

#### new(size, quality="perfect") -> Note

-   Creates a new Interval object. Size should be an integer, and quality should be a string (valid options are "dim", "aug", "min", "maj", "perfect"). The method raises an error if the interval is invalid.
-   Examples:
    
    ```lua
    A3 = Interval.new(3, "aug")
    M13 = Interval.new(13, "maj")
    P5 = Interval.new(5)
    ```
    
    ```lua
    _, err = pcall(function() Interval.new(5, "min") end)
    print(err)
    ```


<a id="org2782435"></a>

#### identify(note1, note2) -> Interval

-   Identifies the interval between two notes.
-   Example:
    
    ```lua
    P4 = Interval.identify("C", "F")
    ```


<a id="org95c7f9b"></a>

#### semitones(self) -> int

-   Returns the number of semitones in the interval.
-   Examples:
    
    ```lua
    semitones = Interval.fromstring("M3"):semitones()
    assert(semitones == 4)
    ```


<a id="org5daed0b"></a>

#### tostring(self) -> string

-   Converts the interval into a string representation.
-   Example:
    
    ```lua
    m6 = Interval.new(6, "min"):tostring()
    ```


<a id="orgc496bdf"></a>

### Note


<a id="org61a9313"></a>

#### fromstring(string) -> Note

-   Parses a string and returns a Note object.
-   Examples:
    
    ```lua
    C_sharp_4 = Note.fromstring("C#4")
    E = Note.fromstring("E") -- the octave is optional
    ```


<a id="orga039f43"></a>

#### new(tone, accidental=0, octave=nil) -> Note

-   Creates a new Note object. The tone should be a capital letter (e.g., "C"). The accidental should be a numeric value (e.g., -1 for flat, 1 for sharp). The octave is optional.
-   Examples:
    
    ```lua
    D_sharp_5 = Note.new("D", 1, 5)
    B_double_flat = Note.new("B", -2)
    ```


<a id="orgfe70cca"></a>

#### transpose(self, interval) -> Note

-   Returns a new note transposed by the given interval.
-   Example:
    
    ```lua
    F4 = Note.fromstring("C4"):transpose("P4")
    ```


<a id="org6e87c5f"></a>

#### transpose\_down(self, interval) -> Note

-   Returns a new note transposed down by the given interval.
-   Example:
    
    ```lua
    A3 = Note.fromstring("C4"):transpose_down("m3")
    ```


<a id="org33f3b89"></a>

#### pitch\_class(self) -> int

-   Returns a number from 0 to 11 representing the pitch class of the note (e.g., C=0, C♯/D♭=1, &#x2026;, B=11).
-   Example:
    
    ```lua
    pitch_class = Note.fromstring("G"):pitch_class()
    assert(pitch_class == 7)
    ```


<a id="orgf02a9a1"></a>

#### tostring(self) -> string


<a id="org6a1e579"></a>

#### toascii(self) -> string

-   Works similarly to the Chord methods of the same name.
-   Example:
    
    ```lua
    note = Note.fromstring("D#4")
    
    assert(note:tostring() == "D♯4")
    assert(note:toascii() == "D#4")
    ```


## Similar libraries in other languages

-   [Mingus](https://github.com/bspaans/python-mingus) for Python,
-   [Sharp11](https://github.com/jsrmath/sharp11) for JavaScript,
-   [Teoria](https://github.com/saebekassebil/teoria) for JavaScript,
-   [Tonal](https://github.com/tonaljs/tonal) for JavaScript.
