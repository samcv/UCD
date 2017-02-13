#!/usr/bin/env perl6
use Pod::Render;
my $head = Q:to/END/;
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
END

my @files = "UCD-gen.p6", "lib/UCDlib.pm6", "lib/bitfield-rows-switch.pm6";
#say pod2markdown($=pod);
my $text;
for @files -> $file {
    $text ~=  "\n# $file\n\n" ~ run("perl6",  "--doc=Markdown", $file.IO.abspath, :out).out.slurp-rest;
}
"README.md".IO.spurt($head ~ $text);
