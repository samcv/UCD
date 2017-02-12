use Test;
use lib 'lib';
use bitfield-rows-switch;
my %point-index = 1 => 'test', 2 => 'this', 2 => 'this', 3 => 'that', 4 => 'this', 5 => 'this', 6 => 'that', 7 => 'that';
my %points-ranges = get-points-ranges(%point-index);
is-deeply %points-ranges, {"0" => $[0], "1" => $["1"], "2" => $["2"], "3" => $["3"], "4" => $["4", "5"], "5" => $["6", "7"]};
done-testing;
