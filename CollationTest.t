#!/usr/bin/env perl6
use Test;
my Str $folder = "UNIDATA/UCA/CollationTest";
my IO::Path $file;
sub MAIN (Bool:D :$fatal = False) {
    $file = "$folder/CollationTest_NON_IGNORABLE_SHORT.txt".IO;
    die "File not found: $file" unless $file.f;
    my @failed;
    use experimental :collation;
    my @lines;
    my Int:D $line-no = 0;
    @lines = lazy gather for $file.lines {
        $line-no++;
        #say $line-no;
        #say $_;
        my $short-test-regex = regex {
            ^ $<codes>=( [<:AHex>+]+ % \s+ ) $
        };
        my $full-test-regex = regex {
            ^ $<codes>=(<[A..F0..9\s]>+)
                    \s*   ';' .*? '#' \s*
                      $<comment>=(.*?) \s*
                      $<col-val>=('['.*?']') \s*
                    $
        };
        next if $_ eq '' or .starts-with('#');
        $_ ~~ $short-test-regex;
        my $codes = $<codes>.split(' ').».parse-base(16);
        if $codes.grep({is-surrogate($_)}).not {

        take Pair.new(
            Uni.new(|$codes).Str,
            ($<comment>.defined ?? ~$<comment> !! "line number $line-no")
        );
        } #unless $codes.grep({is-surrogate($_)});
    }
    my $i = 0;
    my $fh = open ($file.basename ~ '.failed.txt'), :a;
    while (@lines[$i + 1]) {
        if @lines[$i].key eq @lines[$i + 1].key {
            $i++;
            next;
        }
        unless is-deeply @lines[$i].key unicmp @lines[$i + 1].key, Less,
            "@lines[$i].key() unicmp @lines[$i + 1].key() {@lines[$i].value ?? “# @lines[$i].value() <=> @lines[$i + 1].value()” !! ""}"
        {
            ($fatal ?? $*IN !! $fh).say: format-printout(@lines[$i], @lines[$i+1])
            #`( unless @lines[$i].key.ords.any.uniprop('MVM_COLLATION_QC') #`) ;
            exit 1 if $fatal;
        }
        $i++;
    }
    $fh.close;
    say 'done';
    done-testing;
}
sub format-printout (Pair:D $first, Pair:D $second) {
    [~] 'Uni.new(',
        $first.key.ords.fmt("0x%X,"),
        ').Str unicmp Uni.new(',
        $second.key.ords.fmt("0x%X,"),
        ').Str; # ',
        $first.value,
        ' <=> ',
        $second.value
}
sub is-surrogate (Int $cp) {
    return True if $cp >= 0xDC00 && $cp <= 0xDFFF; # <Low Surrogate>
    return True if $cp >= 0xD800 && $cp <= 0xDB7F; # <Non Private Use High Surrogate>
    False;
}
