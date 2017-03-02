use Test;
use lib 'lib';
use bitfield-rows-switch;
my %point-index = 1 => 'test', 2 => 'this', 3 => 'that', 4 => 'this', 5 => 'this', 6 => 'that', 7 => 'that', 10 => 'what';
my @expected-array = [
    ["0"],
    ["1"],
    ["2"],
    ["3"],
    ["4", "5"],
    ["6", "7"],
    ["8", "9"],
    ["10"]
];
my @points = '1', '2', '3', '4', '5', '6', '7', '10';
is-deeply get-points-ranges-array(%point-index, @points)».Int, @expected-array».Int;

is-deeply get-points-ranges-array(%point-index)».Int, @expected-array».Int;

my %p3 =
20 => '351',
#
22 => '335',
23 => '335',
24 => '335',
#
25 => '334',
26 => '334',

31 => '334',
32 => '334',
;
is-deeply get-points-ranges-array(%p3)».Int,
$[
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [20], [21],
    [22, 23, 24],
    [25, 26],
    [27, 28, 29, 30],
    [31, 32]
];
done-testing;
