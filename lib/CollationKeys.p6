grammar Collation-Gram {
    token TOP {
        <codepoints>
        \s* ';' \s*
        <coll-key>+
        <comment>
        .*
    }
    token codepoints {
        <codepoint>+ % \s+
    }
    token codepoint {
        <:AHex>+
        #[$<cp>=(<:AHex>)\s+]
    }
    token comment { \s* '#' \s* <( .* $ }
    token coll-key {
        '[' ~ ']'
        [
            <dot-star> <primary> '.' <secondary> '.' <tertiary>
        ]
    }
    token dot-star { <[.*]> }
    token primary { <:AHex>+ }
    token secondary { <:AHex>+ }
    token tertiary { <:AHex>+ }


}
class Collation-Gram::Action {
    has @!array;
    has $!comment;
    has $!dot-star;
    has @!codepoints;
    method TOP ($/) {
        make %(
            array => @!array,
            comment => ~$<comment>,
            dot-star => ~$!dot-star,
            codepoints => @!codepoints
        )
    }
    method coll-key ($/) {
        $!dot-star.push: $<dot-star>;
        @!array.push: ($<primary>, $<secondary>, $<tertiary>).map(*.Str.parse-base(16));

    }
    method codepoints ($/) {
        @!codepoints.append: $<codepoint>.map(*.Str.parse-base(16));

    }

}
my %list{Int};
my %trie;
my @all;
my $i = 0;
my $max-coll-keys = 0;
sub add-to-trie (@list, %trie) {
    if !@list.elems {
        return;
    }
    my Int $cp = @list.shift;
    if %trie{$cp}:exists {
        add-to-trie @list, %trie{$cp};
    }
    else {
        %trie{$cp} = Hash.new;
        add-to-trie @list, %trie{$cp};
    }
}

for "UNIDATA/UCA/allkeys.txt".IO.lines -> $line {
    next if $line.starts-with('#') or !$line;
    # TODO add implict weights
    next if $line.starts-with('@');
    my $var = Collation-Gram.new.parse($line, :actions(Collation-Gram::Action.new)).made;
    @all.push: $var;
    if $var<codepoints>.elems > 1 {
        %list{$var<codepoints>[0]}<count>++;
        %list{$var<codepoints>[0]}<data>.push: $var;
        add-to-trie($var<codepoints>.Array, %trie);
    }
    #last if $i > 1000;
    $i++;
}
use Data::Dump;
my $output = Dump %trie;
spurt "temp.txt", $output;
#my %hash;
my @output;
my $keys = %list.keys;
#my $values = %hash.values;
@output.push: "Max number of cp's: {@all»<codepoints>».elems.max}";
@output.push: "Number of different special first cps: {$keys.elems}";
@output.push: "Number of different total collation thingys: {@all.elems}";
@output.push: "Longest number of collation keys {@all»<array>».elems.max} min: {@all»<array>».elems.min}";
@output.push: "Special starters:";
for %list.sort(*.key) {
    @output.push: "codepoint %4i %4i uses of %s".sprintf(.key, .value<count>, .key.uniname);
}
use JSON::Fast;
$*CWD.child('build').add('collation-data.json').spurt: to-json(%list);
#for %hash { @output.push: .gist }
#@output.push: '###';
say @output.join("\n");
exit;

#say '[.1D7F.0020.0008]' ~~ /<Collation-Gram::coll-key>/;
my $string = Q<A746 A746 ; [.1D7F.0020.0008][.1D7F.0020.0009] # LATIN CAPITAL LETTER BROKEN L>;
my $parse = Collation-Gram.new.parse($string,
:actions(Collation-Gram::Action.new)
);
say $parse.made;
# $parse.say;
