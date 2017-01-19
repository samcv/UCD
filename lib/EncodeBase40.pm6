#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
use v6;
our @bases = "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
    '7','8','9',' ','-', '\a';
our @shift-level-one;
our @shift-level-two;
# If we end up needing more characters we can always use one of the null values to denote "SHIFT"
# and encode a second level of characters as well
my %base;
my %shift-one;
my %shift-two;
for ^@bases.elems {
    %base{@bases[$_]} = $_;
}
sub init-shift-hashes {
    if @shift-level-one and !%shift-one {
        for ^@shift-level-one.elems {
            %shift-one{@shift-level-one[$_]} = $_;
        }
        dd @shift-level-one;
        dd %shift-one;
    }
    if @shift-level-one and !%shift-two {
        for ^@shift-level-one.elems {
            %shift-one{@shift-level-one[$_]} = $_;
        }
    }
}
sub set-shift-levels ( %shift-level-one ) is export {
    for %shift-level-one.sort(*.value) -> $pair {
        push @shift-level-one, $pair.key;
    }
}
sub get-base40-table is export {
    @bases;
}
sub get-base40-shift-one-table is export {
    @shift-level-one;
}
sub get-base40-hash is export {
    %base;
}
sub get-base40-c-table is export {
    my $str = "char ctable[@bases.elems()] = \{\n";
    my @c_table;
    my @s_table;
    for @bases {
        my $string = "'$_'";
        $string = q['\0'] if $string eq "'\0'";
        $string = q['\a'] if $string eq "'\a'";
        @c_table.push($string);
    }
    $str ~= @c_table.join(',') ~ "\n\};\n";
    if @shift-level-one {
        @shift-level-one.pop;
        for @shift-level-one {
            @s_table.push(qq["$_"]);
        }
        $str ~= "char * s_table[@s_table.elems()] = \{\n" ~ @s_table.join(',') ~ "\n\};\n";
    }
    return $str;
}
sub test-points {
    my $new;
    my $old;
    for 0..0x1FFFFF -> $cp {
        my $name = $cp.uniname.lc;
        #say $name;
        next if $name.contains('<') or $name eq '';
        $new += encode-base40-string($name).elems;
        $old += $name.chars;
    }
    say "new $new old $old. diff: {$old - $new}";

}
sub encode-base40-string ( Str $string is copy ) is export {
    init-shift-hashes();
    if @shift-level-one {
        for @shift-level-one -> $s_string {
            if $string.contains($s_string) {
                my $replacement = '{' ~ %shift-one{$s_string} ~ '}';
                $string ~~ s:g/$s_string/$replacement/;
            }
        }

    }
    #say "string: $string";
    my @items = $string.comb;
    my @coded-nums;
    my $i = 40 ** 2;
    my $triplet = 0;
    while @items {
        my $item = @items.shift;
        # This is a shifted value, so process it as such
        if $item eq '{' {
            my $item = @items.shift;
            my $str;
            # Grab the numbers up until the '}'
            while $item ne '}' {
                $str ~= $item;
                $item = @items.shift;
            }
            #say "STR: $str";
            for %base{@bases[@bases.end]}, $str.Int -> $num {
                #say "num: $num";
                $triplet += $num * $i;
                #say "triplet: $triplet i: $i";
                # We have our shift value now, so add it to the @coded-nums
                # Push the shift character
                $i = $i / 40;
                # XXX Maybe we need to not check if elems == 0 since we may have pulled everything out?
                if $i < 1 {
                    $i = 40 ** 2;
                    @coded-nums.push($triplet);
                    $triplet = 0;
                }
            }
            if @items.elems == 0 {
                @coded-nums.push($triplet);
                $triplet = 0;
            }
            next;
        }

        die "Can't find this letter in table “$item”" unless %base{$item}:exists;
        $triplet += %base{$item} * $i;
        $i = $i / 40;
        if $i < 1 or @items.elems == 0 {
            $i = 40 ** 2;
            @coded-nums.push($triplet);
            $triplet = 0;
        }
    }
    @coded-nums;
}
sub decode-base40-nums ( @coded-nums is copy ) is export {
    my @decoded-chars;
    while @coded-nums {
        my $num = @coded-nums.shift;
        my $shift = False;
        for (1600, 40, 1) -> $j {
            my $char = $num.Int div $j;
            say "char $char";
            last if $char == 0 and !$shift;
            $num -= $char * $j;
            # If it's 39 then it's a shift value
            if $char == 39 and !$shift {
                say "setting shift on";
                $shift = True;
            }
            elsif $shift {
                say "Trying to push char $char @shift-level-one[$char]";
                @decoded-chars.push(@shift-level-one[$char]);
                $shift = False;
            }
            # Otherwise just push it
            else {
                @decoded-chars.push(@bases[$char]);
            }
        }
    }
    @decoded-chars.join;
}
