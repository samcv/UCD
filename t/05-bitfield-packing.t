#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use BitfieldPacking;
my @n = [7,  4,4,  3,3,2  ,1, 1];
my @n1 = [7, 4, 2, 4, 5, 3, 1];
my @n2 = [15, 14, 13, 8, 4, 2, 2, 2, 1, 3];
my $gist = @n.gist;
sub format (@before, @after) {
    (@before => @after.».value).gist;
}
my @n-packed = [0 => 7, 7 => 1, 2 => 4, 1 => 4, 4 => 3, 3 => 3, 5 => 2, 6 => 1];
my @n1-packed = [0 => 7, 6 => 1, 4 => 5, 5 => 3, 3 => 4, 1 => 4, 2 => 2];
my @n2-packed = [3 => 8, 0 => 15, 8 => 1, 1 => 14, 7 => 2, 2 => 13, 9 => 3, 4 => 4, 6 => 2, 5 => 2];
is-deeply compute-packing(@n.pairs), @n-packed, format(@n, @n-packed);
is-deeply compute-packing(@n1.pairs), @n1-packed, format(@n1, @n1-packed);
is-deeply compute-packing(@n2.pairs), @n2-packed, format(@n2, @n2-packed);
done-testing;
