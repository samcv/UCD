#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use BitfieldPacking;
my @n = 7,  4,4,  3,3,2  ,1, 1;
my @m;
my $i = 0;
for @n {
    @m.push($i++ => $_);
}
my @n1 = [7, 4, 2, 4, 5, 3, 1];
my $gist = @n.gist;
is compute-packing(@m), (0 => 7, 7 => 1, 2 => 4, 1 => 4, 4 => 3, 3 => 3, 5 => 2, 6 => 1), @m.gist;
done-testing;
