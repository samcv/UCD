#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use packer;
my @n = 7,  4,4,  3,3,2  ,1, 1;
my @n1 = [7, 4, 2, 4, 5, 3, 1];
my $gist = @n.gist;
is packer(@n), 4, "%i bytes: %s".sprintf(4, @n.gist);
is packer(@n1), 5, "%i bytes: %s".sprintf(5, @n.gist);
done-testing;
