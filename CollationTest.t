use Test;
my Str $folder = "UNIDATA/UCA/CollationTest";
my IO::Path $file = "$folder/CollationTest_NON_IGNORABLE_SHORT.txt".IO;
sub MAIN {
    say is-surrogate(56320);
    exit;
    die unless $file.f;
    my @failed;
    use experimental :collation;
    my @lines = lazy gather {
        for $file.slurp.lines {
            next if $_ eq '' or .starts-with('#');
            take Uni.new(.split(' ').».parse-base(16).grep({
                not is-surrogate($_)
            })).Str;
        }
    }
    my $i = 0;
    while (@lines[$i + 1]) {
        unless is-deeply @lines[$i] unicmp @lines[$i + 1], Less, "@lines[$i] unicmp @lines[$i + 1]" {
            @failed.push( @lines[$i].ords.fmt("0x%X") ~ ',' ~ @lines[$i + 1].ords.fmt("0x%X") );
        }
        $i++;
        #say "$i";
    }
    done-testing;
    ($file.Str ~ '.failed.txt').IO.spurt(@failed.join: "\n");
}
sub is-surrogate (Int $cp) {
    return True if $cp >= 0xDC00 && $cp <= 0xDFFF; # <Low Surrogate>
    return True if $cp >= 0xD800 && $cp <= 0xDB7F; # <Non Private Use High Surrogate>
    False;
}
