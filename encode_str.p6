#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
our @bases = "\0",'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u',
'v','w','x','y','z','0','1','2','3','4','5','6','7','8','9',' ',"\n";
my %base;
for ^@bases.elems {
    %base{@bases[$_]} = $_;
}
my $string = "this is a test string";
my @items = $string.comb;
my @iter;
my @coded-nums;
my $i = 3;
my $triplet = 0;
while @items {
    $triplet += %base{@items.shift} * (40 ** $i--);
    if $i <= 0 or @items.elems == 0 {
        $i = 3;
        @coded-nums.push($triplet);
        $triplet = 0;
    }
}
say @coded-nums.join(',');
my $elems = @coded-nums.elems;
my @decoded-chars;
while @coded-nums {
    my $num = @coded-nums.shift;
    for (3,2,1) -> $j {
        my $char = $num div ( 40 ** $j);
        last if $char == 0;
        $num -= $char * ( 40 ** $j);
        @decoded-chars.push(@bases[$char]);
    }
}
say @decoded-chars.join;
say "Saved " ~ $string.chars - $elems * 2 ~ " Bytes";
