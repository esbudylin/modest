- [Modest](#orgfe4d01f)
  - [Features](#orgdcabe4e)
  - [Installation](#org9f368be)
    - [Manual installation](#orga603833)
  - [General Information](#org8f92e48)
    - [Lua version support](#org4612bd8)
    - [Immutability](#org59a9288)
    - [String parsing](#orgcd30050)
    - [Representation of accidentals](#orgc536892)
    - [Metamethods](#orgdc3d4ab)
    - [Trivia](#orgae28a4d)
  - [Documentation](#orgeb25a0e)
    - [Chord](#org27a928f)
      - [fromstring(string) -> Chord](#orga798d05)
      - [transpose(self, interval) -> Chord](#org50e334b)
      - [transpose\_down(self, interval) -> Chord](#orgae83427)
      - [notes(self, octave=nil) -> [Note]](#org77f8761)
      - [numeric(self) -> [int]](#org6abf114)
      - [tostring(self, ascii=nil) -> string](#orgc3c98b6)
      - [toascii(self) -> string](#orga2c8049)
    - [Interval](#orged339ef)
      - [fromstring(string) -> Interval](#orgb783526)
      - [new(size, quality="perfect") -> Note](#orga58d9ea)
      - [identify(note1, note2) -> Interval](#orgbaa3a37)
      - [semitones(self) -> int](#org981c0f4)
      - [tostring(self) -> string](#org05d4e63)
    - [Note](#orge532c5e)
      - [fromstring(string) -> Note](#org3698d18)
      - [new(tone, accidental=0, octave=nil) -> Note](#org15b0881)
      - [transpose(self, interval) -> Note](#org76e5ba6)
      - [transpose\_down(self, interval) -> Note](#orga6697c3)
      - [pitch\_class(self) -> int](#orgac90010)
      - [tostring(self, ascii) -> string](#org43b6281)
      - [toascii(self) -> string](#orgf332bb2)
  - [Similar libraries in other languages](#org799c25f)



<a id="orgfe4d01f"></a>

# Modest

Musical harmony library for Lua.


<a id="orgdcabe4e"></a>

## Features

-   Chord Object. Supports a wide range of chords, from simple major/minor to complex jazz chords. Can transpose chords and retrieve individual notes. Provides a flexible string parsing.
-   Note Object. Handles alterations (sharps, flats, double accidentals), octaves, pitch classes.
-   Interval Object. Supports simple and compound intervals. Can identify the interval between two notes and represent it in semitones.


<a id="org9f368be"></a>

## Installation

The easiest way to install Modest is via [LuaRocks](https://luarocks.org/).

```sh
luarocks install modest-harmony
```


<a id="orga603833"></a>

### Manual installation

If you want to avoid LuaRocks, you should consider two things about the project. First, Modest depends on [LPeg](https://www.inf.puc-rio.br/~roberto/lpeg/), a library partially written in C, which you will need to install manually. Second, the project is written in Fennel, a language that transpiles to Lua. To use Modest in your Lua code, you can either embed Fennel compiler in your project or perform ahead-of-time compilation of the Fennel files. I recommend the latter option. To do so, [install Fennel](https://fennel-lang.org/setup#downloading-fennel) and run the following command from the project's root directory:

```sh
fennel --require-as-include --skip-include re,lpeg --compile modest/init.fnl > modest.lua
```

After running the command, move the resulting modest.lua file into your project and require it as you would any other Lua module.


<a id="org8f92e48"></a>

## General Information


<a id="org4612bd8"></a>

### Lua version support

-   The library supports both Lua 5.4 and LuaJIT. It should also be compatible with older Lua 5.x versions.


<a id="org59a9288"></a>

### Immutability

-   Methods in the library do not mutate objects; instead, they return new instances. However, as these instances are regular Lua tables, they can still be modified after creation. It is strongly advised **not** to mutate them, as this could lead to unexpected behavior.


<a id="orgcd30050"></a>

### String parsing

-   Each object provides a 'fromstring' method, allowing object construction through string parsing. While Interval and Note requires strings in a strict format, Chord can parse almost any notation that may be encountered in musical scores or chord charts.
-   Any method that requires one of the library objects as an argument can also accept a string, which will be parsed using the appropriate 'fromstring' method. For example, both of the following expressions are valid.
    
    ```lua
    local note = Note.fromstring("C5")
    note:transpose("P5")
    note:transpose(Interval.fromstring("P5"))
    ```


<a id="orgc536892"></a>

### Representation of accidentals

-   The library supports two types of accidental representation: special Unicode symbols ('♯' for sharp, '♭' for flat, '𝄪' for double sharp, '𝄫' for double flat) and ASCII characters ('#', 'b', 'x', 'bb', respectively).
-   The parsers of the Note and Chord objects can handle both types. When transforming these objects into strings, different methods are available for each representation (see below).


<a id="orgdc3d4ab"></a>

### Metamethods

-   Each object implements '\_\_tostring' metamethod. In Lua, this metamethod is automatically called when an object needs to be represented as a string, such as during string concatenation or when using the 'print' function. It uses Unicode symbols for accidentals.


<a id="orgae28a4d"></a>

### Trivia

-   Modest is named after Modest Petrovich Mussorgsky, the great Russian composer.


<a id="orgeb25a0e"></a>

## Documentation


<a id="org27a928f"></a>

### Chord


<a id="orga798d05"></a>

#### fromstring(string) -> Chord

-   Parses a string and returns a Chord object.
-   Example:
    
    ```lua
    local chord = Chord.fromstring("Cmaj7")
    print(chord)
    ```
    
        Cmaj7


<a id="org50e334b"></a>

#### transpose(self, interval) -> Chord

-   Returns a new Chord transposed by the given interval.
-   Example:
    
    ```lua
    local transposed = Chord.fromstring("C6/9"):transpose("m3")
    print(transposed)
    ```
    
        E♭6/9


<a id="orgae83427"></a>

#### transpose\_down(self, interval) -> Chord

-   Similar to transpose, returns a chord transposed down by the given interval.
-   Example:
    
    ```lua
    local transposed_down = Chord.fromstring("Ab9"):transpose_down("P5")
    print(transposed_down)
    ```
    
        D♭9


<a id="org77f8761"></a>

#### notes(self, octave=nil) -> [Note]

-   Returns the notes that make up the chord. Optionally, specify the octave of the root note.
-   Example:
    
    ```lua
    local notes = Chord.fromstring("F#"):notes(4)
    for _, note in ipairs(notes) do print(note) end
    ```
    
        F♯4
        A♯4
        C♯5


<a id="org6abf114"></a>

#### numeric(self) -> [int]

-   Converts the chord into a numeric representation, with each note represented as the number of semitones from the C of the chord's root octave.
-   Examples:
    
    ```lua
    local numeric = Chord.fromstring("C/Bb"):numeric()
    print(table.concat(numeric, ", "))
    ```
    
        -2, 0, 4, 7
    
    ```lua
    local numeric = Chord.fromstring("G9"):numeric()
    print(table.concat(numeric, ", "))
    ```
    
        7, 11, 14, 17, 21


<a id="orgc3c98b6"></a>

#### tostring(self, ascii=nil) -> string

-   Converts the chord into a string. By default accidental will be represented with special Unicode characters. Pass a true value as a parameter to get an ASCII representation.
-   Example:
    
    ```lua
    local chord = Chord.fromstring("C#maj7")
    print(chord:tostring())
    print(chord:tostring(true))
    ```
    
        C♯maj7
        C#maj7


<a id="orga2c8049"></a>

#### toascii(self) -> string

-   Shorthand for chord:tostring(true). Returns the chord as a string with ASCII representations for accidentals.
-   Example:
    
    ```lua
    local chord = Chord.fromstring("G7#11")
    print(chord:toascii())
    ```
    
        G7(#11)


<a id="orged339ef"></a>

### Interval


<a id="orgb783526"></a>

#### fromstring(string) -> Interval

-   Parses a string and returns an Interval object. Examples:
    -   "m3" = minor third
    -   "P4" = perfect fourth
    -   "A5" = augmented fifth
    -   "d7" = diminished seventh
    -   "M6" = major sixth.
-   Example:
    
    ```lua
    local interval = Interval.fromstring("P4")
    print(interval)
    ```
    
        P4


<a id="orga58d9ea"></a>

#### new(size, quality="perfect") -> Note

-   Creates a new Interval object. Size should be an integer, and quality should be a string (valid options are "dim", "aug", "min", "maj", "perfect"). The method raises an error if the interval is invalid.
-   Examples:
    
    ```lua
    local interval = Interval.new(3, "aug")
    print(interval)
    ```
    
        A3
    
    ```lua
    local interval = Interval.new(13, "maj")
    print(interval)
    ```
    
        M13
    
    ```lua
    local interval = Interval.new(5)
    print(interval)
    ```
    
        P5
    
    ```lua
    local _, err = pcall(function() Interval.new(5, "min") end)
    print(err)
    ```
    
        ./modest.lua:263: Invalid combination of size and quality


<a id="orgbaa3a37"></a>

#### identify(note1, note2) -> Interval

-   Identifies the interval between two notes.
-   Example:
    
    ```lua
    local interval = Interval.identify("C", "F")
    print(interval)
    ```
    
        P4


<a id="org981c0f4"></a>

#### semitones(self) -> int

-   Returns the number of semitones in the interval.
-   Examples:
    
    ```lua
    local semitones = Interval.fromstring("M3"):semitones()
    print(semitones)
    ```
    
        4


<a id="org05d4e63"></a>

#### tostring(self) -> string

-   Converts the interval into a string representation.
-   Example:
    
    ```lua
    local interval = Interval.new(6, "min"):tostring()
    print(interval)
    ```
    
        m6


<a id="orge532c5e"></a>

### Note


<a id="org3698d18"></a>

#### fromstring(string) -> Note

-   Parses a string and returns a Note object.
-   Examples:
    
    ```lua
    local note = Note.fromstring("C#4")
    print(note)
    ```
    
        C♯4
    
    ```lua
    local note = Note.fromstring("E") -- the octave is optional
    print(note)
    ```
    
        E


<a id="org15b0881"></a>

#### new(tone, accidental=0, octave=nil) -> Note

-   Creates a new Note object. The tone should be a capital letter (e.g., "C"). The accidental should be a numeric value (e.g., -1 for flat, 1 for sharp). The octave is optional.
-   Examples:
    
    ```lua
    local note = Note.new("D", 1, 5)
    print(note)
    ```
    
        D♯5
    
    ```lua
    local note = Note.new("B", -2)
    print(note)
    ```
    
        B𝄫


<a id="org76e5ba6"></a>

#### transpose(self, interval) -> Note

-   Returns a new note transposed by the given interval.
-   Example:
    
    ```lua
    local transposed = Note.fromstring("C4"):transpose("P4")
    print(transposed)
    ```
    
        F4


<a id="orga6697c3"></a>

#### transpose\_down(self, interval) -> Note

-   Returns a new note transposed down by the given interval.
-   Example:
    
    ```lua
    local transposed_down = Note.fromstring("C4"):transpose_down("m3")
    print(transposed_down)
    ```
    
        A3


<a id="orgac90010"></a>

#### pitch\_class(self) -> int

-   Returns a number from 0 to 11 representing the pitch class of the note (e.g., C=0, C♯/D♭=1, &#x2026;, B=11).
-   Example:
    
    ```lua
    local note = Note.fromstring("G")
    print(note:pitch_class())
    ```
    
        7


<a id="org43b6281"></a>

#### tostring(self, ascii) -> string


<a id="orgf332bb2"></a>

#### toascii(self) -> string

-   Works similarly to the Chord methods of the same name.
-   Example:
    
    ```lua
    local note = Note.fromstring("D#4")
    print(note:tostring())
    print(note:tostring(true))
    print(note:toascii())
    ```
    
        D♯4
        D#4
        D#4


<a id="org799c25f"></a>

## Similar libraries in other languages

-   [Mingus](https://github.com/bspaans/python-mingus) for Python,
-   [Sharp11](https://github.com/jsrmath/sharp11) for JavaScript,
-   [Teoria](https://github.com/saebekassebil/teoria) for JavaScript,
-   [Tonal](https://github.com/tonaljs/tonal) for JavaScript.
