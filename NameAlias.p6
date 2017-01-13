my Str $folder = "UNIDATA";
#my $names = slurp "$folder/NameAliases.txt";
my %points;
my %decomp_spec;
# NameAliases.txt
# 0 Codepoint (Hex)
# 1 NameAlias
# 2 NameAlias type
# sub path($cp, +@a) { say "\@.perl: @a.perl()"; @a.reduce({ $^a{$^b}:exists ?? $^a{$^b} !! $^a{$^b} = {} }) };
sub slurp-lines ( Str $filename ) returns Seq {
    "$folder/$filename.txt".IO.slurp.lines;
}
sub infix:< ?= > ($left is rw, $right) { $left = $right if defined $right and $right ne '' }

sub skip-line ( Str $line ) {
    $line.starts-with('#') or $line.match(/^\s*$/) ?? True !! False;
}
sub NameAlias ( $property, $file ) {
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split(';').».trim;
        my %hash;
        %hash{$property}{@parts[1]}<type> = @parts[2];
        apply-to-cp(@parts[0], %hash)
    }
}
sub UnicodeData ( $file ) {
    for slurp-lines $file {
        next if skip-line($_);
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = .split(';');
        my $cp = $code-str.parse-base(16);
        if ($name eq '<control>' ) {
            $name = sprintf '<control-%.4X>', $cp;
        }
        my %hash;
        %hash<Unicode_1_Name>            ?= $u1name;
        %hash<name>                      ?= $name;
        %hash<gencat_name>               ?= $gencat;
        %hash<General_Category>          ?= $gencat;
        %hash<Canonical_Combining_Class> ?= $ccclass;
        %hash<Bidi_Class>                ?= $bidiclass;
        %hash<suc>     ?= $suc;
        %hash<slc>     ?= $slc;
        %hash<stc>     ?= $stc;
        %hash<NFD_QC>  ?= True;
        %hash<NFC_QC>  ?= True;
        %hash<NFKD_QC> ?= True;
        %hash<NFG_QC>  ?= True;
        %hash<Any>     ?= True;
        %hash<Bidi_Mirrored> = True if $bidimirrored eq 'Y';
        if $decmpspec {
            my @dec = $decmpspec.split(' ');
            if @dec[0] ~~ /'<'\w+'>'/ {
                %decomp_spec{$cp}<type> = @dec.shift;
            }
            else {
                %decomp_spec{$cp}<type> = 'Canonical';
            }
            %decomp_spec{$cp}<mapping> = @dec.».parse-base(16);
        }
        apply-to-cp($code-str, %hash);
    }

}
sub apply-to-cp (Str $range-str, $hashy) {
    my $range;
    # If it contains .. then it is a range
    if $range-str ~~ / ^ ( <:AHex>+ ) '..' ( <:AHex> ) $ / {
        $range = Range.new: $0.Str.parse-base(16), $1.Str.parse-base(16);
    }
    # Otherwise there's only one point
    elsif $range-str ~~ / ^ (<:AHex>+) $ / {
        $_ = $0.Str.parse-base(16);
        $range = Range.new($_, $_);
    }
    else {
        die "Unknown range '$range-str'";
    }
    for $range.lazy -> $cp {
        apply-to-points($cp, $hashy);
    }
}
sub apply-to-points (Int $cp, $hashy) {
    for $hashy.keys -> $key {
        if !defined %points{$cp}{$key} {
            %points{$cp}{$key} = $hashy{$key};
        }
        else {
            for $hashy{$key}.keys -> $key2 {
                if !defined %points{$cp}{$key}{$key2} {
                    %points{$cp}{$key}{$key2} = $hashy{$key}{$key2};
                }
                else {
                    die "This level of hash NYI";
                }
            }
        }
    }
}
UnicodeData("UnicodeData");
NameAlias("NameAlias", "NameAliases" );
say %points{'ū'.ord};
