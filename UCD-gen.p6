#!/usr/bin/env perl6
use JSON::Fast;
use MONKEY-TYPING;
use nqp;
use Data::Dump;
use lib 'lib';
use UCDlib;
use ArrayCompose;
use Set-Range;
use seenwords;
use EncodeBase40;
use Operators;
INIT  say "\nStarting…";
my Str $build-folder = "source";
my Str $snippets-folder = "snippets";
# stores lines of bitfield.h
our @bitfield-h;
my %points; # Stores all the cp's property values of all types
my %names = nqp::hash; # Unicode Name hash for generating the name table
my %binary-properties; # Stores the binary property names
# Stores enum prop names and also the property
# codes which are just internal numbers to represent it in the C datastructure
my %enumerated-properties;
# Stores all of the properties. The keys of %binary-properties and %enum-properties
# get assigned to keys of this hash
my %all-properties;
# Stores the decomposition data for NFD
my %decomp_spec;
# Stores PropertyValueAliases from PropertyValueAliases.txt
# Used to go from short names that may be used in the data files to the full names
my %PropertyValueAliases;
my %PropertyNameAliases;
# Stores Property Aliases or Property Value Aliases to their Full Name mappings
my %PropertyNameAliases_to;
my %PropertyValueAliases_to;
my %missing;
my $missing-str = '# @missing';
sub missing (Str $line is copy) {
    # @missing: 0000..10FFFF; cjkAccountingNumeric; NaN
    die unless $line.starts-with($missing-str);
    $line ~~ s/$missing-str': '//;
    my @parts = $line.split-trim(';');
    %missing{@parts[1]} = @parts[2];
}
sub skip-line ( Str $line ) is export {
    if $line eq '' {
        return True;
    }
    elsif $line.starts-with('#') {
        missing($line) if $line.starts-with($missing-str);
        return True;
    }
    elsif $line.starts-with(' ') {
        return True if $line.match(/^\s*$/);
    }
    False;
}
sub PValueAliases (Str $filename, %aliases, %aliases_to?) {
    for slurp-lines($filename) -> $line {
        next if skip-line($line);
        my @parts = $line.split-trim(';');
        my $prop-name = @parts.shift;
        my $short-pvalue = @parts.shift;
        my $long-pvalue = @parts[0];
        $prop-name = get-full-propname($prop-name);
        %aliases{$prop-name}{$short-pvalue} = @parts;
        if defined %aliases_to {
            %aliases_to{$prop-name}{$long-pvalue} = $long-pvalue;
            %aliases_to{$prop-name}{$short-pvalue} = $long-pvalue;
            for @parts {
                %aliases_to{$prop-name}{$_} = $long-pvalue;
            }
        }
    }
}
class pvalue-seen {
    has %.seen-values;
    method saw ($saw) {
        %!seen-values{$saw} = True unless %!seen-values{$saw}:exists;
    }
}
sub PNameAliases (Str $filename, %aliases, %aliases_to?) {
    for slurp-lines($filename) -> $line {
        next if skip-line($line);
        my @parts = $line.split-trim(';');
        my $short-name = @parts.shift;
        my $long-name = @parts.shift;
        push %aliases{$long-name}, $short-name;
        push %aliases{$long-name}, $_ for @parts;
        if defined %aliases_to {
            %aliases_to{$long-name} = $long-name;
            %aliases_to{$short-name} = $long-name;
            for @parts {
                %aliases_to{$_} = $long-name;
            }
        }
    }
}
sub get-property-fullname (Str $name) {

}
my %point-to-struct;
my %bitfields;
my %point-index = nqp::hash;
my $debug-global = False;
my $less-global;
my int $bin-index = -1;
my $indent = "\c[SPACE]" x 4;
sub write-file ( Str $filename is copy, Str $text ) {
    $filename ~~ s/ ^ \W //;
    my $file = "$build-folder/$filename";
    if $text {
        note "Writing $file…";
        $file.IO.spurt($text);
    }
}
sub start-routine {
    if !$build-folder.IO.d {
        say "Creating $build-folder because it does not already exist.";
        mkdir $build-folder;
    }
}
sub MAIN ( Bool :$dump = False, Bool :$nomake = False, Int :$less = 0, Bool :$debug = False, Bool :$names-only = False, Bool :$numeric-value-only = False ) {
    $debug-global = $debug;
    $less-global = $less;
    start-routine();
    PNameAliases("PropertyAliases", %PropertyNameAliases, %PropertyNameAliases_to);
    PValueAliases("PropertyValueAliases", %PropertyValueAliases, %PropertyValueAliases_to);
    my $name-file;
    DerivedNumericValues('extracted/DerivedNumericValues');
    UnicodeData("UnicodeData", $less);
    enumerated-property(1, 'N', 'East_Asian_Width', 'extracted/DerivedEastAsianWidth') unless $less < 200;

    unless $numeric-value-only {
        $name-file = Generate_Name_List();
    }
    unless $names-only or $numeric-value-only {
        my @enum-data =
            (1, 'None', 'Numeric_Type', 'extracted/DerivedNumericType'),
            (1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty');
        for @enum-data {
            enumerated-property(|$_);
        }
        #enumerated-property(1, 'None', 'Numeric_Type', 'extracted/DerivedNumericType');

        #enumerated-property(1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty');
    }
    unless $less or $names-only or $numeric-value-only {
        # The values in this file are already in DerivedEastAsianWidth
        #enumerated-property(1, 'N', 'East_Asian_Width', 'EastAsianWidth');
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
        tweak_nfg_qc();
    }
    dump-json($dump);
    unless $nomake {
        my $int-main;
        if $less == 0 {
            $int-main = slurp-snippets("bitfield", "int-main");
        }
        else {
            $int-main = slurp-snippets("bitfield", "int-main", -2);
        }
        unless $names-only {
            my $bitfield_c = [~] slurp-snippets("bitfield", "header"),
                make-enums(), make-bitfield-rows(), make-point-index(),
                $int-main;
            note "Saving bitfield.c…";
            write-file('bitfield.c', $bitfield_c);
            write-file('bitfield.h', @bitfield-h.join("\n"));
        }
        note "Saving names.c…";
        write-file('names.c', $name-file);
    }
    say "Took {now - INIT now} seconds.";
}
sub Generate_Name_List {
    my $t0_nl = now;
    my $max = %names.keys.map({$^a.Int}).max;
    my $no-empty = True;
    my $set-range = Set-Range.new;
    my base40-string $base40-string;
    my $seen-words = seen-words.new(levels-to-gen => 1);
    sub get-shift-levels {
        for 0..$max -> $cp {
            my str $cp_s = nqp::base_I(nqp::decont($cp), 10);
            if nqp::existskey(%names, $cp_s) {
                my $s := nqp::atkey(%names, $cp_s);
                if $s.contains('<') {
                    next;
                }
                $seen-words.saw-line($s);
            }
        }
        $base40-string = $base40-string.new(shift-level-one => $seen-words.get-shift-one-array);

    }
    get-shift-levels(); # this is the sub directly above

    my $c-type = compute-type(40**3);
    my $t1 = now;
    my int $longest-name;
    note "Starting generation of codepoint names…";
    my %control-ranges;
    for 0..$max -> $cp {
        my str $cp_s = nqp::base_I(nqp::decont($cp), 10);
        if nqp::existskey(%names, $cp_s) {
            my $s := nqp::atkey(%names, $cp_s);
            if $s.contains('<') {
                if $s.match(/ ^ '<' (.*) '>' $ /) {
                    $set-range.add-to-range: $cp_s, 'uninames', “sprintf(out, "<$0-%.4X>", cp);”, 0;
                    $base40-string.push unless $no-empty;
                }
                else {
                    die "name: $s, cp: $cp";
                }
                next;
            }
            $base40-string.push($s);
        }
        # If we have no name just push a 0
        elsif !$no-empty {
            $set-range.add-to-range: $cp_s, “sprintf(out, "<unassigned-%.4X>", cp);”, 0;
            $base40-string.push;
        }
    }
    $base40-string.done;
    say "Took " ~ now - $t1 ~ " secs to go through all codepoints";
    say "Joining codepoints";
    my $t2 = now;
    my $base40-joined = $base40-string.join(',');
    my $t3 = now;
    my $set-rang-func-h = 'uint32_t get_uninames ( char * out, uint32_t cp )';
    my $set-range-func = qq:to/END/;
    $set-rang-func-h \{
            {$set-range.generate-c("cp")}

        return 0;
    \}
    END
    say "Took " ~ now - $t3 ~ " seconds to generate set range's";
    my $names_h = ("#define uninames_elems $base40-string.elems()",
                   "#define LONGEST_NAME " ~ $seen-words.longest-name,
                   "#define HIGHEST_NAME_CP $max",
                   "$set-rang-func-h;",
                   compose-array($c-type, 'uninames', $base40-string.elems, $base40-joined, :header),
                   ).join("\n");
    my $string = join( '',
                slurp-snippets('names', 'head'),
                $names_h,
                $set-range-func,
                $base40-string.get-c-table,
                compose-array($c-type, 'uninames', $base40-string.elems, $base40-joined),
                slurp-snippets("names", "tail"),
                );
    say "Took " ~ now - $t3 ~ " seconds to the final part of name creation";
    say "NAME GEN: took " ~ now - $t0_nl ~ " seconds to go through all the name generation code";
    return $string;
}
sub DerivedNumericValues ( Str $filename ) {
    my $numerator-seen = pvalue-seen.new;
    my $denominator-seen = pvalue-seen.new;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim([';','#']);
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
        $numerator-seen.saw($numerator);
        $denominator-seen.saw($denominator);
        my %point = 'Numeric_Value_Numerator' => $numerator.Int,
            'Numeric_Value_Denominator' => $denominator.Int;
        apply-to-cp($cp, %point);
    }
    register-enum-property('Numeric_Value_Denominator', 0, $denominator-seen);
    register-enum-property('Numeric_Value_Numerator', 0, $numerator-seen);
}
sub binary-property ( Int $column, Str $filename ) {
    my %props-seen;
    my Int $i = 0;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim([';','#'], $column + 2);
        my $property = @parts[$column];
        %props-seen{$property} = True unless %props-seen{$property};
        my $range = @parts[0];
        my %point;
        %point{$property} = True;
        apply-to-cp($range, %point);
        last if $less-global and $less-global > $i;
        $i++;
    }
    register-binary-property(%props-seen.keys.sort);
}
sub enumerated-property ( Int $column, Str $negname, Str $propname, Str $filename ) {
    my $seen-value = pvalue-seen.new;
    my %points-by-range;
    my Int $i = 0;
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split-trim([';','#'], $column + 2);
        my $range = @parts[0];
        my $prop-val = @parts[$column];
        $seen-value.saw($prop-val);
        my %point = $propname => $prop-val;
        %points-by-range{$range} = %point;
    }
    my %enum = register-enum-property($propname, $negname, $seen-value);
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
        %all-properties{$name} := %binary-properties{$name};
    }
}
sub compute-bitwidth ( Int $max ) {
    $max.base(2).chars;
}
multi sub register-enum-property (Str $propname, $negname, %seen-values) {
    die "Deprecated register-enum-property called with prop: $propname";
}
# Eventually we will make a multi that can take ints
multi sub register-enum-property (Str $propname, $negname, pvalue-seen $seen-values) {
    my %enum;
    my %seen-values = $seen-values.seen-values;
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
    %all-properties{$propname} := %enumerated-properties{$propname};
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
sub PValueAlias ( Str $property, Str $file ) {
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
    my $seen-ccc = pvalue-seen.new;
    #3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;
    our $first-point-cp;
    my %First-point; # %First-point gets assigned a value if it matches as above
    # and so is the first in a range inside UnicodeData.txt
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split(';');
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = @parts;
        my $cp = :16($code-str);
        next if $less != 0 and $cp > $less;
        my %hash;
        %hash<Unicode_1_Name>            =? $u1name;
        %hash<gencat_name>               =? $gencat;
        %hash<General_Category>          =? $gencat;
        if $ccclass {
            $seen-ccc.saw($ccclass);
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
        # We may not need to set the name in the hash in case we only rely on %names;
        die if !$name;
        if $name.starts-with('<') {
            if $name.ends-with(', Last>') {
                $name ~~ s/', Last>'$/>/;
                if %First-point {
                    die "\%First-point: " ~ %First-point.gist ~ "\%hash: " ~ %hash.gist if %First-point !eqv %hash;
                    apply-to-cp("$first-point-cp..$cp", %hash);
                    say "Found Range in UnicodeData: $first-point-cp..$cp";
                    for $first-point-cp..$cp {
                        nqp::bindkey(%names, nqp::base_I(nqp::decont($_), 10), $name);
                    }
                    %First-point := {};
                    $first-point-cp = Nil;
                    next;
                }
                else {
                    die;
                }
            }
            elsif $name.ends-with(', First>') {
                $first-point-cp = $cp;
                $name ~~ s/', First>'$/>/;
                %First-point = %hash;
                next;
            }
        }
        # Bind the names hash we generate the Unicode Name C data from
        nqp::bindkey(%names, nqp::base_I(nqp::decont($cp), 10), $name);

        %hash<name>                      =? $name;
        apply-to-cp($code-str, %hash);
    }
    # For now register it as a string enum, will change when a register-enum-property multi is made
    register-enum-property("Canonical_Combining_Class", 0, $seen-ccc);
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
                    given $key2 {
                        when Int {
                            %points{$cp}{$key} = $hashy{$key};
                        }
                        when Bool {
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
sub get-full-pvalue (Str $prop is copy, Str $pvalue) {
    $prop = get-full-propname($prop);
    if %PropertyValueAliases_to{$prop}{$pvalue}:exists {
        return %PropertyValueAliases_to{$prop}{$pvalue};
    }
    else {
        note "Could not find “$pvalue” in property “$prop” in " ~
             '%PropertyValueAliases_to hash';
        if %PropertyValueAliases_to{$prop}:exists {
            note "\%PropertyValueAliases_to\{$prop\}: " ~
                Dump %PropertyValueAliases_to{$prop};
        }
        else {
            note '%PropertyValueAliases_to: ' ~ Dump %PropertyValueAliases_to;
        }
    }
    $pvalue;
}
sub get-full-propname (Str $prop) returns Str {
    state @non-official-properties =
        'Numeric_Value_Numerator', 'Numeric_Value_Denominator';
    say "Looking up full propname for $prop" if $debug-global;
    if %PropertyNameAliases_to{$prop}:exists {
        return %PropertyNameAliases_to{$prop};
    }
    elsif $prop ne @non-official-properties.any {
        note "Could not find property “$prop” in " ~
             '%PropertyValueAliases_to hash';
    }
    $prop;
}
sub make-enums {
    note "Making enums…";
    my @enums;
    say Dump %enumerated-properties if $debug-global;
    for %enumerated-properties.keys.sort -> $prop {
        my $full-prop-name = get-full-propname($prop);
        say "make-enums prop[$prop] fullname [$full-prop-name]";
        my str $enum-str;
        my @enum-str;
        my $type = %enumerated-properties{$prop}<type>;
        my $rev-hash = reverse-hash-int-only(%enumerated-properties{$prop});

        say $rev-hash if $debug-global;
        if $type eq 'Str' {
            for $rev-hash.keys.sort(+*) {
                my $pvalue = $rev-hash{$_};
                my $full-pvalue = get-full-pvalue($prop, $pvalue);
                @enum-str.push($full-pvalue);
            }
            $enum-str = compose-array compute-type('char *'), $prop, @enum-str;
        }
        elsif $type eq 'Int' {
            my Int $min = +$rev-hash.values.min(+*);
            my Int $max = +$rev-hash.values.max(+*);
            say "Min $min, Max $max";
            for $rev-hash.keys.sort(+*) {
                @enum-str.push($rev-hash{$_});
            }
            say Dump $rev-hash if $debug-global;
            $enum-str = compose-array compute-type($max, $min), $prop, @enum-str;
        }
        else {
            die "Don't know how to make an enum of type '$type'";
        }
        # Create the #define's for the Property Value's
        @bitfield-h.push("/* $prop */");
        for $rev-hash.sort(+*.key) {
            my ($enum-no, $prop-val) = (.key, .value);
            my $prop-val-name = $prop-val.subst('-', 'negative_');
            @bitfield-h.push("#define Uni_PVal_{$prop.uc}_$prop-val-name $enum-no");
        }
        @enums.push($enum-str);
    }
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
    # XXX can use .split-into-lines here
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
    @bitfield-h.push("struct binary_prop_bitfield  \{");
    my $bin-prop-nqp := nqp::hash;
    for %binary-properties.keys.sort -> $bin {
        %prop-to-code{$bin} = $i;
        %code-to-prop{$i} = $bin;
        $i++;
        @bitfield-h.push("    unsigned int $bin :1;");
        nqp::bindkey($bin-prop-nqp, $bin, '1');
    }
    my $enum-prop-nqp := nqp::hash;
    for %enumerated-properties.keys.sort({%enumerated-properties{$^a}<bitwidth> cmp %enumerated-properties{$^b}<bitwidth>}) -> $property {
        %prop-to-code{$property} = $i;
        %code-to-prop{$i} = $property;
        $i++;
        my $bitwidth = %enumerated-properties{$property}<bitwidth>;
        @bitfield-h.push("    unsigned int $property :$bitwidth;");
        my $this-prop := nqp::hash;
        for %enumerated-properties{$property}.kv -> $key, $value {
            next if $key eq any('name', 'bitwidth');
            my str $key_s = $key;
            my str $value_s;
            if nqp::istype($value, Int) {
                $value_s = nqp::base_I(nqp::decont($value), 10);
            }
            elsif nqp::istype($value, Str) {
                $value_s = nqp::unbox_s($value);
            }
            elsif nqp::istype($value, str) {
                $value_s = $value;
            }
            nqp::bindkey($this-prop, $key_s, $value_s);
        }
        nqp::bindkey($enum-prop-nqp, $property, $this-prop);

    }
    say $enum-prop-nqp;
    say $enum-prop-nqp<Canonical_Combining_Class><0>.WHAT;
    @bitfield-h.push("\};");
    @bitfield-h.push("typedef struct binary_prop_bitfield binary_prop_bitfield;");
    my $bitfield-rows := nqp::list_s;
    my %bitfield-rows-seen = nqp::hash;
    my @code-to-prop-keys = %code-to-prop.keys.sort(+*);
    say @code-to-prop-keys.VAR.name ~ Dump @code-to-prop-keys;
    my @code-sorted-props = %prop-to-code.sort(+*.value).».key;
    # double check it is as as it should be
    for ^@code-sorted-props -> $elem {
        my $p = %code-to-prop{$elem};
        say "elem $elem, p $p";
        die %code-to-prop.VAR.name ~ Dump %code-to-prop if %code-to-prop{$elem} ne @code-sorted-props[$elem];
        die if %prop-to-code{$p} != $elem;
    }

    my $t1 = now;
    for %points.keys.sort(+*) -> $point {
        my $bitfield-columns := nqp::list_s;
        my $points-point := nqp::atkey(%points, $point);
        for @code-sorted-props -> $prop {
            if $points-point{$prop}:exists {
                nqp::if( nqp::existskey($bin-prop-nqp, $prop), (
                    nqp::push_s($bitfield-columns,
                        nqp::if($points-point{$prop}, '1', '0')
                    );
                ), (nqp::if(nqp::existskey($enum-prop-nqp, $prop), (
                        my $enum := nqp::base_I(nqp::decont($points-point{$prop}), 10);
                        # If the key exists we need to look up the value
                        my $enum-prop-nqp-prop := nqp::atkey($enum-prop-nqp, $prop);
                        # If it doesn't exist we already have the property code.
                        # Eventually we may want to try and have it so all things
                        # either have or don't have the property for consistency
                        # XXX
                        nqp::if( nqp::existskey($enum-prop-nqp-prop, $enum), (
                            nqp::push_s($bitfield-columns, nqp::atkey($enum-prop-nqp-prop, $enum));
                        ), (
                            nqp::push_s($bitfield-columns, $enum);
                           )
                        );
                    ), (nqp::die('oh no') )
                    ),
                    )
                );
            }
            else {
                nqp::push_s($bitfield-columns, '0');
            }
        }
        my $bitfield-rows-str := nqp::join(',', $bitfield-columns);
        # If we've already seen an identical row
        nqp::if(nqp::existskey(%bitfield-rows-seen, $bitfield-rows-str), (
            nqp::bindkey(%point-index, $point, nqp::atkey(%bitfield-rows-seen, $bitfield-rows-str))
        ),
        (
            my $bin-index_s := nqp::base_I(++$bin-index, 10);
            # Bind it to the bitfield rows hash
            nqp::bindkey(%bitfield-rows-seen, $bitfield-rows-str, $bin-index_s);
            # Bind the point index so we know where in the bitfield this point is located
            nqp::bindkey(%point-index, $point, $bin-index_s);
        )
        );

    }
    my $t2 = now;
    say "Finished computing all rows, took {now - $t1}. Now creating the final unduplicated version.";
    for %bitfield-rows-seen.sort(+*.value).».kv -> ($row-str, $index) {
        nqp::push_s($bitfield-rows, '    {' ~ $row-str ~ "\},/* index $index */");
    }
    $binary-struct-str = nqp::join("\n", $bitfield-rows);
    my @array;
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
        write-file(%points.VAR.name ~ '.json',  to-json(%points));
        write-file(%decomp_spec.VAR.name ~ '.json',  to-json(%decomp_spec));
    }
    for %enumerated-properties, %binary-properties, %PropertyValueAliases,
       %PropertyNameAliases, %PropertyNameAliases_to, %PropertyValueAliases_to {
        write-file(.VAR.name ~ '.json', to-json($_));
    }
}
