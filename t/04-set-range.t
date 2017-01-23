#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use Set-Range;
my %ranges;
for 0..20 {
    %ranges{$_} = '<control>';
}
for 80.. 90 {
    %ranges{$_} = '<control>';
}
my @r_iter = %ranges.keys.sort(+*);
my $sr = Set-Range.new;
for %ranges.keys.sort(+*) {
    $sr.add-to-range($_, "control");
}
is $sr.get-range, {
    0 => { first => 0, last => 20, name => 'control' },
    1 => { first => 80, last => 90, name => 'control' }
},
    "Set-Range tenatively returns the correct value";
