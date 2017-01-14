use JSON::Fast;
use nqp;
use Data::Dump;
use lib 'lib';
use UCDlib;
INIT say "Initializing...";
my Str $folder = "UNIDATA";
my %points{Int};
my %binary-properties;
my %decomp_spec;
sub MAIN ( Bool :$dump = False, Bool :$make = False ) {
    chdir "..";
    binary-property(1, 'emoji/emoji-data');
    # Not needed, in UnicodeData ?
    #binary-property(1, 'extracted/DerivedBinaryProperties');
    UnicodeData("UnicodeData");
    enumerated-property(1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty');
    NameAlias("NameAlias", "NameAliases" );
    tweak_nfg_qc();
    dump-json() if $dump;
    if $make {
        spurt "bitfield.c", make-bitfield-rows();
    }
}
sub dump {
    say 'Dumping %points';
    Dump-Range(900..1000, %points);
}
sub binary-property ( Int $column, Str $filename ) {
    my %props-seen;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim(/';'|'#'/, $column + 2);
        my $property = @parts[$column];
        %props-seen{$property} = True unless %props-seen{$property};
        my $range = @parts[0];
        my %point;
        %point{$property} = True;
        #say "Range: $range Property: $property";
        apply-to-cp($range, %point);
    }
    register-binary-property(%props-seen.keys.sort);
}
sub enumerated-property ( Int $column, Str $negname, Str $propname, Str $filename ) {
    # XXX program for @ references for ranges in the comments
    my %seen-values;
    my %points-by-range;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim(/';'|'#'/, $column + 2);
        my $range = @parts[0];
        my $prop-val = @parts[$column];
        %seen-values{$prop-val} = True;
        my %point;
        %point{$propname} = $prop-val;
        %points-by-range{$range} = %point;
    }
    my %enum;
    my $number = 0;
    %enum{$number++} = $negname;
    for %seen-values.keys.sort {
        %enum{$_} = $number++;
    }
    say %seen-values.perl;
    say %enum;
    for %points-by-range.keys -> $range {
        %points-by-range{$range}{$propname} = %enum{%points-by-range{$range}{$propname}};
        apply-to-cp($range, %points-by-range{$range});
    }
}
sub register-binary-property (+@names) {
    for @names -> $name {
        note "Registering binary property $name";
        if %binary-properties{$name}.defined {
            note "Tried to add $name but binary property already exists";
        }
        %binary-properties{$name} = name => $name, bitwidth => 1;
    }
}
sub tweak_nfg_qc {
    note "Tweaking NFG_QC...";
    # See http://www.unicode.org/reports/tr29/tr29-27.html#Grapheme_Cluster_Boundary_Rules
    quietly for %points.keys -> $code {
        die %points{$code}.perl if $code.defined.not;
        # \r
        if ($code == 0x0D) {
            %points{$code}<NFG_QC> = False;
        }
        # SpacingMark, and a couple of specials
        elsif (%points{$code}<gencat_name> eq 'Mc' || $code == 0x0E33 || $code == 0x0EB3) {
            %points{$code}<NFG_QC> = False;
        }
        # For now set all Emoji to NFG_QC 0
        # Eventually we will only want to set the ones that are NOT specified
        # as ZWJ sequences
        for <Grapheme_Cluster_Break Emoji Hangul_Syllable_Type> -> $prop {
            %points{$code}<NFG_QC>= False if %points{$code}{$prop};
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
    "$folder/$filename.txt".IO.slurp.lines orelse die;
}
multi sub prefix:< ¿ > ( Str $str ) { $str.defined and $str ne '' ?? True !! False }
multi sub prefix:< ¿ > ( Bool $bool ) { $bool.defined and $bool != False }
sub infix:< =? > ($left is rw, $right) { $left = $right if ¿$right }
sub infix:< ?= > ($left is rw, $right) { $left = $right if ¿$left }
sub skip-line ( Str $line ) {
    $line.starts-with('#') or $line.match(/^\s*$/) ?? True !! False;
}
sub NameAlias ( Str $property, Str $file ) {
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split-trim(';');
        my %hash;
        %hash{$property}{@parts[1]}<type> = @parts[2];
        apply-to-cp(@parts[0], %hash)
    }
}
sub UnicodeData ( Str $file ) {
    register-binary-property(<NFD_QC NFC_QC NFKD_QC NFG_QC Any Bidi_Mirrored>);
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
        return if $cp > 1000;
        my %hash;
        %hash<Unicode_1_Name>            =? $u1name;
        %hash<name>                      =? $name;
        %hash<gencat_name>               =? $gencat;
        %hash<General_Category>          =? $gencat;
        %hash<Canonical_Combining_Class> =? $ccclass;
        %hash<Bidi_Class>                =? $bidiclass;
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
sub apply-to-cp (Str $range-str, Hash $hashy) {
    my $range;
    # If it contains .. then it is a range
    if $range-str.match(/ ^ ( <:AHex>+ ) '..' ( <:AHex>+ ) $ /) {
        $range = Range.new: :16(~$0), :16(~$1);
    }
    # Otherwise there's only one point
    elsif $range-str.match(/ ^ (<:AHex>+) $ /) {
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
sub apply-to-points (Int $cp, Hash $hashy) {
    for $hashy.keys -> $key {
        if !defined %points{$cp}{$key} {
            %points{$cp}{$key} = $hashy{$key};
        }
        else {
            for $hashy{$key}.keys -> $key2 {
                if !defined %points{$cp}{$key}{$key2} {
                    say "\$hashy\{$key\}\{$key2\}";
                    %points{$cp}{$key}{$key2} = $hashy{$key}{$key2};
                }
                else {
                    die "This level of hash NYI";
                }
            }
        }
    }
}

sub make-bitfield-rows {
    note "Making bitfield-rows";
    my %code-to-prop;
    my %prop-to-code;
    my Int $i = 0;
    my $binary-struct-str;
    # Create the order of the struct
    my $header = "struct binary_prop_bitfield  \{\n";
    for %binary-properties.keys.sort -> $bin {
        %prop-to-code{$bin} = $i;
        %code-to-prop{$i} = $bin;
        $i++;
        $header ~= "    unsigned int $bin :1;\n"
    }
    $header ~= "\};\n";
    $header ~= "typedef struct binary_prop_bitfield binary_prop_bitfield;\n";
    my Int $bin-index = 0;
    # Not sure why the Int's turn into strings…
    for %points.keys.sort.lazy -> $point {
        die if $point !~~ Int;
        my @props;
        for %code-to-prop.keys.sort -> $propcode {
            my $prop = %code-to-prop{$propcode};
            if %points{$point}{$prop}:exists {
                @props.push(%points{$point}{$prop} ?? 1 !! 0);
            }
            else {
                @props.push(0);
            }
        }
        $binary-struct-str ~= '    {' ~ @props.join(',') ~ "\},/* $point.Int.uniname() */"  ~ "\n";
        # If we matched ANY of the binary properties, increment the index by one
        # and set this points index for binary props

        %points{$point}<index><binary> = $bin-index++;

    }
    $binary-struct-str ~~ s/','$//;
    my @array;
    push @array, $header;
    push @array, qq:to/END/;
    #include <stdio.h>
    static const binary_prop_bitfield mybitfield[$bin-index] = \{
        $binary-struct-str
        \};
    END
    push @array, q:to/END2/;
    int main (void) {
        printf("U+0000 Bidi_Mirrored: %i NFG_QC: %i\n", mybitfield[0].Bidi_Mirrored, mybitfield[0].NFG_QC);
    }
    END2
    #push @array, $binary-struct-str;
    return @array.join("\n");
}

sub dump-json ( Bool $dump ) {
    note "Converting data to JSON...";
    if $dump {
        spurt "points.json", to-json(%points);
        spurt "decomp_spec.json", to-json(%decomp_spec);
    }
    spurt "enumerated-property.json", to-json(%enumerated-property);
    spurt "binary-properties.json", to-json(%binary-properties);
}
