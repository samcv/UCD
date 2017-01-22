use v6;
use MONKEY-TYPING;
use Data::Dump;
use nqp;
my $prefix = 'const static ';
sub get-prefix is export {
    $prefix;
}
augment class Str {
    multi method split-trim ( Str $delimiter, Int $limit? ) {
        $limit ?? self.split($delimiter, $limit).».trim
               !! self.split($delimiter).».trim;
    }
    multi method split-trim ( @needles, Int $limit? ) {
        $limit ?? self.split(@needles, $limit).».trim
               !! self.split(@needles).».trim;
    }
    multi method split-trim ( Regex $regex, Int $limit? ) {
        $limit ?? self.split($regex, $limit).».trim
               !! self.split($regex).».trim;
    }
    method break-into-lines ( Str $breakpoint ) {
        my $copy = self;
        $copy ~~ s:g/(.**70..79 $breakpoint)/$0\n/;
        return $copy;
    }
}
sub break-into-lines ( Str $breakpoint, Str $string ) is export {
    $string.break-into-lines($breakpoint);
}
sub Dump-Range ( Range $range, Hash $hashy ) is export {
    for $range.lazy -> $point {
        say $point;
        say Dump($hashy{$point}) if $hashy{$point}:exists;
    }
}
sub reverse-hash-int-only ( Hash $hash ) is export {
    my %new-hash{Int};
    for $hash.keys {
        %new-hash{$hash{$_}} = $_ if $hash{$_} ~~ Int and $_ ne any('bitwidth', 'name');
    }
    return %new-hash;
}
multi sub compute-type ( Str $str ) {
    if $str eq 'char *' {
        return $prefix ~ 'char *';
    }
    else {
        die "Don't know what type '$str' is";
    }
}
multi sub compute-type ( Int $max, Int $min = 0 ) is export {
    say "max: $max, min: $min";
    die "Not sure how to handle min being higher than max. Min: $min, Max: $max" if $min.abs > $max;
    my $size = $max.base(2).chars / 8;
    my $type;
    if $size < 1 {
        $type ~= $min >= 0 ?? 'uint8_t' !! 'int16_t';
    }
    elsif $size <= 2 {
        $type ~= $min >= 0 ?? 'uint16_t' !! 'int32_t';
    }
    elsif $size <= 4 {
        $type ~= $min >= 0 ?? 'uint32_t' !! 'int64_t';
    }
    elsif $size <= 8 {
        $type ~= $min >= 0 ?? 'uint64_t' !! 'int128_t';
    }
    else {
        die "Size is $size. Not sure what to do";
    }
    $prefix ~ $type;
}
sub circumfix:<⟅ ⟆>(*@array) returns str is export {
    @array.join('');
}
multi sub prefix:< ¿ > ( Str $str ) is export { $str.defined and $str ne '' ?? True !! False }
multi sub prefix:< ¿ > ( Bool $bool ) { $bool.defined and $bool != False }

sub infix:< =? > ($left is rw, $right) is export { $left = $right if ¿$right }
sub infix:< ?= > ($left is rw, $right) is export { $left = $right if ¿$left }
