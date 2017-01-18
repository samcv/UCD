use JSON::Fast;
use nqp;
use Data::Dump;
use lib 'lib';
use UCDlib;
use EncodeBase40;
BEGIN say "Initializing…";
INIT  say "Starting…";
my Str $UNIDATA-folder = "UNIDATA";
my Str $build-folder = "build";
my Str $snippets-folder = "snippets";
if !$build-folder.IO.d {
  mkdir $build-folder;
}
my %points;
my %names = nqp::hash;
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
sub MAIN ( Bool :$dump = False, Bool :$nomake = False, Int :$less = 0, Bool :$debug = False, Bool :$names-only = False ) {
    $debug-global = $debug;
    UnicodeData("UnicodeData", $less);
    my $name-file = Generate_Name_List();
    unless $names-only {
        enumerated-property(1, 'None', 'Numeric_Type', 'extracted/DerivedNumericType');

        enumerated-property(1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty');
    }
    unless $less or $names-only {
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
        my $int-main = Q:to/END/;
        int main (void) {
        END
        my $more = Q:to/END4/;
            printf("index %i\n", point_index['6']);
            printf("%lli\n", Numeric_Value_Numerator[mybitfield[point_index['6']].Numeric_Value_Numerator]);
            unsigned int cp = 0x28;
        END4
        $int-main ~= $less == 0 ?? $more !! '';
        my $var = q:to/END2/;
            for (int i = 0; i < 150; i++) {
                int cp_index = (int) point_index[i];
                if ( cp_index > max_bitfield_index ) {
                    printf("Character has no values we know of\n");
                    return 1;
                }
                unsigned int cp_GCB = mybitfield[cp_index].Grapheme_Cluster_Break;
                char * printf_s = "U+%X [%c] Bidi_Mirrored: %i GCB: %s(%i)\n";
                char * printf_s_control = "U+%X Bidi_Mirrored: %i GCB: %s(%i)\n";
                if (cp_GCB != Uni_PVal_GRAPHEME_CLUSTER_BREAK_Control ) {
                    printf(printf_s, i, (char) i, mybitfield[cp_index].Bidi_Mirrored, Grapheme_Cluster_Break[cp_GCB], cp_GCB );
                }
                else {
                    printf(printf_s_control, i, mybitfield[cp_index].Bidi_Mirrored, Grapheme_Cluster_Break[cp_GCB], cp_GCB );
                }
            }
        }
        END2
        $int-main ~= $var;
        my $bitfield_c = (make-enums(), make-bitfield-rows(), make-point-index(), $int-main).join;
        note "Saving bitfield.c…";
        spurt "$build-folder/bitfield.c", $bitfield_c;
        spurt "$build-folder/names.c", $name-file;
    }
    say "Took {now - INIT now} seconds.";
}
sub dump {
    say 'Dumping %points';
    Dump-Range(900..1000, %points);
}
sub Generate_Name_List {
    my $names_l := nqp::list_s;
    my $max = %names.keys.map({$^a.Int}).max;
    my $c-type = compute-type(40**3);
    my $t1 = now;
    my $all-elems;
    my %seen-words;
    for 0..$max -> $cp {
        my str $cp_s = nqp::base_I(nqp::decont($cp), 10);
        if nqp::existskey(%names, $cp_s) {
            my $s := nqp::atkey(%names, $cp_s);
            # XXX for now we just skip these
            if $s.contains('<') {
                nqp::push_s($names_l, "0, /* empty: $s */");
                $all-elems++;
                next;
            }
            my @a = encode-base40-string($s);
            my $elems = @a.elems;
            $all-elems += $elems + 1;
            nqp::push_s($names_l,
                $elems ~ ',' ~ @a.join(',') ~ ',' ~ " /* $s */"
            );
        }
        # If we have no name just push a 0
        else {
            nqp::push_s($names_l, '0, /* empty */');
            $all-elems++;
        }
    }
    nqp::push_s($names_l, "\};\n");
    my $string = join( '',
                "#include <stdio.h>\n",
                "#define uninames_elems $all-elems\n",
                get-base40-c-table(),
                $c-type ~ ' uninames[' ~ $all-elems ~ '] = {' ~ "\n",
                nqp::join("\n", $names_l),
                "$snippets-folder/tail_names.c".IO.slurp,
                );
    say "Took " ~ now - $t1 ~ " seconds to generate name list";
    return $string;
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
        if %binary-properties{$name}:exists {
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
    say Dump %seen-values if $debug-global;
    # Start the enum values at 0
    my Int $number = 0;
    # Our false name we got should be number 0, and will be different depending on the category
    if $type eq 'Str' {
        %enum{$negname} = $number++;
        %seen-values{$negname}:delete;
        for %seen-values.keys.sort {
            %enum{$_} = $number++;
        }
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
    %enumerated-properties{$propname} = %enum;
    say Dump %enumerated-properties if $debug-global;
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
        die %points{$code}.perl unless $code.defined;
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
    "$UNIDATA-folder/$filename.txt".IO.slurp.lines orelse die;
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
        my %hash;
        %hash<Unicode_1_Name>            =? $u1name;
        if $name {
            nqp::bindkey(%names, nqp::base_I(nqp::decont($cp), 10), $name);
        }
        # We may not need to set the name in the hash in case we only rely on %names;
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
    # If it contains `..` then it is a range
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
    for $hashy.keys -> $key {
        if !defined %points{$cp}{$key} {
            %points{$cp}{$key} = $hashy{$key};
        }
        else {
            for $hashy{$key}.keys -> $key2 {
                if !defined %points{$cp}{$key}{$key2} {
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
                }
                else {
                    die "This level of hash NYI";
                }
            }
        }
    }
}

sub make-enums {
    note "Making enums…";
    my @enums;
    say Dump %enumerated-properties if $debug-global;
    my $header;
    for %enumerated-properties.keys -> $prop {
        my str $enum-str;
        my $type = %enumerated-properties{$prop}<type>;
        my $rev-hash = reverse-hash-int-only(%enumerated-properties{$prop});
        say $rev-hash if $debug-global;
        if $type eq 'Str' {
            for $rev-hash.keys.sort {
                $enum-str = ($enum-str, $indent, Q<">, $rev-hash{$_}, qq[",\n]).join;
            }
            $enum-str = (compute-type('char *'), $prop, "[", $rev-hash.elems, "] = \{\n", $enum-str, "\n\};\n").join;
        }
        elsif $type eq 'Int' {
            for $rev-hash.keys.sort {
                $enum-str = ($enum-str, $indent, $rev-hash{$_}, ",\n").join;
            }
            say Dump $rev-hash if $debug-global;
            $enum-str = (compute-type($rev-hash.values.».Int.max, $rev-hash.values.».Int.min ), " $prop", "[", $rev-hash.elems, "] = \{\n", $enum-str, "\n\};\n").join;
        }
        else {
            die "Don't know how to make an enum of type '$type'";
        }
        # Create the #define's for the Property Value's
        for $rev-hash.kv -> $enum-no, $prop-val {
            my $prop-val-name = $prop-val.subst('-', 'minus');
            $header ~= "#define Uni_PVal_{$prop.uc}_$prop-val-name $enum-no\n";
        }
        @enums.push($enum-str);
    }
    @enums.unshift($header);
    @enums.join("\n");
}
sub make-point-index (:$less) {
    note "Making point_index…\n";
    my int $point-max = %points.keys.sort(-*)[0].Int;
    say "point-max $point-max";
    my $type = compute-type($bin-index + 1);
    my $mapping := nqp::list_s;
    my $mapping_rows := nqp::list_s;
    my @rows;
    my $i := nqp::add_i(0, 0);
    my int $bin-index_i = nqp::unbox_i($bin-index);
    my $t1 = now;
    nqp::while( nqp::isle_i($i, $point-max), (
        my str $point_s = nqp::base_I($i, 10);
        nqp::if(nqp::existskey(%point-index, $point_s),
            # if
            nqp::push_s($mapping, nqp::atkey(%point-index, $point_s)),
            # XXX for now let's denote things that have no value with 1 more than max index
            # else
            nqp::push_s($mapping, nqp::atkey(%point-index, nqp::add_i($bin-index_i, 1))) # -1 represents NULL
        );
        $i := nqp::add_i($i, 1);
      )
    );
    my $string = nqp::join(",", $mapping);
    my int $chars = nqp::chars($string);
    say "Adding nowlines every 50-60 chars";
    $string ~~ s:g/(.**70..79',')/$0\n/;
    say now - $t1 ~ "Took this long to concat points";
    my $mapping-str = ("#define max_bitfield_index $point-max\n$type point_index[", $point-max + 1, "] = \{\n    ", $string, "\n\};\n").join;
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
    for %enumerated-properties.keys.sort({%enumerated-properties{$^a}<bitwidth> cmp %enumerated-properties{$^b}<bitwidth>}) -> $property {
        %prop-to-code{$property} = $i;
        %code-to-prop{$i} = $property;
        $i++;
        my $bitwidth = %enumerated-properties{$property}<bitwidth>;
        $header = nqp::concat($header, "    unsigned int $property :$bitwidth;\n");
    }
    $header = nqp::concat($header, "\};\n");
    $header = nqp::concat($header, "typedef struct binary_prop_bitfield binary_prop_bitfield;\n");
    my $bitfield-rows := nqp::list_s;
    my %bitfield-rows-seen = nqp::hash;
    my @code-to-prop-keys = %code-to-prop.keys.sort(+*);
    my $t1 = now;
    quietly for %points.keys.sort(+*) -> $point {
        my $bitfield-columns := nqp::list_s;
        for @code-to-prop-keys -> $propcode {
            my $prop = %code-to-prop{$propcode};
            if %points{$point}{$prop}:exists {
                if nqp::existskey(%binary-properties, $prop) {
                    nqp::push_s($bitfield-columns, nqp::unbox_s(%points{$point}{$prop} ?? '1' !! '0'));
                }
                elsif nqp::existskey(%enumerated-properties, $prop) {
                    my $enum := %points{$point}{$prop};
                    # If the key exists we need to look up the value
                    if %enumerated-properties{$prop}{$enum}:exists {
                        $enum := %enumerated-properties{$prop}{ $enum };
                        nqp::push_s($bitfield-columns, nqp::base_I(nqp::decont($enum),10));
                    }
                    # If it doesn't exist it's an Int property. Eventually we should try and look
                    # up the enum type in the hash
                    # XXX make it so we have consistent functionality for Int and non Int enums
                    else {
                        nqp::push_s($bitfield-columns, nqp::base_I(nqp::decont($enum),10));
                    }
                }
                else {
                    die;
                }
            }
            else {
                nqp::push_s($bitfield-columns, '0');
            }
        }
        my str $bitfield-rows-str = nqp::join('', nqp::list_s('    {', nqp::join(',', $bitfield-columns), '},'));
        # If we've already seen an identical row
        nqp::if(nqp::existskey(%bitfield-rows-seen, $bitfield-rows-str), (
            nqp::bindkey(%point-index, nqp::unbox_s($point), nqp::atkey(%bitfield-rows-seen, $bitfield-rows-str))
        ),
        (
            my str $bin-index_s = nqp::base_I(++$bin-index, 10);
            # Bind it to the bitfield rows hash
            nqp::bindkey(%bitfield-rows-seen, $bitfield-rows-str, $bin-index_s);
            # Bind the point index so we know where in the bitfield this point is located
            nqp::bindkey(%point-index, nqp::unbox_s($point), $bin-index_s);
        )
        );

    }
    my $t2 = now;
    say "Finished computing all rows, took {now - $t1}. Now creating the final unduplicated version.";
    for %bitfield-rows-seen.sort(+*.value).».kv -> ($row-str, $index) {
        nqp::push_s($bitfield-rows, nqp::concat($row-str, "/* index $index */"));
    }
    $binary-struct-str = nqp::join("\n", $bitfield-rows);
    my @array;
    push @array, $header;
    my $prefix = get-prefix();
    push @array, qq:to/END/;
    #include <stdio.h>
    $prefix binary_prop_bitfield mybitfield[{$bin-index + 1}] = \{
    $binary-struct-str
        \};
    END
    say "Took {now - $t2} seconds to join all the seen bitfield rows";
    return @array.join("\n");
}

sub dump-json ( Bool $dump ) {
    note "Converting data to JSON...";
    if $dump {
        spurt $build-folder ~ %points.VAR.name ~ '.json', to-json(%points);
        spurt $build-folder ~ %decomp_spec.VAR.name ~ '.json', to-json(%decomp_spec);
    }
    spurt $build-folder ~ %enumerated-properties.VAR.name ~ '.json', to-json(%enumerated-properties);
    spurt $build-folder ~ %binary-properties.VAR.name ~ '.json', to-json(%binary-properties);
}
