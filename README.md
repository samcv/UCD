* [UCD-gen.p6](#ucdgenp6)
* [lib/UCDlib.pm6](#libucdlibpm6)
* [lib/bitfield-rows-switch.pm6](#libbitfieldrowsswitchpm6)
* [Unicode-Grant/lib/PropertyValueAliases.pm6](#unicodegrantlibpropertyvaluealiasespm6)
* [Unicode-Grant/lib/PropertyAliases.pm6](#unicodegrantlibpropertyaliasespm6)
* [lib/ArrayCompose.pm6](#libarraycomposepm6)

[![Build Status](https://travis-ci.org/samcv/UCD.svg?branch=master)](https://travis-ci.org/samcv/UCD)

## What
This is work towards a rewrite of the `ucd2c.pl` script that generates our
Unicode database on MoarVM.

## How do I build this
Install all dependant modules, if you have zef:
`zef --depsonly install .`
Download the Unicode database files:
`perl6 UCD-download.p6`

Then make sure ./Unicode-Grant which is a git submodule is also checked out
`git submodule update --init --recursive`

Generate the C files with
`perl6 UCD-gen.p6`

They will be placed in `./source`

Running `make` will build `bitfield` and `names` and put them in `./build`

# UCD-gen.p6

`%names`
--------

Unicode Name hash for generating the name table

`%binary-properties`
--------------------

Stores the binary property names

`%enumerated-properties`
------------------------

Stores enum prop names and also the property codes which are just internal numbers to represent it in the C datastructure

`%decomp_spec`
--------------

Stores the decomposition data for decomposition

`%PropertyValueAliases_to`
--------------------------

Stores PropertyValueAliases from PropertyValueAliases.txt Used to go from short property value names to full names. Is a hash where the keys are full length property names, and the level below that has keys of property value alias names and the values are full property value names.

#### Example:

    Bidi_Class => ${:AL("Arabic_Letter"), :AN("Arabic_Number"),
        :Arabic_Letter("Arabic_Letter"), :Arabic_Number("Arabic_Number"),
        :B("Paragraph_Separator"), :BN("Boundary_Neutral") }

`%PropertyNameAliases %PropertyNameAliases_to`
----------------------------------------------

Stores Property Aliases or Property Value Aliases to their Full Name mappings

### sub make-property-switches

```perl6
sub make-property-switches(
    @code-sorted-props
) returns Mu
```

Makes the C functions which go from a property code into a value get_prop_int returns an prop's raw int, get_prop_str returns a char * from an enum. get_prop_enum gets an integer value from an enum
 
# lib/UCDlib.pm6

### sub slurp-snippets

```perl6
sub slurp-snippets(
    Str $name, 
    Str $subname?, 
    $numbers?
) returns Mu
```

Slurps files from the snippets folder and concatenates them together The first argument is the folder name inside /snippets that they are in The second argument make it only concat files which contain that string The third argument allows you to request only snippets starting with those numbers if the numbers are positive. If they are negative, it returns all snippets except those numbers. Takes a single number, or a List of numbers
 
# lib/bitfield-rows-switch.pm6

### sub get-points-ranges-array

```perl6
sub get-points-ranges-array(
    %point-index, 
    Array $sorted-points?
) returns Mu
```

Returns a multi-dim Array. We push onto each index all of the contiguous codepoints which have the same bitfield row. We also fill in any gaps and add those to their own range number.
 
# Unicode-Grant/lib/PropertyValueAliases.pm6

### sub GetPropertyValueLookupHash

```perl6
sub GetPropertyValueLookupHash(
    Str:D $filename = "UNIDATA/PropertyValueAliases.txt", 
    Bool:D :$use-short-pnames = Bool::True, 
    Bool:D :$missing = Bool::False
) returns Mu
```

Returns a hash whose keys are PropertyValues and whose values are list's of list's. AHex => [[N No F False] [Y Yes T True]], The first value in the array is the shortened property value, and the second one is the long form one. The ones after that point are additional aliases Note. Does not return a positional for integer properties, instead returns a string which contains the Unicode datafile reason/null value for that property
 
# Unicode-Grant/lib/PropertyAliases.pm6

### sub GetPropertyAliasesRevLookupHash

```perl6
sub GetPropertyAliasesRevLookupHash(
    Str $filename = "UNIDATA/PropertyAliases.txt"
) returns Mu
```

Returns a hash whose keys are PropertyAliases and whose values are the short name which is usable with GetPropertyValueLookupHash to look up different value aliases

### sub GetPropertyAliasesLookupHash

```perl6
sub GetPropertyAliasesLookupHash(
    Str $filename = "UNIDATA/PropertyAliases.txt"
) returns Mu
```

Returns a hash whose keys are PropertyAliases and whose values are the full names

### sub GetPropertyAliases

```perl6
sub GetPropertyAliases(
    Str $filename = "UNIDATA/PropertyAliases.txt"
) returns Mu
```

Returns a hash whose values arrays of all the property names which are equivalent
 
# lib/ArrayCompose.pm6

### sub compose-array2

```perl6
sub compose-array2(
    Str:D $type, 
    Str:D $name, 
    @body, 
    Bool :$header = Bool::False, 
    Str:D :$delim = ",", 
    Bool:D :$no-split = Bool::False, 
    :$partition-note!, 
    :$map-empty-as
) returns Mu
```

:partition-note option seperates them by line and adds comments so you can tell what element number each one of the items is :map-empty-as allows you to make undefined array items to a certain value. for example match all undefined items to -1 or 0 for example