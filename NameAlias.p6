use JSON::Fast;
INIT say "Initializing...";
my Str $folder = "UNIDATA";
#my $names = slurp "$folder/NameAliases.txt";
my %points;
my %binary_properties;
my %decomp_spec;
sub enumerated-property ( Int $column, Str $negname, Str $propname, Str $filename ) {
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split(';', $column + 1).».trim;
        my %point;
        my $range = @parts[0];
        my $prop-val = @parts[$column];
        %point{$propname} = $prop-val;
        apply-to-cp($range, %point);
    }
}
enumerated-property(1, 'Other', 'Grapheme_Cluster_Break', 'auxillary/GraphemeBreakProperty');
sub register-binary-property (+@names) {
    say "\@names @names.perl()";
    for @names -> $name {
        note "Registering binary property $name";
        if %binary_properties{$name}.defined {
            die "Tried to add $name but binary property already exists";
        }
        %binary_properties{$name} = name => $name, bitwidth => 1;
    }
}
sub tweak_nfg_qc {
    note "Tweaking NFG_QC...";
    # See http://www.unicode.org/reports/tr29/tr29-27.html#Grapheme_Cluster_Boundary_Rules
    for %points.kv -> $code, $point {
        # \r
        if ($code == 0x0D) {
            $point<NFG_QC> = False;
        }
        # SpacingMark, and a couple of specials
        elsif ($point<gencat_name> eq 'Mc' || $code == 0x0E33 || $code == 0x0EB3) {
            $point<NFG_QC> = False;
        }
        # For now set all Emoji to NFG_QC 0
        # Eventually we will only want to set the ones that are NOT specified
        # as ZWJ sequences
        for <Grapheme_Cluster_Break Emoji Hangul_Syllable_Type> -> $prop {
            $point{$prop} = False if $point{$prop}:exists;
        }
    }
}
# NameAliases.txt
# 0 Codepoint (Hex)
# 1 NameAlias
# 2 NameAlias type
# sub path($cp, +@a) { say "\@.perl: @a.perl()"; @a.reduce({ $^a{$^b}:exists ?? $^a{$^b} !! $^a{$^b} = {} }) };
sub slurp-lines ( Str $filename ) returns Seq {
    note "Reading $filename.txt...";
    "$folder/$filename.txt".IO.slurp.lines;
}
sub prefix:< ¿ > ( Str $str ) { $str.defined and $str ne '' ?? True !! False }
sub infix:< ?= > ($left is rw, $right) { $left = $right if ¿$right }
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
    register-binary-property(<Bidi_Class NFD_QC NFC_QC NFKD_QC NFG_QC Any Bidi_Mirrored>);
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split(';');
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = @parts;
        my $cp = :16($code-str);
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
        %hash<suc>     = :16($suc) if ¿$suc;
        %hash<slc>     = :16($slc) if ¿$slc;
        %hash<stc>     = :16($stc) if ¿$stc;
        %hash<NFD_QC>  = True;
        %hash<NFC_QC>  = True;
        %hash<NFKD_QC> = True;
        %hash<NFG_QC>  = True;
        %hash<Any>     = True;
        %hash<Bidi_Mirrored> = True if $bidimirrored eq 'Y';
        if $decmpspec {
            my @dec = $decmpspec.split(' ');
            if @dec[0].match(/'<'\w+'>'/) {
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
    if $range-str.match(/ ^ ( <:AHex>+ ) '..' ( <:AHex> ) $ /) {
        $range = Range.new: :16(~$0), :16(~$1);
    }
    # Otherwise there's only one point
    elsif $range-str ~~ / ^ (<:AHex>+) $ / {
        $_ = :16(~$0);
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
tweak_nfg_qc();
note "Converting data to JSON...";
spurt "points.json", to-json(%points);
spurt "decomp_spec.json", to-json(%decomp_spec);
spurt "binary_properties", to-json(%binary_properties);
say %points{"\r".ord};
say %decomp_spec{"\r".ord};
say %binary_properties.perl;
