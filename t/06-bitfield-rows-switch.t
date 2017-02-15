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
is get-points-ranges-array(%point-index, @points), @expected-array;

is get-points-ranges-array(%point-index), @expected-array;
done-testing;
