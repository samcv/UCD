#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
my @modules = 'lib'.IO.dir.».basename.grep({.starts-with('.').not}).».subst(/ '.' .* $/, '');
my @files = 'UCD-gen.p6';
plan @modules.elems + @files.elems;
for @modules {
    use-ok $_, "Can ‘use’ $_";
}
for @files -> $file {
    is run('perl6', '-c', $file, :out).exitcode, 0, "Syntax ok for $file";
}

done-testing;
