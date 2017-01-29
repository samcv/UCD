use v6;
use MONKEY-TYPING;
use Data::Dump;
use nqp;
my $prefix = 'const static ';
my Str $UNIDATA-folder = "UNIDATA";
my Str $snippet-folder = 'snippets';
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
#| Slurps files from the snippets folder and concatenates them together
#| The first argument is the folder name inside /snippets that they are in
#| The second argument make it only concat files which contain that string
#| The third argument allows you to request only snippets starting with those
#| numbers if the numbers are positive. If they are negative, it returns
#| all snippets except those numbers.
#| Takes a single number, or a List of numbers
sub slurp-snippets ( Str $name, Str $subname?, $numbers? ) is export {
    my $dir-name = "$snippet-folder/$name";
    state %dir-listing;
    if !%dir-listing {
        for $snippet-folder.IO.dir -> $folder {
            die $folder unless $folder.d;
            %dir-listing{$folder} = $folder.dir.List;
        }
    }
    die if !defined %dir-listing{$dir-name};
    my $files = $subname ?? %dir-listing{$dir-name}.grep( { .basename.contains: $subname } ) !! %dir-listing{$dir-name};
    $files .= grep: { .basename.starts-with: $numbers.any } if $numbers and $numbers.any >= 0;
    $files .= grep: { .basename.starts-with($numbers.any).not } if $numbers and $numbers.any < 0;
    my $text ~= .slurp orelse die for $files.sort;
    $text;
}
sub slurp-lines ( Str $filename ) returns Seq is export {
    note "Reading $filename.txt…";
    "$UNIDATA-folder/$filename.txt".IO.slurp.lines orelse die;
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
sub get-prefix is export {
    $prefix;
}
proto sub compute-type (|) { * }
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
    my $bit-size = $max.base(2).chars;
    my $type;
    if $min >= 0 {
        if $max <= 2**8 - 1 {
            $type ~= 'uint8_t';
        }
        elsif $max <= 2**16 - 1 {
            $type ~= 'uint16_t';
        }
        elsif $max <= 2**32 - 1 {
            $type ~= 'uint32_t';
        }
        elsif $max <= 2**64 - 1 {
            $type ~= 'uint64_t';
        }
        else {
            die "Size is $bit-size. Not sure what to do";
        }
    }
    else {
        if $max <= 2**7 - 1 {
            $type ~= 'int8_t';
        }
        elsif $max <= 2**15 - 1 {
            $type ~= 'int16_t';
        }
        elsif $max <= 2**31 - 1 {
            $type ~= 'int32_t';
        }
        elsif $max <= 2**63 - 1 {
            $type ~= 'int64_t';
        }
        else {
            die "Size is $bit-size. Not sure what to do";
        }
    }
    $prefix ~ $type;
}
