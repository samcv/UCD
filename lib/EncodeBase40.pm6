#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
use v6;
our @bases = "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
    '7','8','9',' ',"-", "\0";
# If we end up needing more characters we can always use one of the null values to denote "SHIFT"
# and encode a second level of characters as well
my %base;
for ^@bases.elems {
    %base{@bases[$_]} = $_;
}
sub get-base-40-table {
    @bases;
}
sub get-base-40-hash {
    %base;
}
sub test-points {
    my $new;
    my $old;
    for 0..0x1FFFFF -> $cp {
        my $name = $cp.uniname.lc;
        #say $name;
        next if $name.contains('<') or $name eq '';
        $new += encode-string($name).elems;
        $old += $name.chars;
    }
    say "new $new old $old. diff: {$old - $new}";

}
sub encode-base-40-string ( Str $string ) is export {
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
