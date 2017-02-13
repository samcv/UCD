* [UCD-gen.p6](#ucd-gen.p6)
* [lib/UCDlib.pm6](#lib/ucdlib.pm6)
* [lib/bitfield-rows-switch.pm6](#lib/bitfield-rows-switch.pm6)

[![Build Status](https://travis-ci.org/samcv/UCD.svg?branch=master)](https://travis-ci.org/samcv/UCD)

## What
This is work towards a rewrite of the `ucd2c.pl` script that generates our
Unicode database on MoarVM.

## How do I build this
Install all dependant modules, if you have zef:
`zef --depsonly install .`
Download the Unicode database files:
`perl6 UCD-download.p6`

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

`%PropertyValueAliases %PropertyValueAliases_to`
------------------------------------------------

Stores PropertyValueAliases from PropertyValueAliases.txt Used to go from short names that may be used in the data files to the full names

`%PropertyNameAliases %PropertyNameAliases_to`
----------------------------------------------

Stores Property Aliases or Property Value Aliases to their Full Name mappings
 
# lib/UCDlib.pm6

### sub slurp-snippets

```
sub slurp-snippets(
    Str $name, 
    Str $subname?, 
    $numbers?
) returns Mu
```

Slurps files from the snippets folder and concatenates them together The first argument is the folder name inside /snippets that they are in The second argument make it only concat files which contain that string The third argument allows you to request only snippets starting with those numbers if the numbers are positive. If they are negative, it returns all snippets except those numbers. Takes a single number, or a List of numbers
 
# lib/bitfield-rows-switch.pm6

### sub get-points-ranges

```
sub get-points-ranges(
    %point-index
) returns Mu
```

Makes a hash where the keys "range numbers". These range numbers start at 0 and we push onto each range number all of the contiguous codepoints which have the same bitfield row. We also fill in any gaps and add those to their own range number.
