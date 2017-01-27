#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
my @modules = 'lib'.IO.dir.».basename.grep({.starts-with('.').not}).».subst(/ '.' .* $/, '');
plan @modules.elems;
for @modules {
    .say;
    use-ok $_, "Can ‘use’ $_";
}

done-testing;
