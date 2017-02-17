#!/usr/bin/env perl6
use experimental :macros, :collation;
use nqp;
use JSON::Fast;
use Data::Dump;
use Terminal::ANSIColor;
use lib 'lib';
use UCDlib; use ArrayCompose; use Set-Range;
use seenwords; use EncodeBase40;
use BitfieldPacking; use bitfield-rows-switch;
constant $build-folder = "source";
constant $snippets-folder = "snippets";
constant $myindent = ' ' x 4;
# stores lines of bitfield.h
our @bitfield-h;
sub timer (Str $name = '') {
    state %timers;
    push %timers{$name}, now;
    if %timers{$name}.elems > 1 {
        say "TIMER $name {%timers{$name}[*-1] - %timers{$name}[*-2]} seconds";
    }
}
macro dump($x) { quasi { say {{{$x}}}.VAR.name, ": ", Dump {{{$x}}} } };
my %points = nqp::hash;
my %names = nqp::hash;
=head2 C<%names>
=para Unicode Name hash for generating the name table

my %binary-properties;
=head2 C<%binary-properties>
=para Stores the binary property names

my %enumerated-properties;
=head2 C<%enumerated-properties>
=para Stores enum prop names and also the property
codes which are just internal numbers to represent it in the C datastructure

my %decomp_spec;
=head2 C<%decomp_spec>
=para Stores the decomposition data for decomposition

my %PropertyValueAliases;
my %PropertyValueAliases_to;
=head2 C<%PropertyValueAliases %PropertyValueAliases_to>
=para Stores PropertyValueAliases from PropertyValueAliases.txt
Used to go from short names that may be used in the data files to the full names

my %PropertyNameAliases;
my %PropertyNameAliases_to;
=head2 C<%PropertyNameAliases %PropertyNameAliases_to>
=para Stores Property Aliases or Property Value Aliases to their Full Name mappings

