use v6;
use MONKEY-TYPING;
use Data::Dump;
use Terminal::ANSIColor;
constant $BOLD = BOLD;
constant $BOLD_OFF = BOLD_OFF;
constant $BLUE = color('blue');
constant $RESET = RESET;
use nqp;
constant $prefix = 'const static ';
my Str $UNIDATA-folder = "UNIDATA";
my Str $snippet-folder = 'snippets';
augment class Str {
    method break-into-lines ( Str $breakpoint ) {
        my $copy = self;
        $copy ~~ s:g/(.**70..79 $breakpoint)/$0\n/;
        return $copy;
    }
}

sub starts-with (\string, \needle) is export  { nqp::eqat(string, needle, 0) }
sub atkey (\hash, \key) is export            { nqp::atkey(hash, key) }
sub atkey2 (\hash, \key1, \key2) is export   { nqp::atkey(nqp::atkey(hash, key1), key2) }
sub bindkey (\hash, \key, \value) is export  { nqp::bindkey(hash, key, value) }
sub str-isn't-empty (\x) is export           { nqp::isne_i( nqp::chars(x), 0) }
sub base10_I (\integer) is export          { nqp::base_I(integer, 10) }
sub base10_I_decont (\integer) is export   { nqp::base_I(nqp::decont(integer), 10) }
sub existskey (\hash, \key) is export      { nqp::existskey(hash, key) }
sub hex (\code-str) is export      { nqp::atpos(nqp::radix(16, code-str, 0, 0), 0) }
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
    $files .= grep: { .basename.match( / ^ (\d+)'-' / )[0].Int == $numbers.any } if $numbers.defined and $numbers.any >= 0;
    $files .= grep: { .basename.match( / ^ (\d+)'-' / )[0].Int != $numbers.any } if $numbers.defined and $numbers.any < 0;
    my $text ~= .slurp orelse die for $files.sort;
    $text;
}
multi sub announce ( $verb, $subject, $time) is export {
    note $BOLD, "Took ", $time, ' seconds to ', $verb, ' ', $BLUE, $subject, $RESET;
}
multi sub announce ( $verb, $subject ) is export {
    note $BOLD, $verb.tc, ' ', $BLUE, $subject, $RESET, $BOLD, ' …', $RESET;
}
sub slurp-lines ( Str $filename ) returns Seq is export {
    announce "Reading", "$filename.txt";
    "$UNIDATA-folder/$filename.txt".IO.lines orelse die;
}
sub Dump-Range ( Range $range, Hash $hashy ) is export {
    for $range.lazy -> $point {
        say $point;
        say Dump($hashy{$point}) if $hashy{$point}:exists;
    }
}
sub get-prefix is export { $prefix }
multi sub compute-type ( Str $str ) {
    if $str eq 'char *' {
        return $prefix ~ 'char *';
    }
    elsif $str eq 'char' {
        return $prefix ~ 'char';
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
