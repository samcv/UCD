#!/usr/bin/env perl6
use Test;
my Str $folder = "UNIDATA/UCA/CollationTest";
my IO::Path $file;
sub MAIN {
    $file = "$folder/CollationTest_NON_IGNORABLE.txt".IO;
    die "File not found: $file" unless $file.f;
    my @failed;
    use experimental :collation;
    my @lines;
    #start {
        @lines = lazy gather {
            for $file.lines {
                next if $_ eq '' or .starts-with('#');
                $_ ~~ / ^ $<codes>=(.*?) ';' .*? '#' \s*
                          $<comment>=(.*?) \s*
                          $<col-val>=('['.*?']') \s* $ /;
                take Pair.new(
                    Uni.new(
                        $<codes>.split(' ').».parse-base(16).grep({
                            not is-surrogate($_)
                    })).Str,
                    ~$<comment>
                )
            }
        }
    #}
    my $i = 0;
    while (@lines[$i + 1]) {
        unless is-deeply @lines[$i].key unicmp @lines[$i + 1].key, Less,
            "@lines[$i].key() unicmp @lines[$i + 1].key() # @lines[$i].value() <=> @lines[$i + 1].value()"
        {
            @failed.push(
                [~] 'Uni.new(',
                    @lines[$i].key.ords.fmt("0x%X,"),
                    ').Str unicmp Uni.new(',
                    @lines[$i + 1].key.ords.fmt("0x%X,"),
                    ').Str; # ',
                    @lines[$i].value,
                    ' <=> ',
                    @lines[$i + 1].value
            ) #`( unless @lines[$i].key.ords.any.uniprop('MVM_COLLATION_QC') #`) ;
        }
        $i++;
        #say "$i";
    }
    ($file.basename, '.failed.txt').join.IO.spurt(@failed.join: "\n");
    done-testing;
}
sub is-surrogate (Int $cp) {
    return True if $cp >= 0xDC00 && $cp <= 0xDFFF; # <Low Surrogate>
    return True if $cp >= 0xD800 && $cp <= 0xDB7F; # <Non Private Use High Surrogate>
    False;
}
