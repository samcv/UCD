#!/usr/bin/env perl6
# This is a script to encode strings using base 40 encoding.
# This can save space.
use v6;
use nqp;
use ArrayCompose;
use UCDlib;
# If we end up needing more characters we can always use one of the null values to denote "SHIFT"
# and encode a second level of characters as well
class base40-string {
    has @.bases = "\0",'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
        'P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6',
        '7','8','9',' ','-', '\a';
    has @.shift-level-one;
    has Str $.to-encode-str;
    has Str $.encoded-str;
    has @.to-encode-str-array;
    has %!shift-one;
    has %!base;
    has $!num_encoded_codepoints = 0;
    has Array $indices;
    has $base40-nums = nqp::list_s;
    method TWEAK {
        for ^@!bases.elems {
           %!base{@!bases[$_]} = $_;
        }
        if @!shift-level-one {
            self.set-shift-level-one(@!shift-level-one);
        }
    }
    method set-shift-level-one ( @things where { .all ~~ Str and .elems <= 40 } ) {
        @!shift-level-one = @things;
        for ^@!shift-level-one.elems {
            %!shift-one{@!shift-level-one[$_]} = $_;
        }
    }
    multi method push {
        @!to-encode-str-array.push('');
        #$!to-encode-str ~= "\0";
    }
    multi method push ( Str:D $string ) {
        @!to-encode-str-array.push: $string;
        #$!to-encode-str ~= $string ~ "\0";
        if $string ne '' {
            $!num_encoded_codepoints++;
        }
    }
    method done {
        # XXX for some reason either we aren't encoding the chars right or
        # names.c will keep going unless you put an extra null
        my $null = "\0";
        $!to-encode-str ~= "\0";
        $!to-encode-str ~~ s/ "\0"* $/$null/;
    }
    method get-base40 {
        $!to-encode-str = @!to-encode-str-array.join("\0") ~ "\0";
        @!to-encode-str-array = [];
        note "Running get-base40";
        if $!to-encode-str.defined and $!to-encode-str ne '' {
            if nqp::elems(nqp::decont($base40-nums)) == 0 {
                $base40-nums := self.encode-base40-string($!to-encode-str);
            }
            else {
                warn "This has not been tested!";
                my $var := self.encode-base40-string($!to-encode-str);
                for ^nqp::elems($var) {
                    nqp::push_s($base40-nums, nqp::atpos_s($var, $_));
                }
            }
            $!encoded-str ~= $!to-encode-str;
            $!to-encode-str = '';
        }
        note "Done running get-base40";
        $base40-nums;
    }
    method encode-base40-string ( Str $string is copy ) {
        if @!shift-level-one {
            for @!shift-level-one -> $s_string {
                my $replacement = '{' ~ %!shift-one{$s_string} ~ '}';
                $string ~~ s:g/$s_string/$replacement/;
            }

        }
        # Keeps track of the index for the unicode names
        my Int $counter = 0;
        my int $items_f = $string.chars;
        my int $items_i = 0;
        my $coded-nums := nqp::list_s;
        my int $i = 40 ** 2;
        my int $triplet = 0;
        sub items-elems {
            $items_i - $items_f - 1;
        }
        my str $item;
        while $items_i < $items_f {
            $item = nqp::substr($string, $items_i++, 1);
            # This saves the indexes of names
            if nqp::iseq_s($item, "\0") {
                if $counter %% 2 {
                    $indices.push(nqp::elems($coded-nums));
                }
                $counter++;
            }
            # This is a shifted value, so process it as such
            elsif nqp::iseq_s($item, '{') {
                #my str $item = nqp::substr($string, $items_i++, 1);
                my str $item;
                my str $str;
                # Grab the numbers up until the '}'
                # distance of the string to pull out (between the brackets)
                my $distance =  nqp::index($string, '}', $items_i) - $items_i;
                $str = nqp::substr($string, $items_i, $distance);
                $items_i += 1 + $distance;
                $item = nqp::substr($string, $items_i, 1);

                for @!bases.end, $str.Int -> $num {
                    $triplet += $num * $i;
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
            #die '%!base: ' ~ %!base.perl ~ "Can't find this letter in table “$item”" unless %!base{$item}:exists;
            $triplet += %!base{$item} * $i;
            $i = $i div 40;
            if $i < 1 or items-elems() == 0 {
                $i = 40 ** 2;
                nqp::push_s($coded-nums, nqp::base_I(nqp::decont($triplet), 10));
                $triplet = 0;
            }
        }
        $coded-nums;
    }
    method get-c-table {
        my @c_table;
        my @s_table;
        for @!bases {
            my $string = "'$_'";
            $string = q['\0'] if $string eq "'\0'";
            $string = q['\a'] if $string eq "'\a'";
            @c_table.push($string);
        }
        my $str ~= compose-array( "char", "ctable", @!bases.elems, @c_table.join(',') );
        if @!shift-level-one {
            note "detected shift level one in making c table";
            for @!shift-level-one {
                @s_table.push(qq["$_"]);
            }
            $str ~= compose-array(compute-type("char *"), "s_table",
                    @s_table.elems, @s_table.join(',') );
        }
        my $name_index = "#define num_encoded_codepoints = $!num_encoded_codepoints\n" ~
                            compose-array(
                                compute-type(self.elems), "name_index",
                                $indices.elems, $indices.join(',') );

        return $str ~ "\n" ~ $name_index ~ "\n";
    }
    method elems {
        self.get-base40;
        nqp::elems($base40-nums);
    }
    method Str {
        self.get-base40;
        nqp::box_s($!encoded-str, Str);
    }
    method convert-back {
        my @array;
        for ^nqp::elems($base40-nums) {
            @array.push(nqp::atpos_s($base40-nums, $_));
        }
        decode-base40-nums(@!bases, @array, :shift-one(@!shift-level-one));
    }
    method join (Str $joiner = '') {
        self.get-base40;
        note "Starting join process";
        my str $joined_str = nqp::join($joiner, $base40-nums);
        note "Done with joining process";
        $joined_str;
    }
}

sub decode-base40-nums ( @bases, @coded-nums is copy, :@shift-one? ) is export {
    my @decoded-chars;
    my %shift-one;
    if @shift-one {
        for ^@shift-one.elems {
            %shift-one{@shift-one[$_]} = $_;
        }
    }
    while @coded-nums {
        my $num = @coded-nums.shift;
        my $shift = False;
        for (1600, 40, 1) -> $j {
            my $char = $num.Int div $j;
            #note "char $char";
            last if $char == 0 and !$shift and @coded-nums.elems == 0;
            $num -= $char * $j;
            # If it's 39 then it's a shift value
            if $char == 39 and !$shift {
                note "setting shift on";
                $shift = True;
            }
            elsif $shift {
                note "Trying to push char $char @shift-one[$char]";
                @decoded-chars.push(@shift-one[$char]);
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
