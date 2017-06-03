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

Then make sure ./Unicode-Grant which is a git submodule is also checked out
`git submodule update --init --recursive`

Generate the C files with
`perl6 UCD-gen.p6`

They will be placed in `./source`

Running `make` will build `bitfield` and `names` and put them in `./build`
END

my @files =
    "UCD-gen.p6",
    "lib/UCDlib.pm6",
    "lib/bitfield-rows-switch.pm6",
    "Unicode-Grant/lib/PropertyValueAliases.pm6",
    "Unicode-Grant/lib/PropertyAliases.pm6",
    "lib/ArrayCompose.pm6"
    ;
#say pod2markdown($=pod);
my $text;
my @prom = do for @files -> $file {
    start {
        "\n# $file\n\n" ~ run("perl6",  "-I", "Unicode-Grant/lib", "-I", "lib", "--doc=Markdown", $file.IO.absolute, :out).out.slurp
    }
}
await Promise.allof(@prom);
my @result;
my $i = -1;
for @prom.map(*.result).Str.lines -> $line is copy {
    {
        $i++ if $line.starts-with: '```';
        $line ~~ s/'```'/```perl6/ if $i %% 2;
    }
    @result.push: $line;
}
"README.md".IO.spurt: [~]
    @files.map({ "* [$_](#{.trans([' ', '!'..'/'] => ['-', '']).lc})"}).join("\n"),
    "\n\n", $head, @result.join("\n");

#"README.md".IO.spurt($head ~ $text);
