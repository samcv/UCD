#!/usr/bin/env perl6
use experimental :macros, :collation;
use nqp;
use JSON::Fast;
use Data::Dump;
use Terminal::ANSIColor;
use lib 'lib';
use UCDlib; use ArrayCompose; use Set-Range;
use seenwords; use EncodeBase40; use Operators;
use BitfieldPacking; use bitfield-rows-switch;
#INIT note "Starting…";
constant $build-folder = "source";
constant $snippets-folder = "snippets";
#my $BOLD     = BOLD;
#my $BOLD_OFF = BOLD_OFF;
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
my %points = nqp::hash; # Stores all the cp's property values of all types
my %names = nqp::hash; # Unicode Name hash for generating the name table
my %binary-properties; # Stores the binary property names
# Stores enum prop names and also the property
# codes which are just internal numbers to represent it in the C datastructure
my %enumerated-properties;
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
constant $missing-str = '# @missing';
constant @gc = 'General_Category_1', 'General_Category_2';
my %point-to-struct;
my %bitfields;
my %point-index = nqp::hash;
my $debug-global = False;
my $less-global;
my int $bin-index = -1;
my $indent = ' ' x 4;

sub MAIN ( Bool:D :$dump = False, Bool:D :$nomake = False, Int:D :$less = 0,
           Bool:D :$debug = False, Bool:D :$names-only = False, Bool:D :$no-UnicodeData = False,
           Bool:D :$no-names = False, Str :$only? ) {
    my @only = $only ?? $only.split( [',', ' '] ) !! Empty;
    $debug-global = $debug;
    $less-global = $less;
    start-routine();
    PNameAliases("PropertyAliases", %PropertyNameAliases, %PropertyNameAliases_to);
    PValueAliases("PropertyValueAliases", %PropertyValueAliases, %PropertyValueAliases_to);
    timer('UnicodeData');
    UnicodeData("UnicodeData", $less, $no-UnicodeData);
    die Dump %points unless %points{0}:exists;
    timer('UnicodeData');

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
        tweak_nfg_qc() unless $less;
        say now - INIT now;
    }
    unless $nomake {
        my $int-main;
        if $less == 0 or %enumerated-properties{'Numeric_Value_Numerator'}:!exists {
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
        write-file('names.c', Generate_Name_List()) unless $no-UnicodeData or $no-names;
    }
    say "Took {now - INIT now} seconds.";
    dump-json($dump) unless $dump;
}
sub missing (Str $line is copy) {
    # @missing: 0000..10FFFF; cjkAccountingNumeric; NaN
    die unless $line.starts-with($missing-str);
    $line ~~ s/$missing-str': '//;
    my @parts = $line.split-trim(';');
    %missing{@parts[1]} = @parts[2];
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
    has $.negname;
    has $!type;
    has %.enum;
    has $!bitwidth;
    method type {
        $!type = $!negname.WHAT.^name;
        $!type;
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
        my @parts = .split-trim([';','#']);
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
    for slurp-lines($filename) {
        next if skip-line($_);
        nqp::bindkey(%props-seen,
        apply-pv-to-range(
         |.split([';','#'], 3).head(2).».trim,
        # Range, # Property Name
          True       # Property Value
        ), True);
    }
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
sub enumerated-property ( Int $column, $negname, Str $propname, Str $filename ) {
    my %seen-value = nqp::hash;
    die $propname unless %PropertyValueAliases{$propname}:exists;
    my Int $i = 0;
    my $t1 = now;
    for slurp-lines($filename) {
        next if skip-line($_);
        my \parts := .split-trim([';','#'], $column + 2);
        #nqp::bind($property-value, @parts[$column]);
        bindkey(%seen-value, parts[$column], True);
        apply-pv-to-range(
            parts[0], # range
            $propname,
            parts[$column] # property value
        );
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
sub tweak_nfg_qc {
    note "Tweaking NFG_QC…";
    timer('tweak_nfg_qc');
    # See http://www.unicode.org/reports/tr29/tr29-27.html#Grapheme_Cluster_Boundary_Rules
    # \r
    my @nfg_qc_no =
        0x0D, # \r
        0x0E33, 0x0EB3; # some specials
    ;
    %points{$_}<NFG_QC> = False if %points{$_}:exists for @nfg_qc_no;
    for %points.keys -> $code {
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
        my @parts = .split-trim(';');
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
    #register-binary-property(<NFD_QC NFC_QC NFKD_QC NFG_QC Any Bidi_Mirrored>);
    register-binary-property(<Any Bidi_Mirrored>);
    my %seen-ccc = nqp::hash;
    my %seen-gc = nqp::hash;
    #3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;
    our $first-point-cp;
    my %First-point; # %First-point gets assigned a value if it matches as above
    # and so is the first in a range inside UnicodeData.txt
    my $num-processed = 0;
    my $t1 = now;
    for slurp-lines $file {
        next if skip-line($_);
        #`{{
        my @parts = nqp::split(';', $_);
        my ($code-str, $name, $gencat, $ccclass, $bidiclass, $decmpspec,
            $num1, $num2, $num3, $bidimirrored, $u1name, $isocomment,
            $suc, $slc, $stc) = @parts;
        }}
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
            #if nqp::existskey(%seen-gc, $gencat) {
            #    %hash{@gc[0]} = atkey2(%seen-gc, $gencat, @gc[0]);
            #    %hash{@gc[1]} = atkey2(%seen-gc, $gencat, @gc[1]);
            #}
            #else {

                #my $h := nqp::hash;
                #bindkey($h, @gc[0], %hash{@gc[0]});
                #bindkey($h, @gc[1], %hash{@gc[1]});
                #bindkey(%seen-gc, $gencat, $h);
            #}
        }
        if $ccclass {
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

        #`( For now these are flipped instead of setting this here
        %hash<NFD_QC>  = True;
        %hash<NFC_QC>  = True;
        %hash<NFKD_QC> = True;
        %hash<NFG_QC>  = True;
        #`)
        bindkey(%hash, 'Any', True);
        bindkey(%hash, 'Bidi_Mirrored', True) if starts-with($bidimirrored, 'Y');

        if $decmpspec {
            my @dec = nqp::split(' ', $decmpspec);
            %decomp_spec{$cp}<type> = starts-with(@dec[0], '<')
            ?? @dec.shift
            !! 'Canonical';
            %decomp_spec{$cp}<mapping> = @dec.map( { hex $_ } )
        }
        if starts-with($name, '<') {
            if $name.ends-with(', Last>') {
                my $t9 = now;
                $name ~~ s/', Last>'$/>/;
                if %First-point {
                    # This function can work on ranges
                    for Range.new($first-point-cp, $cp) {
                        # We need to duplicate the hash so each cp hash a new hash
                        my %new-hash = %hash;
                        apply-hash-to-cp($_, %new-hash);
                    }
                    #say "Found Range in UnicodeData: $first-point-cp..$cp";
                    for $first-point-cp..$cp {
                        bindkey(%names, base10_I_decont($_), $name);
                    }
                    %First-point := {};
                    $first-point-cp = Nil;
                    #say "Took ", now - $t9, " seconds to process this range";
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
        apply-hash-to-cp($cp, %hash);
        # This only does single points so we use it to improve speed
        # Bind the names hash we generate the Unicode Name C data from
        bindkey(%names, base10_I_decont($cp), $name);
    }
    my $time-took = now - $t1;
    say "Took $time-took secs to process $num-processed and ",
        ($time-took/($num-processed or 1) * 1000).fmt("%.4f"), " ms/line";
    my $gc_0-seen = get-pvalue-seen(@gc[0], '');
    my $gc_1-seen = get-pvalue-seen(@gc[1], '');
    for %seen-gc.keys {
        my @letters = .comb;
        $gc_0-seen.saw(@letters[0]);
        $gc_1-seen.saw(@letters[1]);
    }
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
sub apply-pv-to-range ($range-str, Str $pname, $value) is raw {
    # If it contains `..` then it is a range
    my \items = $range-str.split('..').map( { hex $_ } );
    if items[1].defined {
        for items[0]..items[1] -> $cp {
            apply-pv-to-cp($cp, $pname, $value);
        }
    }
    elsif items[0].defined {
        apply-pv-to-cp(items[0], $pname, $value);
    }
    else {
        die "Unknown range '$range-str'";
        return False;
    }
    return $pname;
}
sub apply-pv-to-cp (int $cp, Str $pname, $value) is raw {
    my \cp_s = base10_I($cp);
    #dump %points{0xAC01} if $cp == 0xAC00;
    #dump %points{0xAC00} if $cp == 0xAC00;
    #say $cp.fmt("apply-pv-to-cp cp: %X") if issue-prop($pname);
    if !existskey(%points, cp_s) {
        bindkey(%points, cp_s, nqp::hash);
    }
    elsif %points{cp_s}{$pname}:exists {
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
    #say %points{$cp}{$pname};
    #nqp::atkey(%points, $cp, Pair.new($pname, $value));
    #bindkey(%points, $pname, $value);
    #say '%points{', $cp, '}:  ', Dump %points{$cp};
    #%points{$cp}{$pname} = $value;
    #dump %points{0xAC01} if $cp == 0xAC00;
    #dump %points{0xAC00} if $cp == 0xAC00;

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
sub make-point-index (:$less) {
    note $BOLD, "Making point_index…\n", $RESET;
    my $t0 = now;
    my %points-ranges = get-points-ranges(%point-index);
    say "Took ", $BOLD, now - $t0, $RESET, " seconds to compute point_index ranges";
    my $dump-count = 0;
    my Int $point-max = %points.keys.sort(-*.Int)[0].Int;
    #say "point-max $point-max";
    my Str $type = compute-type($bin-index + 1);
    #`{{
    my int $bin-index_i = nqp::unbox_i($bin-index);
    my $mapping := nqp::list_s;
    my @rows;
    my $i := nqp::add_i(0, 0);
    for 0..$point-max -> $i {
        my $point_s := base10_I_decont($i);
        nqp::if(existskey(%point-index, $point_s),
            # if
            nqp::push_s($mapping, atkey(%point-index, $point_s)),
            # XXX for now let's denote things that have no value with 1 more than max index
            # else
            nqp::push_s($mapping,
                atkey(%point-index,
                    base10_I( nqp::add_i( $bin-index_i, 1)
                    )
                )
            )
        );
    }
    spurt "mapping.txt", nqp::join("\n", $mapping);
    #`}}
    my $t1 = now;
    my Cool:D @mapping;
    my $min-elems = 10;
    my str @range-str = 'int get_bitfield_offset (uint32_t cp) {',
        '#define BITFIELD_DEFAULT ' ~ $bin-index + 1, 'int return_val = cp;';
    my $indent = '';
    my $tabstop = ' ';
    for %points-ranges.sort(*.key.Int) {
        my $range-no = .key;
        my $range = .value;
        #say "range-no ", $range-no;
        #say "range[0] ", $range[0];
        my $inc-diff = $range.tail - $range.head + 1;
        my $what = 0;
        if %point-index{$range.head}:exists {
            if $range.elems > $min-elems {
                @range-str.push( [~] $indent, 'if (cp >= ', $range.head, ') {',
                ($inc-diff != 1 ?? ' return_val -= ' ~ $inc-diff ~ ';' !! '') );
                $indent ~= $tabstop;
                @range-str.push: $indent ~ 'if (cp <= ' ~ $range.tail ~ ') return ' ~ %point-index{$range.head} ~ ';';
            }
            else {
                my $point-index-var = %point-index{$range.head};
                for ^$range.elems {
                    #`(
                    die "point-index-var: $point-index-var, point-index\{$range\[$_\]\}: {%point-index{$range[$_]}}"
                        if $point-index-var != %point-index{$range[$_]};
                    dump $range-no;
                    dump $range;
                    say '$range[', $_, ']: ', $range[$_], ' %point-index{', $range[$_], '}: ', %point-index{$range[$_]}.perl;
                    #`)
                    @mapping.push: %point-index{ $range[$_] };
                }
            }
        }
        else {
            if $range.elems > $min-elems {
                #say "donet exist";
                @range-str.push( [~] $indent, 'if (cp >= ', $range.head, ') {',
                ($inc-diff != 1 ?? ' return_val -= ' ~ $inc-diff ~ ';' !! '') );
                $indent ~= $tabstop;
                @range-str.push: $indent ~ 'if (cp <= ' ~ $range.tail ~ ') return BITFIELD_DEFAULT;';
            }
            else {
                for ^$range.elems {
                    @mapping.push($bin-index + 1)
                }
            }
        }
    }
    while $indent.chars {
        @range-str.push: $indent ~ '}';
        $indent = ' ' x ($indent.chars - $tabstop.chars);
    }
    @range-str.push: 'return point_index[return_val];';
    @range-str.push: '}' ~ "\n";
    #say "Range str: ", @range-str.join("\n");

    my $string = @mapping.join(',');
    my int $chars = nqp::chars($string);
    say "Adding newlines every 70-79 chars";
    $string .= break-into-lines(',');
    say now - $t1 ~ "Took this long to concat points";
    my $mapping-str = ("#define max_bitfield_index $point-max\n$type point_index[", @mapping.elems, "] = \{\n    ", $string, "\n\};\n").join;
    $mapping-str ~ @range-str.join("\n");
}
sub make-bitfield-rows {
    note "Making bitfield-rows…";
    my str @code-sorted-props;
    my $code-sorted-props := nqp::list_s;
    # Create the order of the struct
    @bitfield-h.push("struct binary_prop_bitfield  \{");
    my $bin-prop-nqp := nqp::hash;
    #| Stores an array of Pairs where the key is the property name and the
    #| value is the bitwidth. It then passes it off to BitfieldPacking module
    my @list-for-packing;
    say @list-for-packing.WHY;
    for %binary-properties.keys.sort(&[unicmp]) -> $bin {
        @list-for-packing.push($bin => 1);
    }
    my $enum-prop-nqp := nqp::hash;
    for %enumerated-properties.sort({ $^a.key unicmp $^b.key }) {
        @list-for-packing.push(.key => .value.bitwidth);
    }
    my @packed-enums = compute-packing(@list-for-packing);
    say "Packed-enums: ", @packed-enums.perl;
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
    my $bitfield-rows := nqp::list_s;
    my %bitfield-rows-seen = nqp::hash;
    my $t1 = now;
    my ($enum, $enum-prop-nqp-prop);
    my \bitfield-columns := nqp::list_s;
    my \points-point := 0;
    my $bitfield-rows-str;
    #my str $bin-index_s = '';
    for %points.keys.sort(*.Int) -> $point {
        nqp::bind(bitfield-columns, nqp::list_s);
        nqp::bind(points-point, nqp::decont(nqp::atkey(%points, $point)));
        for @code-sorted-props -> $prop {
            nqp::if( nqp::existskey(points-point, $prop), (
                nqp::if( nqp::existskey($bin-prop-nqp, $prop), (
                    nqp::push_s(bitfield-columns,
                        nqp::if(nqp::atkey(points-point, $prop), '1', '0')
                    );
                ), (nqp::if(nqp::existskey($enum-prop-nqp, $prop), (
                      nqp::stmts(
                        #nqp::bind($enum-prop-nqp-prop, nqp::atkey($enum-prop-nqp, $prop)),
                        # If the key exists we need to look up the value
                        nqp::bind($enum, nqp::atkey(points-point, $prop)),
                        # If it doesn't exist we already have the property code.
                        # Eventually we may want to try and have it so all things
                        # either have or don't have the property for consistency
                        # XXX
                        nqp::if( nqp::existskey(nqp::atkey($enum-prop-nqp, $prop), $enum), (
                            nqp::push_s(bitfield-columns, atkey2($enum-prop-nqp, $prop, $enum));
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
        $bitfield-rows-str := nqp::join(',', bitfield-columns);
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
    my $t2 = now;
    say "Finished computing all rows, took {now - $t1}. Now creating the final unduplicated version.";
    for %bitfield-rows-seen.sort(*.value.Int).».kv -> ($row-str, $index) {
        nqp::push_s($bitfield-rows, '    {' ~ $row-str ~ "\},/* index $index */");
    }
    my str $binary-struct-str = nqp::join("\n", $bitfield-rows);
    say "Took {now - $t2} seconds to join all the seen bitfield rows";
    return qq:to/END/;
    #include <stdio.h>
    {get-prefix()} binary_prop_bitfield mybitfield[{$bin-index + 1}] = \{
    $binary-struct-str
        \};
    END
}
sub dump-json ( Bool $dump ) {
    note "Converting data to JSON...";
    if $dump {
        write-file(%points.VAR.name ~ '.Dump.p6',  Dump %points);
        write-file(%decomp_spec.VAR.name ~ '.Dump.p6',  Dump %decomp_spec);
    }
    for %binary-properties, %PropertyValueAliases,
       %PropertyNameAliases, %PropertyNameAliases_to, %PropertyValueAliases_to {
        write-file(.VAR.name ~ '.Dump.p6', Dump $_);
    }
    write-file(%enumerated-properties.VAR.name ~ '.Dump.p6', Dump %enumerated-properties);
}
