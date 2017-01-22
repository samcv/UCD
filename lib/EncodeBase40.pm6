#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
use v6;
use nqp;
our @bases = "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
    '7','8','9',' ','-', '\a';
our @shift-level-one;
our @shift-level-two;
our $pushed-strings;
our %base;
our %shift-one;
our %shift-two;
class base40-string {
    has @.bases = "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
        'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
        '7','8','9',' ','-', '\a';
    has @.shift-level-one;
    has Str $.to-encode-str;
    has Str $.encoded-str;
    has %!shift-one;
    my $base40-nums := nqp::list_s;
    method init-globals {
        %shift-one = %!shift-one;
        @bases = @.bases;
        @shift-level-one = @.shift-level-one;
    }
    method TWEAK {
        if @!shift-level-one {
            self.set-shift-level-one(@!shift-level-one);
        }
    }
    method set-shift-level-one ( @things where { .all ~~ Str and .elems <= 40 } ) {
        for ^@!shift-level-one.elems {
            %!shift-one{@!shift-level-one[$_]} = $_;
        }
        self.init-globals;
    }
    multi method push {
        $!to-encode-str ~= "\0";
    }
    multi method push ( Str $string ) {
        if $!to-encode-str {
            $!to-encode-str ~= $string ~ "\0";
        }
        else {
            $!to-encode-str = $string;
        }
    }
    method get-base40 {
        self.init-globals;
        if $!to-encode-str.defined and $!to-encode-str ne '' {
            init-shift-hashes(@!shift-level-one) if @!shift-level-one;
            die if self.elems > 0;
            $base40-nums := encode-base40-string($!to-encode-str);
            $!encoded-str ~= $!to-encode-str;
            $!to-encode-str = '';
        }
        $base40-nums;
    }
    method get-c-table {
        self.init-globals;
        get-base40-c-table(@!shift-level-one, @!bases);
    }
    method elems {
        nqp::elems($base40-nums);
    }
    method Str {
        self.get-base40;
        nqp::box_s($!encoded-str, Str);
    }
    method join (Str $joiner) {
        self.get-base40;
        nqp::join($joiner, $base40-nums);
    }
}

# I
# If we end up needing more characters we can always use one of the null values to denote "SHIFT"
# and encode a second level of characters as well

for ^@bases.elems {
    %base{@bases[$_]} = $_;
}
sub init-shift-hashes (@sub-shift-level-one?) is export {
    if @sub-shift-level-one {
        %shift-one := {};
        for ^@sub-shift-level-one.elems {
            %shift-one{@sub-shift-level-one[$_]} = $_;
        }
        @shift-level-one = @sub-shift-level-one;
    }
    elsif @shift-level-one {
        %shift-one := {};
        for ^@shift-level-one.elems {
            %shift-one{@shift-level-one[$_]} = $_;
        }
    }
    else {
        note "No \@shift-level-one found";
    }
}
sub set-shift-levels ( %shift-level-one ) is export {
    for %shift-level-one.sort(+(*.value)) -> $pair {
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
sub get-base40-c-table (@shift-level-one?,
    @bases = (
    "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
    '7','8','9',' ','-', '\a')
    ) is export {
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
        say "detected shift level one in making c table";
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
sub encode-base40-string ( Str $string is copy, base40-string $self? ) is export {
    if $self {
        init-shift-hashes($self.shift-level-one);
    }
    if @shift-level-one {
        if !%shift-one {
            init-shift-hashes(@shift-level-one);
        }
        for @shift-level-one -> $s_string {
            if $string.contains($s_string) {
                my $replacement = '{' ~ %shift-one{$s_string} ~ '}';
                $string ~~ s:g/$s_string/$replacement/;
            }
        }

    }
    #note "string: $string";
    my int $items_f = $string.chars;
    my int $items_i = 0;
    my $coded-nums := nqp::list_s;
    my int $i = 40 ** 2;
    my int $triplet = 0;
    sub items-elems {
        $items_i - $items_f - 1;
    }
    while $items_i < $items_f {
        my str $item = nqp::substr($string, $items_i++, 1);
        # This is a shifted value, so process it as such
        if $item eq '{' {
            my str $item = nqp::substr($string, $items_i++, 1);;
            my str $str;
            # Grab the numbers up until the '}'
            while $item ne '}' {
                $str ~= $item;
                $item = nqp::substr($string, $items_i++, 1);
            }
            #say "STR: $str";
            for %base{@bases[@bases.end]}, $str.Int -> $num {
                $triplet += $num * $i;

                #say "triplet: $triplet i: $i";
                # We have our shift value now, so add it to the @coded-nums
                # Push the shift character
                $i = $i div 40;
                # XXX Maybe we need to not check if elems == 0 since we may have pulled everything out?
                if $i < 1 {
                    $i = 40 ** 2;

                    nqp::push_s($coded-nums, nqp::base_I(nqp::decont($triplet), 10));
                    $triplet = 0;
                }
            }
            if items-elems() == 0 {
                nqp::push_s($coded-nums, nqp::base_I(nqp::decont($triplet), 10));
                $triplet = 0;
            }
            next;
        }

        die "Can't find this letter in table “$item”" unless %base{$item}:exists;
        $triplet += %base{$item} * $i;
        $i = $i div 40;
        if $i < 1 or items-elems() == 0 {
            $i = 40 ** 2;
            nqp::push_s($coded-nums, nqp::base_I(nqp::decont($triplet), 10));
            $triplet = 0;
        }
    }
    $coded-nums;
}
sub decode-base40-nums ( @coded-nums is copy, :@shift-one? ) is export {
    my @decoded-chars;
    if @shift-one {
        init-shift-hashes(@shift-one);
        if !%shift-one {
            init-shift-hashes(@shift-one);
        }
    }
    while @coded-nums {
        my $num = @coded-nums.shift;
        my $shift = False;
        for (1600, 40, 1) -> $j {
            my $char = $num.Int div $j;
            #say "char $char";
            last if $char == 0 and !$shift and @coded-nums.elems == 0;
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
