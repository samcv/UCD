use JSON::Fast;
use nqp;
use Data::Dump;
use lib 'lib';
use UCDlib;
INIT say "Initializing…";
my Str $folder = "UNIDATA";
my %points;
my %binary-properties;
my %enumerated-properties;
my %all-properties;
my %decomp_spec;
my %point-to-struct;
my %bitfields;
my %point-index = nqp::hash;
my $debug-global = False;
my int $bin-index = -1;
my $indent = "\c[SPACE]" x 4;
sub MAIN ( Bool :$dump = False, Bool :$nomake = False, Int :$less = 0, :$debug = False ) {
    $debug-global = $debug;
    chdir "..";

    UnicodeData("UnicodeData", $less);
    enumerated-property(1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty');
    enumerated-property(1, 'None', 'Numeric_Type', 'extracted/DerivedNumericType');
    unless $less {
        DerivedNumericValues('extracted/DerivedNumericValues');
        enumerated-property(1, 'N', 'East_Asian_Width', 'extracted/DerivedEastAsianWidth');
        enumerated-property(1, 'N', 'East_Asian_Width', 'EastAsianWidth');
        enumerated-property(1, '', 'Jamo_Short_Name', 'Jamo');
        binary-property(1, 'PropList');
        enumerated-property(1, 'L', 'Bidi_Class', 'extracted/DerivedBidiClass');
        enumerated-property(1, 'No_Joining_Group', 'Joining_Group', 'extracted/DerivedJoiningGroup');
        enumerated-property(1, 'Non_Joining', 'Joining_Type', 'extracted/DerivedJoiningGroup');
        binary-property(1, 'emoji/emoji-data');
        binary-property(1, 'DerivedCoreProperties');
        enumerated-property(1, 'Other', 'Word_Break', 'auxiliary/WordBreakProperty');
        enumerated-property(1, 'Other', 'Line_Break', 'LineBreak');
        # Not needed, in UnicodeData ?
        # Also we don't account for this case where we try and add a property that already exists
        binary-property(1, 'extracted/DerivedBinaryProperties');
        #NameAlias("NameAlias", "NameAliases" );
        tweak_nfg_qc();
    }
    dump-json($dump);
    unless $nomake {
        my $var = q:to/END2/;
        int main (void) {
            printf("index %i\n", point_index['6']);
            printf("%lli\n", Numeric_Value_Numerator[mybitfield[point_index['6']].Numeric_Value_Numerator]);
            unsigned int cp = 0x28;
            int index = point_index[cp];
            if ( index > max_bitfield_index ) {
                printf("Character has no values we know of\n");
                return 1;
            }
            printf("Index: %i", index);
            unsigned int num = mybitfield[index].Grapheme_Cluster_Break;
            printf("GCB enum %i\n", num);
            char * str = Grapheme_Cluster_Break[num];
            printf("GCB = %s\n", str);
            printf("U+%X Bidi_Mirrored: %i\n", cp, mybitfield[index].Bidi_Mirrored );
        }

        END2
        my $bitfield_c = (make-enums(), make-bitfield-rows(), make-point-index(), $var).join('');
        note "Saving bitfield.c…";
        spurt "bitfield.c", $bitfield_c;
    }
    say "Took {now - INIT now} seconds.";
}
sub dump {
    say 'Dumping %points';
    Dump-Range(900..1000, %points);
}
sub DerivedNumericValues ( Str $filename ) {
    my %numerator-seen;
    my %denominator-seen;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim(/';'|'#'/);
        my $number = @parts[3];
        my $cp = @parts[0];
        my ($numerator, $denominator);
        if $number.contains('/') {
            ($numerator, $denominator) = $number.split('/');
        }
        else {
            $numerator = $number;
            $denominator = 1;
        }
        %numerator-seen{$numerator} = True;
        %denominator-seen{$denominator} = True;
        my %point = 'Numeric_Value_Numerator' => $numerator.Int, 'Numeric_Value_Denominator' => $denominator.Int;
        apply-to-cp($cp, %point);

    }
    register-enum-property('Numeric_Value_Denominator', 0, %denominator-seen);
    register-enum-property('Numeric_Value_Numerator', 0, %numerator-seen);
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
    # Eventually this may be able to be wrapped into register-enum-property
    my %enum = register-enum-property($propname, $negname, %seen-values);
    for %points-by-range.keys -> $range {
        %points-by-range{$range}{$propname} = %enum{%points-by-range{$range}{$propname}};
        apply-to-cp($range, %points-by-range{$range});
    }
}
sub register-binary-property (+@names) {
    for @names -> $name {
        die if $name !~~ Str;
        note "Registering binary property $name";
        if %binary-properties{$name}.defined {
            note "Tried to add $name but binary property already exists";
        }
        %binary-properties{$name} = name => $name, bitwidth => 1;
        %all-properties{$name} = %binary-properties{$name};
    }
}
sub compute-bitwidth ( Int $max ) {
    $max.base(2).chars;
}
# Eventually we will make a multi that can take ints
sub register-enum-property (Str $propname, $negname, %seen-values) {
    my %enum;
    my $type = $negname.WHAT.^name;
    note "Registering type $type enum property $propname";
    # Start the enum values at 0
    my Int $number = 0;
    # Our false name we got should be number 0, and will be different depending on the category
    if $type eq 'Str' {
        %enum{$negname} = $number++;
        %seen-values{$negname}:delete;
        say Dump %enum;
        say Dump %seen-values;
        for %seen-values.keys.sort {
            %enum{$_} = $number++;
        }
        say Dump %enum;
    }
    elsif $type eq 'Int' {
        for %seen-values.keys.sort({$^a.Int cmp $^b.Int}) {
            %enum{$_} = $number++;
        }
    }
    else {
        die "Don't know how to register enum property of type '$type'";
    }
    die "Don't see any 0 value for the enum, neg should be $negname" unless any(%enum.values) == 0;
    my Int $max = $number - 1;
    say %enum.perl;
    #exit;
    %enumerated-properties{$propname} = %enum;
    %enumerated-properties{$propname}<name> = $propname;
    %enumerated-properties{$propname}<bitwidth> = compute-bitwidth($max);
    %enumerated-properties{$propname}<type> = $type;
    %all-properties{$propname} = %enumerated-properties{$propname};
    return %enum;
}
sub tweak_nfg_qc {
    note "Tweaking NFG_QC…";
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
sub slurp-lines ( Str $filename ) returns Seq {
    note "Reading $filename.txt…";
    "$folder/$filename.txt".IO.slurp.lines orelse die;
}
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
sub UnicodeData ( Str $file, Int $less = 0 ) {
    register-binary-property(<NFD_QC NFC_QC NFKD_QC NFG_QC Any Bidi_Mirrored>);
    my %seen-ccc;
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split(';');
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = @parts;
        my $cp = :16($code-str);
        next if $less != 0 and $cp > $less;
        if ($name eq '<control>' ) {
            $name = sprintf '<control-%.4X>', $cp;
        }
        #return if $cp > 1000;
        my %hash;
        %hash<Unicode_1_Name>            =? $u1name;
        %hash<name>                      =? $name;
        %hash<gencat_name>               =? $gencat;
        %hash<General_Category>          =? $gencat;
        if $ccclass {
            %seen-ccc{$ccclass} = True unless %seen-ccc{$ccclass}:exists;
            %hash<Canonical_Combining_Class> = $ccclass.Int;
        }
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
    # For now register it as a string enum, will change when a register-enum-property multi is made
    register-enum-property("Canonical_Combining_Class", 0, %seen-ccc);

}
sub apply-to-cp (Str $range-str, Hash $hashy) {
    my $range;
    # If it contains .. then it is a range
    if $range-str.match(/ ^ ( <:AHex>+ ) '..' ( <:AHex>+ ) $ /) {
        $range = Range.new: :16(~$0), :16(~$1);
        for $range.lazy -> $cp {
            apply-to-points($cp, $hashy);
        }
    }
    # Otherwise there's only one point
    elsif $range-str.match(/ ^ (<:AHex>+) $ /) {
        apply-to-points(:16(~$0), $hashy);
    }
    else {
        die "Unknown range '$range-str'";
    }

}
sub apply-to-points (Int $cp, Hash $hashy) {
    state $lock = Lock.new;
    for $hashy.keys -> $key {
        if !defined %points{$cp}{$key} {
            %points{$cp}{$key} = $hashy{$key};
        }
        else {
            for $hashy{$key}.keys -> $key2 {
                if !defined %points{$cp}{$key}{$key2} {
                    #say sprintf "U+%X key: %s key2 %s", $cp, $key, $key2;
                    #say Dump $hashy;
                    given $key2.WHAT.^name {
                        when 'Int' {
                            %points{$cp}{$key} = $hashy{$key};
                        }
                        when 'Bool' {
                            %points{$cp}{$key} = $hashy{$key};
                        }
                        default {
                            die "Don't know how to apply type $_ in apply-to-points";
                        }
                    }

                    #%points{$cp}{$key}{$key2} = $hashy{$key}{$key2};
                }
                else {
                    die "This level of hash NYI";
                }
            }
        }
    }
}

sub make-enums (:$debug, :%enumerated-properties) {
    note "Making enums…";
    my @enums;
    for %enumerated-properties.keys -> $prop {
        my str $enum-str;
        my $type = %enumerated-properties{$prop}<type>;
        my $rev-hash = reverse-hash-int-only(%enumerated-properties{$prop});
        say $rev-hash if $debug;
        if $type eq 'Str' {
            for $rev-hash.keys.sort {
                $enum-str = [~] $enum-str, $indent, Q<">, $rev-hash{$_}, Q<">, ",\n";
            }
            $enum-str = [~] "static char *$prop", "[", $rev-hash.elems, "] = \{\n", $enum-str, "\n\};\n";
        }
        elsif $type eq 'Int' {
            for $rev-hash.keys.sort {
                $enum-str = [~] $enum-str, $indent, $rev-hash{$_}, ",\n";
            }
            say Dump $rev-hash if $debug-global;
            $enum-str = [~] compute-type($rev-hash.values.».Int.max, $rev-hash.values.».Int.min ), " $prop", "[", $rev-hash.elems, "] = \{\n", $enum-str, "\n\};\n";
        }
        else {
            die "Don't know how to make an enum of type '$type'";
        }
        @enums.push($enum-str);
        #for %enumerated-properties{$prop}.values.sort -> $value {
        #    say $value
        #}
    }
    @enums.join("\n");
}
sub make-point-index (:$less) {
    note "Making point_index…\n";
    my Int $point-max = %points.keys.sort(-*)[0].Int;
    say "point-max $point-max";
    my $type = compute-type($bin-index + 1);
    my $mapping := nqp::list_s;
    my @rows;
    my int $bin-index_i = nqp::unbox_i($bin-index);
    for 0…$point-max -> $point {
        my str $point_s = nqp::base_I(nqp::decont($point), 10);
        nqp::if(nqp::existskey(%point-index, $point_s),
            # if
            nqp::push_s($mapping, nqp::atkey(%point-index, $point_s)),
            # XXX for now let's denote things that have no value with 1 more than max index
            # else
            nqp::push_s($mapping, nqp::atkey(%point-index, nqp::add_i($bin-index_i, 1))) # -1 represents NULL
        );
    }
    my $t1 = now;
    my str $string = nqp::join(',', $mapping);
    say now - $t1 ~ "Took this long to concat points";
    #for ^nqp::elems($mapping) {
    #    nqp
    #$mapping := nqp::list_s;
    my $mapping-str = ("#define max_bitfield_index $point-max\nstatic $type point_index[", $point-max + 1, "] = \{\n    ", $string, "\n\};\n").join('');
    $mapping-str;
}
sub make-bitfield-rows {
    note "Making bitfield-rows…";
    my %code-to-prop{Int};
    my %prop-to-code;
    my Int $i = 0;
    my str $binary-struct-str;
    # Create the order of the struct
    my str $header = "struct binary_prop_bitfield  \{\n";
    for %binary-properties.keys.sort -> $bin {
        %prop-to-code{$bin} = $i;
        %code-to-prop{$i} = $bin;
        $i++;
        $header = nqp::concat($header,"    unsigned int $bin :1;\n");
    }
    for %enumerated-properties.keys.sort -> $property {
        %prop-to-code{$property} = $i;
        %code-to-prop{$i} = $property;
        $i++;
        my $bitwidth = %enumerated-properties{$property}<bitwidth>;
        $header = nqp::concat($header, "    unsigned int $property :$bitwidth;\n");
    }
    #say %enumerated-properties.perl;
    #exit;
    $header = nqp::concat($header, "\};\n");
    $header = nqp::concat($header, "typedef struct binary_prop_bitfield binary_prop_bitfield;\n");
    my @bitfield-rows;
    my %bitfield-rows-seen;
    my @code-to-prop-keys = %code-to-prop.keys.sort(+*);
    my $t1 = now;
    quietly for %points.keys.sort(+*) -> $point {
        #say $point;
        my int @bitfield-columns;
        for @code-to-prop-keys -> $propcode {
            my $prop = %code-to-prop{$propcode};
            #say "$propcode $prop";
            if %points{$point}{$prop}:exists {
                if %binary-properties{$prop}:exists {
                    nqp::push_i(@bitfield-columns, %points{$point}{$prop} ?? 1 !! 0);
                }
                elsif %enumerated-properties{$prop}:exists {
                    my $enum := %points{$point}{$prop};
                    # If the key exists we need to look up the value
                    if %enumerated-properties{$prop}{ $enum }:exists {
                        $enum := %enumerated-properties{$prop}{ $enum };
                        nqp::push_i(@bitfield-columns, $enum);
                    }
                    # If it doesn't exist it's an Int property. Eventually we should try and look
                    # up the enum type in the hash
                    # XXX make it so we have consistent functionality for Int and non Int enums
                    else {
                        nqp::push_i(@bitfield-columns, $enum);
                    }
                }
                else {
                    die;
                }
            }
            else {
                nqp::push_i(@bitfield-columns,0);
            }
        }
        my $bitfield-rows-str =  ('    {', @bitfield-columns.join(","), '},').join('');
        # If we've already seen an identical row
        if %bitfield-rows-seen{$bitfield-rows-str}:exists {
            nqp::bindkey(%point-index, nqp::unbox_s($point), nqp::base_I(nqp::decont(%bitfield-rows-seen{$bitfield-rows-str}), 10));
            #%point-index{$point} = $bin-index;
        }
        else {
            %bitfield-rows-seen{$bitfield-rows-str} = ++$bin-index;
            nqp::bindkey(%point-index, nqp::unbox_s($point), nqp::base_I(nqp::decont($bin-index),10));
        }

    }
    my $t2 = now;
    say "Finished computing all rows, took {now - $t1}. Now creating the final unduplicated version.";
    for %bitfield-rows-seen.sort(+*.value).».kv -> ($row-str, $index) {
        @bitfield-rows.push($row-str ~ "/* index $index */");
    }
    $binary-struct-str = @bitfield-rows.join("\n");
    my @array;
    push @array, $header;
    push @array, qq:to/END/;
    #include <stdio.h>
    static const binary_prop_bitfield mybitfield[{$bin-index + 1}] = \{
    $binary-struct-str
        \};
    END
    say "Took {now - $t2} seconds to join all the seen bitfield rows";
    #push @array, $binary-struct-str;
    return @array.join("\n");
}

sub dump-json ( Bool $dump ) {
    note "Converting data to JSON...";
    if $dump {
        spurt %points.VAR.name ~ ".json", to-json(%points);
        spurt "decomp_spec.json", to-json(%decomp_spec);
    }
    spurt "enumerated-property.json", to-json(%enumerated-properties);
    spurt "binary-properties.json", to-json(%binary-properties);
}
