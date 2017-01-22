#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use UCDlib;
is ("a," x 80).break-into-lines(",").lines, ("a," x 40) xx 2;
