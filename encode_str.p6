#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
our @bases = "\0",'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u',
'v','w','x','y','z','0','1','2','3','4','5','6','7','8','9',' ',"\n";
my %base;
for ^@bases.elems {
    %base{@bases[$_]} = $_;
}

sub encode-string ( Str $string ) {
    my @items = $string.comb;
    my @coded-nums;
    my $i = 40 ** 2;
    my $triplet = 0;
    while @items {
        $triplet += %base{@items.shift} * $i;
        $i = $i / 40;
        if $i < 1 or @items.elems == 0 {
            $i = 40 ** 2;
            @coded-nums.push($triplet);
            $triplet = 0;
        }
    }
    @coded-nums;
}
my $string = "this is a test string";
my @coded-nums = encode-string($string);
say @coded-nums.join(',');
my $elems = @coded-nums.elems;

sub decode-nums ( @coded-nums ) {
    my @decoded-chars;
    while @coded-nums {
        my $num = @coded-nums.shift;
        for (1600, 40, 1) -> $j {
            my $char = $num.Int div $j;
            last if $char == 0;
            $num -= $char * $j;
            @decoded-chars.push(@bases[$char]);
        }
    }
    @decoded-chars;
}
my @decoded-chars = decode-nums(@coded-nums);
say @decoded-chars.join;
say "Saved " ~ $string.chars - $elems * 2  ~ " Bytes";