my %missing;
constant $missing-str = '# @missing';
constant @gc = 'General_Category_1', 'General_Category_2';
my %point-index = nqp::hash;
my $debug-global = False;
my int $bin-index = -1;
sub MAIN ( Bool:D :$dump = False, Bool:D :$nomake = False, Int:D :$less = 0,
           Bool:D :$debug = False, Bool:D :$names-only = False, Bool:D :$no-UnicodeData = False,
           Bool:D :$no-names = False, Str :$only? ) {
    my @only = $only ?? $only.split( [',', ' '] ) !! Empty;
    $debug-global = $debug;
    start-routine();
    PNameAliases("PropertyAliases", %PropertyNameAliases, %PropertyNameAliases_to);
    PValueAliases("PropertyValueAliases", %PropertyValueAliases, %PropertyValueAliases_to);
    timer('UnicodeData');
    UnicodeData("UnicodeData", $less, $no-UnicodeData);
    die Dump %points unless %points{0}:exists;
    timer('UnicodeData');
    my str @sorted-cp;
    unless $names-only {
        constant @enum-data =
            (1, 'N', 'East_Asian_Width', 'extracted/DerivedEastAsianWidth'),
            (1, 'None', 'Numeric_Type', 'extracted/DerivedNumericType'),
            (1, 'Other', 'Grapheme_Cluster_Break', 'auxiliary/GraphemeBreakProperty'),
            (1, '', 'Jamo_Short_Name', 'Jamo'),
            (1, 'L', 'Bidi_Class', 'extracted/DerivedBidiClass'),
            (1, 'No_Joining_Group', 'Joining_Group', 'extracted/DerivedJoiningGroup'),
            (1, 'Non_Joining', 'Joining_Type', 'extracted/DerivedJoiningType'),
            (1, 'Other', 'Word_Break', 'auxiliary/WordBreakProperty'),
            (1, 'XX', 'Line_Break', 'LineBreak');
        constant @bin-data =
            (1, 'extracted/DerivedBinaryProperties'),
            (1, 'PropList'),
            (1, 'emoji/emoji-data'),
            (1, 'DerivedCoreProperties'),
            (1, "DerivedNormalizationProps");
        if $less and !@only {
            #my $head = $less ?? 1 !! Inf;
            enumerated-property(|@enum-data[0]);
            binary-property(|@bin-data[0]);
        }
        elsif @only {
            for @only -> $prop {
                if @enum-data.first({ $_[2] eq $prop }) {
                    enumerated-property( |@enum-data.first({ $_[2] eq $prop }) )
                }
                elsif @bin-data.first({ $_[1] eq $prop }) {
                    binary-property(|@bin-data.first({ $_[1] }))
                }
                elsif $prop ne 'Numeric_Values' {
                    die "Can't find property '$prop'";
                }
            }
            DerivedNumericValues('extracted/DerivedNumericValues') if @only.any eq 'Numeric_Values';
        }
        else {
            enumerated-property( |$_ ) for @enum-data;
            binary-property( |$_ ) for @bin-data;
            DerivedNumericValues('extracted/DerivedNumericValues');
        }
        @sorted-cp = done-editing-points();
        tweak_nfg_qc(@sorted-cp) unless $less;
        say now - INIT now;
    }
    unless $nomake {
        my $int-main;
        $int-main =  %enumerated-properties{'Numeric_Value_Numerator'}:exists
        ?? slurp-snippets("bitfield", "int-main")
        !! slurp-snippets("bitfield", "int-main", -3);
        unless $names-only {
            my $bitfield_c = [~] “#include "bitfield.h"\n”,
                make-enums(), make-bitfield-rows(@sorted-cp), make-point-index(@sorted-cp),
                slurp-snippets("bitfield", "test"), $int-main;
            note "Saving bitfield.c…";
            write-file('bitfield.c', $bitfield_c);
            @bitfield-h.unshift: slurp-snippets("bitfield", "header", 0);
            @bitfield-h.push: slurp-snippets("bitfield", "header", 1);
            write-file('bitfield.h', @bitfield-h.join("\n"));
        }
        write-file('names.c', Generate_Name_List()) unless $no-UnicodeData or $no-names;
    }
    say "Took {now - INIT now} seconds.";
    dump-json($dump) unless $dump;
}
sub missing (Str $line is copy) {
    # @missing: 0000..10FFFF; cjkAccountingNumeric; NaN
    die unless $line.starts-with($missing-str);
    $line ~~ s/$missing-str': '//;
    my @parts = $line.split(';')».trim;
    %missing{@parts[1]} = @parts[2];
}
sub PValueAliases (Str $filename, %aliases, %aliases_to?) {
    for slurp-lines($filename) -> $line {
        next if skip-line($line);
        my @parts = $line.split(';')».trim;
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
sub done-editing-points {
    timer 'sorting cp';
    my str @sorted = %points.keys.sort(*.Int);
    timer 'sorting cp';
    @sorted
}
class pvalue-seen {
    has %.seen-values;
    has $.negname;
    has $!type;
    has $!c-type;
    has %.enum;
    has $!bitwidth;
    method type {
        $!type = $!negname.WHAT.^name;
        $!type;
    }
    method c-type {
        if self.name eq any(@gc) {
            $!c-type = compute-type('char');
        }
        if self.type eq 'Str' {
            $!c-type = compute-type(%!enum.keys.all.chars <= 1 ?? 'char' !! 'char *');
        }
        elsif self.type eq 'Int' {
            $!c-type = compute-type(%!seen-values.elems);
        }
        $!c-type;
    }
    method bitwidth {
        $!bitwidth = compute-bitwidth(%!seen-values.elems);
        $!bitwidth;
    }
    method bin-seen-keys {
        %!seen-values.sort(&[unicmp]).keys;
    }
    method saw ($saw) {
        %!seen-values{$saw} = True unless %!seen-values{$saw}:exists;
    }
    method build {
        if %!enum.elems != %!seen-values.elems {
            $!type = $!negname.WHAT.^name;
            # Start the enum values at 0
            my $number = 0;
            # Our false name we got should be number 0, and will be different depending
            # on the category.
            if $!type eq 'Str' {
                %!enum{$!negname} = ($number++).Str;
                %!seen-values{$!negname}:delete;
                for %!seen-values.keys.sort(&[unicmp]) {
                    %!enum{$_} = ($number++).Str;
                }
            }
            elsif $!type eq 'Int' {
                for %!seen-values.keys.sort(*.Int) {
                    %!enum{$_} = ($number++).Str;
                }
            }
            else {
                die "Don't know how to register enum property of type '{$!negname.WHAT.^name}'";
            }
        }
        %!enum;
    }
}
sub PNameAliases (Str $filename, %aliases, %aliases_to?) {
    for slurp-lines($filename) -> $line {
        next if skip-line($line);
        my @parts = $line.split(';')».trim;
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
sub write-file ( Str $filename is copy, Str $text ) {
    $filename ~~ s/ ^ \W //;
    my $file = "$build-folder/$filename";
    if $text {
        note $BOLD, "Writing ", $BLUE, $file, $RESET, "…";
        $file.IO.spurt($text);
    }
}
sub start-routine {
    if !$build-folder.IO.d {
        say "Creating $build-folder because it does not already exist.";
        mkdir $build-folder;
    }
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
            my str $cp_s = base10_I(nqp::decont($cp));
            if nqp::existskey(%names, $cp_s) {
                my $s := nqp::atkey(%names, $cp_s);
                next if $s.contains('<');
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
    my $base40-nl-joined = $base40-string.join("\n");
    spurt "base40-nl.txt", $base40-nl-joined;
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
    constant @property-names = 'Numeric_Value_Numerator', 'Numeric_Value_Denominator';
    my $numerator-seen = get-pvalue-seen('Numeric_Value_Numerator', 0);
    my $denominator-seen = get-pvalue-seen('Numeric_Value_Denominator', 0);
    for slurp-lines($filename) {
        next if skip-line($_);
        my @parts = .split([';','#'])».trim;
        my $cp = @parts[0];
        my ($numerator, $denominator) = @parts[3].split('/');
        $denominator = $denominator // 1;
        $numerator-seen.saw($numerator);
        $denominator-seen.saw($denominator);
        apply-pv-to-range($cp, 'Numeric_Value_Numerator', $numerator.Int.Str);
        apply-pv-to-range($cp, 'Numeric_Value_Denominator', $denominator.Int.Str);
    }
}
sub binary-property ( Int $column, Str $filename ) {
    my $t1 = now;
    my %props-seen = nqp::hash;
    nqp::bindkey(%props-seen,
        apply-pv-to-range(
         |.split([';','#'], 3).head(2)».trim,
        # Range, # Property Name
          True       # Property Value
        ), True) unless skip-line($_)
        for slurp-lines $filename;
    say "Took {now - $t1} seconds to process $filename binary prop";
    register-binary-property(%props-seen.keys.sort(&[unicmp]));
}
sub get-pvalue-seen (Str $property, $negname) {
    if %enumerated-properties{$property}:exists {
        return %enumerated-properties{$property};
    }
    else {
        %enumerated-properties{$property} = pvalue-seen.new(negname => $negname);
        return %enumerated-properties{$property};
    }
}
multi sub enumerated-property ( 1, $negname, Str $propname, Str $filename ) {
    my %seen-value = nqp::hash;
    die $propname unless %PropertyValueAliases{$propname}:exists;
    my Int $i = 0;
    my $t1 = now;
    for slurp-lines($filename) {
        bindkey(%seen-value,
            apply-pv-to-range_enum(
                |.split([';','#'], 3).head(2)».trim,
                $propname
            ),
            $propname
        ) unless skip-line($_);
    }
    set-pvalue-seen($propname, $negname, %seen-value);
    say "Took {now - $t1} seconds to process $propname enums";
}
sub register-binary-property (+@names) {
    for @names -> $name {
        die "\@names: " ~ Dump @names ~ "  \$name[$name] doesn't !~~ Str " if $name !~~ Str;
        note "Registering binary property $name" if $debug-global;
        if %binary-properties{$name}:exists {
            note "Tried to add $name but binary property already exists";
        }
        %binary-properties{$name} = name => $name, bitwidth => 1;
    }
    note "Registering binary properties: @names.join(', ')";
}
sub compute-bitwidth ( Int $max ) { ($max - 1).base(2).chars }
sub tweak_nfg_qc (@sorted-cp) {
    note "Tweaking NFG_QC…";
    timer('tweak_nfg_qc');
    # See http://www.unicode.org/reports/tr29/tr29-27.html#Grapheme_Cluster_Boundary_Rules
    # \r
    my @nfg_qc_no =
        0x0D, # \r
        0x0E33, 0x0EB3; # some specials
    ;
    %points{$_}<NFG_QC> = False if %points{$_}:exists for @nfg_qc_no;
    for @sorted-cp -> $code {
        # SpacingMark, and a couple of specials
        if (%points{$code}<General_Category>:exists and %points{$code}<General_Category> eq 'Mc')
        {
            %points{$code}<NFG_QC> = False;
        }
        # For now set all Emoji to NFG_QC 0
        # Eventually we will only want to set the ones that are NOT specified
        # as ZWJ sequences
        for <Grapheme_Cluster_Break Emoji Hangul_Syllable_Type> -> $prop {
            %points{$code}<NFG_QC>= False if %points{$code}{$prop};
        }
    }
    timer('tweak_nfg_qc');
}
sub PValueAlias ( Str $property, Str $file ) {
    for slurp-lines $file {
        next if skip-line($_);
        my @parts = .split(';')».trim;
        my %hash;
        %hash{$property}{@parts[1]}<type> = @parts[2];
        apply-hash-to-range(@parts[0], %hash)
    }
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
sub UnicodeData ( Str $file, Int $less = 0, Bool $no-UnicodeData = False ) {
    my %seen-ccc = nqp::hash;
    my %seen-gc = nqp::hash;
    #3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;
    our $first-point-cp;
    my %First-point; # %First-point gets assigned a value if it matches as above
    # and so is the first in a range inside UnicodeData.txt
    my $t1 = now;
    for slurp-lines $file {
        next if skip-line($_);
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = nqp::split(';', $_);
        my $cp = hex $code-str;
        next if $less != 0 and $cp > $less;
        next if $no-UnicodeData and $cp > 100;
        my %hash = nqp::hash;
        if $gencat {
            bindkey(%hash, @gc[0], nqp::substr($gencat, 0, 1));
            bindkey(%hash, @gc[1], nqp::substr($gencat, 1, 1));
            bindkey(%hash, 'General_Category', $gencat);
            bindkey(%seen-gc, $gencat, True);
        }
        if str-isn't-empty($ccclass) {
            bindkey(%seen-ccc, $ccclass, True);
            bindkey(%hash, 'Canonical_Combining_Class', $ccclass);
        }
        bindkey(%hash, 'Unicode_1_Name', $u1name) if  str-isn't-empty($u1name);
        bindkey(%hash, 'Bidi_Class', $bidiclass) if str-isn't-empty($u1name);
        bindkey(%hash, 'suc', hex $suc) if str-isn't-empty($suc);
        bindkey(%hash, 'slc', hex $slc) if str-isn't-empty($slc);
        bindkey(%hash, 'stc', hex $stc) if str-isn't-empty($stc);
        # We may not need to set the name in the hash in case we only rely on %names
        bindkey(%hash, 'name', $name) if str-isn't-empty($name);

        #`( These eventually should eventually be flipped but for now don't
            set NFD_QC NFC_QC, NFG_QC, NFKD_QC or NFG_QC here at least #`)
        bindkey(%hash, 'Any', True);
        bindkey(%hash, 'Bidi_Mirrored', True) if starts-with($bidimirrored, 'Y');

        if str-isn't-empty($decmpspec) {
            my @dec = nqp::split(' ', $decmpspec);
            %decomp_spec{$cp}<type> =
                starts-with(@dec[0], '<') ?? @dec.shift !! 'Canonical';
            %decomp_spec{$cp}<mapping> = @dec.map( { hex $_ } )
        }
        if starts-with($name, '<') {
            if $name.ends-with(', Last>') {
                if %First-point {
                    # This function can work on ranges
                    for $first-point-cp..$cp {
                        # We need to duplicate the hash so each cp hash is a new hash
                        # otherwise when we write to one cp's value later, it will
                        # end up changing multiple cp's
                        apply-hash-to-cp($_, my %new-hash = %hash);
                        bindkey(%names, base10_I_decont($_), $name);
                    }
                    %First-point    = nqp::hash;
                    $first-point-cp = Nil;
                    next;
                }
                else { die }
            }
            elsif $name.ends-with(', First>') {
                %First-point = %hash;
                $first-point-cp = $cp;
                next;
            }
        }
        apply-hash-to-cp($cp, %hash);
        # This only does single points so we use it to improve speed
        # Bind the names hash we generate the Unicode Name C data from
        bindkey(%names, base10_I_decont($cp), $name);
    }
    my $time-took = now - $t1;
    announce 'process', 'UnicodeData', $time-took;
    my $gc_0-seen = get-pvalue-seen(@gc[0], '');
    my $gc_1-seen = get-pvalue-seen(@gc[1], '');
    for %seen-gc.keys {
        my @letters = .comb;
        $gc_0-seen.saw(@letters[0]);
        $gc_1-seen.saw(@letters[1]);
    }
    register-binary-property(<Any Bidi_Mirrored>);
    set-pvalue-seen("Canonical_Combining_Class", 0, %seen-ccc);
}
sub set-pvalue-seen (Str:D $property, $negname, %hash) {
    my $pvalue-seen = get-pvalue-seen($property, $negname);
    for %hash.keys {
        $pvalue-seen.saw($_);
    }
}
sub apply-hash-to-range (Str $range-str, Hash $hashy) {
    # If it contains `..` then it is a range
    my @items = $range-str.split('..').map( { hex $_ } );
    if @items.elems == 2 {
        for Range.new( @items[0], @items[1] ) -> $cp {
            my $new-hashy = $hashy;
            apply-hash-to-cp($cp, $new-hashy);
        }
    }
    # Otherwise there's only one point
    elsif @items.elems == 1 {
        apply-hash-to-cp(@items[0], $hashy);
    }
    else {
        die "Unknown range '$range-str'";
    }
}
sub apply-pv-to-range_enum ($range-str, $value, Str $pname) is raw {
    # If it contains `..` then it is a range
    apply-pv-to-range2( |$range-str.split('..').map( { hex $_ } ),
        $pname, $value
    );
    return $value;
}
sub apply-pv-to-range ($range-str, Str $pname, $value) is raw {
    # If it contains `..` then it is a range
    apply-pv-to-range2( |$range-str.split('..').map( { hex $_ } ),
        $pname, $value
    );
    return $pname;
}
multi sub apply-pv-to-range2 (Int $first, Int $second, Str $pname, $value) is raw {
    apply-pv-to-cp($_, $pname, $value) for $first..$second;
}
multi sub apply-pv-to-range2 (Int $first, Str $pname, $value) is raw {
    apply-pv-to-cp($first, $pname, $value);
}
sub apply-pv-to-cp (int $cp, Str $pname, $value) is raw {
    my \cp_s := base10_I($cp);
    if !existskey(%points, cp_s) {
        bindkey(%points, cp_s, nqp::hash);
    }
    elsif nqp::existskey(nqp::decont(nqp::atkey(%points, cp_s)), $pname) {
        return if %points{cp_s}{$pname} eqv $value;
        my $var = %points{cp_s}{$pname};
        die "Pname $pname for cp {$cp.base(16)} already exists: '$var' ",
            "Tried to replace with $value ", Dump %points{cp_s};
        %points{cp_s}{$pname}:delete;
    }
    nqp::bindkey(
        nqp::decont(
            nqp::atkey(%points, cp_s
            )
        ), $pname, $value
    );
}
sub apply-hash-to-cp (Int $cp, Hash $hashy) is raw {
    my str $cp_s = base10_I($cp);
    existskey(%points, $cp_s)
    # Full path in case there's already an existing key
    ?? apply-hash-to-cp-full($cp, $hashy)
    # Fast path in case cp doesn't exist yet
    !! bindkey(%points, $cp_s, $hashy);
}
sub apply-hash-to-cp-full (Int $cp, Hash $hashy) {
    # Otherwise we need to go through all the keys and apply them all
    for $hashy.keys -> $key {
        if %points{$cp}{$key}:!exists {
            %points{$cp}{$key} = $hashy{$key};
        }
        else {
            for $hashy{$key}.keys -> $key2 {
                if $key2 ~~ Int or $key2 ~~ Bool {
                    %points{$cp}{$key}:delete;
                    %points{$cp}{$key} = $hashy{$key};
                }
                else {
                    die "Don't know how to apply type {$key2.WHAT} in apply-hash-to-cp";
                }
            }
        }
    }
}
constant @non-official-properties =
    'Numeric_Value_Numerator', 'Numeric_Value_Denominator',
    'General_Category_1', 'General_Category_2';
sub get-full-pvalue (Str $prop is copy, Str $pvalue) {
    $prop = get-full-propname($prop);
    if %PropertyValueAliases_to{$prop}{$pvalue}:exists {
        return %PropertyValueAliases_to{$prop}{$pvalue};
    }
    else {
        if $prop ne @non-official-properties.any and
        # Names without Jamo_Short_Name have no value
        !($prop eq 'Jamo_Short_Name' and $pvalue eq '') {
            warn "Could not find “$pvalue” in property “$prop” in " ~
                '%PropertyValueAliases_to hash';
            note "\%PropertyValueAliases_to\{$prop\}: " ~
                Dump %PropertyValueAliases_to{$prop}
                if %PropertyValueAliases_to{$prop}:exists;
        }
    }
    $pvalue;
}
sub get-full-propname (Str $prop) returns Str {
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
    for %enumerated-properties.keys.sort(&[unicmp]) -> $prop {
        my $obj = %enumerated-properties{$prop};
        my $full-prop-name = get-full-propname($prop);
        say "make-enums prop[$prop] fullname [$full-prop-name]" if $debug-global;
        die if $prop ne $full-prop-name;
        my $type = $obj.type;
        my %enum = $obj.build;
        my @enum-str;
        my $c-type;
        if $type eq 'Str' {
            $c-type = %enum.keys.all.chars <= 1 ?? 'char' !! 'char *';
        }
        elsif $type eq 'Int' {
            my $int-keys = %enum.keys.».Int;
            $c-type = compute-type($int-keys.max, $int-keys.min);
            say "Min, Max: ", $int-keys.min, ' ', $int-keys.max if $debug-global;
        }
        else {
            die "Don't know how to make an enum of type '$type'";
        }
        for %enum.sort(*.value.Int) {
            my $pvalue = $type eq 'Int' ?? .key !! get-full-pvalue($prop, .key);
            @enum-str.push($pvalue);
        }
        # Create the #define's for the Property Value's
        @bitfield-h.push("/* $prop */");
        for %enum.sort(*.value.Int) {
            my ($enum-no, $prop-val) = (.value, .key);
            my $prop-val-name = $prop-val.subst('-', 'negative_');
            @bitfield-h.push("#define Uni_PVal_{$prop.uc}_$prop-val-name $enum-no");
        }
        @enums.push(compose-array $c-type, $prop, @enum-str);
    }
    @enums.join("\n");
}
sub make-point-index (@sorted-cp, :$less) {
    note $BOLD, "Making ", $BLUE, "point_index", $RESET, "…";
    my $t0 = now;
    my @points-ranges = get-points-ranges-array(%point-index);
    say "Took ", $BOLD, now - $t0, $RESET, " seconds to compute point_index ranges";
    my $dump-count = 0;
    my Int $point-max = @sorted-cp.tail.Int;
    my Str $type = compute-type($bin-index + 1);
    my $t1 = now;
    my Cool:D @mapping;
    my $min-elems = 10;
    @bitfield-h.push: '#define BITFIELD_DEFAULT 0';
    my str @range-str2;
    my $indent = '';
    my $tabstop = ' ';
    my @debug_out;
    my $i = 0;
    for ^(0xA47 + 1000) {
        quietly @debug_out.push: $_ ~ ' => ' ~ %point-index{$_};
    }
    spurt 'mapping.txt', @debug_out.join("\n");
    my $struct = Q:to/END/;

    struct table  {
        uint32_t low;
        uint32_t high;
        uint32_t bitfield_row;
        uint32_t miss;
    };
    typedef struct table table;
    END
    for ^@points-ranges.elems {
        my ($range-no, $range) = ($_, @points-ranges[$_]);
        my $high = $range.tail;
        my $low = $range[0];
        my $bitfield_row;
        if %point-index{$range[0]}:exists {
            $bitfield_row = %point-index{$range[0]};
            if $range.elems > $min-elems {
                @range-str2.push: '{' ~ ($low, $high, $bitfield_row, $high - @mapping.elems).join(',') ~ '}';
            }
            else {
                for ^$range.elems {
                    @mapping.push: %point-index{ $range[$_] };
                }
            }
        }
        else {
            $bitfield_row = 'BITFIELD_DEFAULT';
            if $range.elems > $min-elems {
                @range-str2.push: '{' ~ ($low, $high,  $bitfield_row, $high - @mapping.elems).join(',') ~ '}';
            }
            else {
                for ^$range.elems {
                    @mapping.push('BITFIELD_DEFAULT')
                }
            }
        }
    }
    say "Took this long to concat points: ", now - $t1;
    my $mapping-str = ( "#define max_bitfield_index $point-max\n$type point_index[",
        @mapping.elems, "] = \{\n    ",
        @mapping.join(',').break-into-lines(','), "\n\};\n"
        ).join;
    return [~] $mapping-str, $struct,
               compose-array( $prefix ~ 'table', 'sorted_table', @range-str2 ),
               slurp-snippets('bitfield', 'get_offset_new');
}
sub dedupe-rows (@sorted-cp, @code-sorted-props, Mu $enum-prop-nqp, Mu $bin-prop-nqp) is raw {
    my ($enum, $enum-prop-nqp-prop);
    my \bitfield-columns := nqp::list_s;
    my \points-point := 0;
    my str $bitfield-rows-str;
    my %bitfield-rows-seen = nqp::hash;
    nqp::bind($enum-prop-nqp, nqp::decont($enum-prop-nqp));
    nqp::bind($bin-prop-nqp, nqp::decont($bin-prop-nqp));
    my $orig-props-iter := nqp::getattr(@code-sorted-props,List,'$!reified');
    my ($props-iter, $prop);
    # Add a default bitfield row, which is used by any cp we don't know the props
    # of. This will cause it to generate a default 0th bitfield row
    @sorted-cp.unshift('-1');
    %points{-1} = nqp::hash;
    for @sorted-cp -> $point {
        nqp::bind(bitfield-columns, nqp::list_s);
        nqp::bind(points-point, nqp::decont(nqp::atkey(%points, $point)));
        nqp::bind($props-iter, nqp::clone($orig-props-iter));
        while nqp::elems($props-iter) {
            nqp::bind($prop, nqp::shift($props-iter));
            nqp::if( nqp::existskey(points-point, $prop), (
                nqp::if( nqp::existskey($bin-prop-nqp, $prop), (
                    nqp::push_s(bitfield-columns,
                        nqp::if(nqp::atkey(points-point, $prop), '1', '0')
                    );
                ), (nqp::if(nqp::existskey($enum-prop-nqp, $prop), (
                      nqp::stmts(
                        nqp::bind($enum-prop-nqp-prop, nqp::atkey($enum-prop-nqp, $prop)),
                        # If the key exists we need to look up the value
                        nqp::bind($enum, nqp::atkey(points-point, $prop)),
                        # If it doesn't exist we already have the property code.
                        # Eventually we may want to try and have it so all things
                        # either have or don't have the property for consistency
                        # XXX
                        nqp::if( nqp::existskey($enum-prop-nqp-prop, $enum), (
                            nqp::push_s(bitfield-columns, nqp::atkey($enum-prop-nqp-prop, $enum));
                        ), (
                            nqp::push_s(bitfield-columns, $enum);
                           )
                        )
                      )
                    ), (nqp::die('oh no') )
                    ),
                    )
                );
              ),
            #else {
                nqp::push_s(bitfield-columns, '0')
            )
            #}
        }
        $bitfield-rows-str = nqp::join(',', bitfield-columns);
        # If we've already seen an identical row
        nqp::if(nqp::existskey(%bitfield-rows-seen, $bitfield-rows-str), (
            nqp::bindkey(%point-index, $point, nqp::atkey(%bitfield-rows-seen, $bitfield-rows-str))
        ),
        (
            my $bin-index_s := base10_I(++$bin-index);
            # Bind it to the bitfield rows hash
            nqp::bindkey(%bitfield-rows-seen, $bitfield-rows-str, $bin-index_s);
            # Bind the point index so we know where in the bitfield this point is located
            nqp::bindkey(%point-index, $point, $bin-index_s);
        )
        );

    }
    # Remove the default since it's not actually a cp
    @sorted-cp.shift;
    %points{-1}:delete;
    return %bitfield-rows-seen;
}
#| Makes the C functions which go from a property code into a value
#| get_prop_int returns an prop's raw int, get_prop_str returns a char * from
#| an enum. get_prop_enum gets an integer value from an enum
sub make-property-switches (@code-sorted-props) {
    my @switch-enum = $prefix ~ 'int get_prop_enum (uint32_t cp, int propcode) {';
    my @switch      = $prefix ~ 'int get_prop_int (uint32_t cp, int propcode) {';
    my @switch-enum-str = $prefix ~ 'char * get_prop_str (uint32_t cp, int propcode) {';
    (@switch, @switch-enum, @switch-enum-str)».push: $myindent ~ 'switch (propcode) {';
    for ^@code-sorted-props.elems {
        my $prop = @code-sorted-props[$_];
        my $def =  "Uni_Propcode_$prop";
        @bitfield-h.push: "#define $def $_";
        if %enumerated-properties{$prop}:exists {
            if %enumerated-properties{$prop}.type eq 'Int' {
                @switch-enum.append: $myindent x 2 ~ " case $def:",
                $myindent x 3 ~ "return get_enum_prop(cp, $prop);";
            }
            elsif $prop eq any(@gc) {

            }
            elsif %enumerated-properties{$prop}.type eq 'Str' {
                @switch-enum-str.append: $myindent x 2 ~ " case $def:",
                    $myindent x 3 ~ "return get_enum_prop(cp, $prop);";
            }
            else {
                die $prop, %enumerated-properties{$prop}.type
            }
        }
        @switch.append: $myindent x 2 ~ " case $def:",
            $myindent x 3 ~ "return get_cp_raw_value(cp, $prop);";
    }
    (@switch, @switch-enum, @switch-enum-str)».append: $myindent ~ '}', '}';

    return @switch.join("\n"), @switch-enum.join("\n"), @switch-enum-str.join("\n");
}
sub make-bitfield-rows ( @sorted-cp ) {
    note "Making bitfield-rows…";
    my @code-sorted-props;
    my $code-sorted-props := nqp::list_s;
    # Create the order of the struct
    @bitfield-h.push("struct binary_prop_bitfield  \{");
    my $bin-prop-nqp := nqp::hash;
    #| Stores an array of Pairs where the key is the property name and the
    #| value is the bitwidth. It then passes it off to BitfieldPacking module
    my @list-for-packing;
    for %binary-properties.keys.sort(&[unicmp]) -> $bin {
        @list-for-packing.push($bin => 1);
    }
    my $enum-prop-nqp := nqp::hash;
    for %enumerated-properties.sort({ $^a.key unicmp $^b.key }) {
        @list-for-packing.push(.key => .value.bitwidth);
    }
    my @packed-enums = compute-packing(@list-for-packing);
    say $BOLD, "Packed-enums: ", $BOLD_OFF, @packed-enums.perl;
    for @packed-enums.».key -> $property {
        my $bitwidth;
        if %enumerated-properties{$property}:exists {
            $bitwidth = %enumerated-properties{$property}.bitwidth;
            my $this-prop := nqp::hash;
            my $built = %enumerated-properties{$property}.build;
            for $built.kv -> $key, $value {
                my $type = $value.^name;
                die if $type ne 'Str';
                nqp::bindkey($this-prop, $key, $value);
            }
            nqp::bindkey($enum-prop-nqp, $property, $this-prop);
        }
        elsif %binary-properties{$property}:exists {
            $bitwidth = 1;
            nqp::bindkey($bin-prop-nqp, $property, '1');
        }
        else {
            die;
        }
        @code-sorted-props.push($property);
        @bitfield-h.push("    unsigned int $property :$bitwidth;");
    }
    @bitfield-h.push("\};");
    @bitfield-h.push("typedef struct binary_prop_bitfield binary_prop_bitfield;");

    my $t1 = now;
    my %bitfield-rows-seen = dedupe-rows(@sorted-cp, @code-sorted-props, $enum-prop-nqp, $bin-prop-nqp);
    say "Finished computing all rows, took {now - $t1} for {@sorted-cp.elems} elems. Now creating the final unduplicated version.";
    my $bitfield-rows := nqp::list_s;
    my $t2 = now;
    for %bitfield-rows-seen.sort(*.value.Int).».kv -> ($row-str, $index) {
        nqp::push_s($bitfield-rows, '    {' ~ $row-str ~ "\},/* index $index */");
    }
    my str $binary-struct-str = nqp::join("\n", $bitfield-rows);
    say "Took {now - $t2} seconds to join all the seen bitfield rows";
    my $prop-bitfield = qq:to/END/;
    #include <stdio.h>
    {get-prefix()} binary_prop_bitfield mybitfield[{$bin-index + 1}] = \{
    $binary-struct-str
        \};
    END
    return join "\n", $prop-bitfield, make-property-switches(@code-sorted-props).join("\n") ~ "\n";
}
sub dump-json ( Bool $dump ) {
    note "Converting data to JSON...";
    if $dump {
        write-file(%points.VAR.name ~ '.perl.p6',  %points.perl);
        write-file(%decomp_spec.VAR.name ~ '.perl.p6',  %decomp_spec.perl);
    }
    for %binary-properties, %PropertyValueAliases,
       %PropertyNameAliases, %PropertyNameAliases_to, %PropertyValueAliases_to {
        write-file(.VAR.name ~ '.perl.p6', $_.perl);
    }
    write-file(%enumerated-properties.VAR.name ~ '.perl.p6', %enumerated-properties.perl);
}
