use lib 'lib';
use Collation-Gram;
my $debug = False;
my $test-data = Q:to/END/;
0F68  ; [.2E6C.0020.0002] # TIBETAN LETTER A
0F00  ; [.2E6C.0020.0004][.2E83.0020.0004][.0000.00C4.0004] # TIBETAN SYLLABLE OM
0FB8  ; [.2E6D.0020.0002] # TIBETAN SUBJOINED LETTER A
0F88  ; [.2E6E.0020.0002] # TIBETAN SIGN LCE TSA CAN
0F8D  ; [.2E6F.0020.0002] # TIBETAN SUBJOINED SIGN LCE TSA CAN
0F89  ; [.2E70.0020.0002] # TIBETAN SIGN MCHU CAN
0F8E  ; [.2E71.0020.0002] # TIBETAN SUBJOINED SIGN MCHU CAN
0F8C  ; [.2E72.0020.0002] # TIBETAN SIGN INVERTED MCHU CAN
0F8F  ; [.2E73.0020.0002] # TIBETAN SUBJOINED SIGN INVERTED MCHU CAN
0F8A  ; [.2E74.0020.0002] # TIBETAN SIGN GRU CAN RGYINGS
0F8B  ; [.2E75.0020.0002] # TIBETAN SIGN GRU MED RGYINGS
0F71  ; [.2E76.0020.0002] # TIBETAN VOWEL SIGN AA
0F72  ; [.2E77.0020.0002] # TIBETAN VOWEL SIGN I
0F73  ; [.2E78.0020.0002] # TIBETAN VOWEL SIGN II
0F71 0F72 ; [.2E78.0020.0002] # TIBETAN VOWEL SIGN II
0F80  ; [.2E79.0020.0002] # TIBETAN VOWEL SIGN REVERSED I
0F81  ; [.2E7A.0020.0002] # TIBETAN VOWEL SIGN REVERSED II
AAB5 AA87 ; [.2DEA.0020.0002][.2E18.0020.0002] # <TAI VIET VOWEL E, TAI VIET LETTER HIGH GO>
END
my $out-data = Q:to/ENDing/;
{array => [[11884 32 2 0]], codepoints => (3944), comment => TIBETAN LETTER A}
{array => [[11884 32 4 0] [11907 32 4 0] [0 196 4 0]], codepoints => (3840), comment => TIBETAN SYLLABLE OM}
{array => [[11885 32 2 0]], codepoints => (4024), comment => TIBETAN SUBJOINED LETTER A}
{array => [[11886 32 2 0]], codepoints => (3976), comment => TIBETAN SIGN LCE TSA CAN}
{array => [[11887 32 2 0]], codepoints => (3981), comment => TIBETAN SUBJOINED SIGN LCE TSA CAN}
{array => [[11888 32 2 0]], codepoints => (3977), comment => TIBETAN SIGN MCHU CAN}
{array => [[11889 32 2 0]], codepoints => (3982), comment => TIBETAN SUBJOINED SIGN MCHU CAN}
{array => [[11890 32 2 0]], codepoints => (3980), comment => TIBETAN SIGN INVERTED MCHU CAN}
{array => [[11891 32 2 0]], codepoints => (3983), comment => TIBETAN SUBJOINED SIGN INVERTED MCHU CAN}
{array => [[11892 32 2 0]], codepoints => (3978), comment => TIBETAN SIGN GRU CAN RGYINGS}
{array => [[11893 32 2 0]], codepoints => (3979), comment => TIBETAN SIGN GRU MED RGYINGS}
{array => [[11894 32 2 0]], codepoints => (3953), comment => TIBETAN VOWEL SIGN AA}
{array => [[11895 32 2 0]], codepoints => (3954), comment => TIBETAN VOWEL SIGN I}
{array => [[11896 32 2 0]], codepoints => (3953 3954), comment => TIBETAN VOWEL SIGN II}
{array => [[11896 32 2 0]], codepoints => (3953 3954), comment => TIBETAN VOWEL SIGN II}
{array => [[11897 32 2 0]], codepoints => (3968), comment => TIBETAN VOWEL SIGN REVERSED I}
{array => [[11898 32 2 0]], codepoints => (3953 3968), comment => TIBETAN VOWEL SIGN REVERSED II}
ENDing
#`(class collation_key {
    has Int:D $.primary   is rw;
    has Int:D $.secondary is rw;
    has Int:D $.tertiary  is rw;
    has Int:D $.special   is rw;
})
class p6node {
    has Int $.cp;
    has @!collation_elements;
    has $!last;
    has %.next is rw;
    method next-cps                           { %!next.keys.map(*.Int).sort }
    method has-collation                      { @!collation_elements.Bool    }
    method get-collation                      { @!collation_elements }
    method set-collation (Positional:D $list) {
        @!collation_elements = |$list;
    }
    method set-cp (Int:D $cp) { $!cp = $cp }
}
sub p6node-find-node (Int:D $cp, p6node $p6node is rw --> p6node) is rw {
    die unless $p6node.next{$cp}.VAR.^name eq 'Scalar';
    die "can't find the node for $cp " unless $p6node.next{$cp}.isa(p6node);
    return-rw $p6node.next{$cp} orelse die "Can't find node";
}
sub p6node-create-or-find-node (Int:D $cp, p6node:D $p6node is rw) is rw {
    my $hash := $p6node.next;
    #say "p6node-create-or-find-node called for cp $cp";
    if $hash{$cp}:exists {
        return-rw $p6node.next{$cp};
    }
    else {
        my $obj = p6node.new(cp => $cp, last => $hash);
        $obj.set-cp($cp);
        $hash{$cp} = $obj;
        return-rw $hash{$cp};
    }

}
sub print-var ($var) { $var.gist }
my Str $Unicode-Version;
my @implicit-weights;
sub parse-test-data (p6node:D $main-p6node) {
    my $do-test-data = True;
    my $data = $do-test-data ?? $test-data !! "UNIDATA/UCA/allkeys.txt".IO;
    my $line-no;
    for $data.lines -> $line {
        $line-no++;
        last if 10_000 < $line-no;
        #say $line-no;
        next if $line eq '' or $line.starts-with('#');
        if $line.starts-with('@version') {
            $Unicode-Version = $line.subst('@version ', '');
            next;
        }
        if $line.starts-with('@implicitweights') {
            @implicit-weights.push: $line.subst('@implicitweights ', '');
            next;
        }
        #$line ~~ / ^ [ $<codes>=( <:AHex>+ )+ % \s+ ] \s* ';' .* $ / or next;
        my $var = Collation-Gram.new.parse($line, :actions(Collation-Gram::Action.new)).made;
        die $line unless $var;
        next if $var<codepoints>.elems == 1 && $var<array>.elems == 1;
        say "Adding data for cp $var<codepoints>[0]" if $var<codepoints>.any == 183;
        my $node = $main-p6node;
        say $line, "\n", $var<codepoints> if $debug;
        for $var<codepoints>.list -> $cp {
            $node = p6node-create-or-find-node($cp, $node);
        }
        $node.set-collation($var<array>);
    }
    say "Done with parse-test-data";
}

class sub_node {
    has Int $.codepoint;
    has Int $.sub_node_elems      is rw;
    has Int $.sub_node_link       is rw;
    has Int $.collation_key_elems is rw;
    has Int $.collation_key_link  is rw;
    has Int $.element             is rw;
    method build {
        $!codepoint,
        $.sub_node_elems,
        $.sub_node_link,
        $.collation_key_elems,
        $.collation_key_link,
        $.element
    }
}
#| Adds the initial codepoint nodes to @main-node
sub add-main-node-to-c-data (p6node:D $p6node is rw, @main-node) is rw {
    for $p6node.next.keys.map(*.Int).sort -> $cp {
        my $thing := sub_node.new(codepoint => $cp, element => @main-node.elems);
        @main-node.push: $thing;
    }
    @main-node.elems;
}

#say Dump @main-node;
#| Follows the codepoints already in @main-node and adds sub_nodes based on that
sub sub_node-flesh-out-tree-from-main-node-elems
(p6node:D $main-p6node is rw, @main-node, @collation-elements) {
    for ^@main-node -> $i {
        #say "Processing $sub_node.codepoint()";
        sub_node-add-to-c-data-from-sub_node(@main-node[$i],
            p6node-find-node(@main-node[$i].codepoint, $main-p6node),
            @main-node, @collation-elements);
    }
}
sub sub_node-add-to-c-data-from-sub_node
(sub_node:D $sub_node is rw, p6node:D $p6node is rw, @main-node, @collation-elements --> sub_node:D) is rw {
    die unless $sub_node.codepoint == $p6node.cp;
    if $p6node.has-collation {
        my $temp := sub_node-add-collation-elems-from-p6node($sub_node, $p6node, @collation-elements);
        die "\$temp !=== \$sub_node" unless $temp === $sub_node;
    }
    #if !$sub_node.sub_node_elems {
    $sub_node.sub_node_elems = $p6node.next.elems;
    #}
    #die "\$sub_node.sub_node_elems !== \$p6node.next.elems" unless $sub_node.sub_node_elems == $p6node.next.elems;
    my Int ($last-link, $first-link) = -1 xx 2;
    for $p6node.next-cps -> $cp {
        $last-link = sub_node-add-sub_node($cp, @main-node);
        sub_node-add-to-c-data-from-sub_node(@main-node[$last-link], p6node-find-node($cp, $p6node), @main-node, @collation-elements);
        $first-link = $last-link if !$first-link.defined;
    }
    $sub_node.sub_node_link = $first-link;
    $sub_node;
}
sub sub_node-add-sub_node (Int:D $cp, @main-node --> Int:D) {
    my $node := sub_node.new(codepoint => $cp, element => @main-node.elems);
    die "!\$node.element.defined || !\$node.codepoint.defined"
        unless $node.element.defined && $node.codepoint.defined;
    @main-node.push: $node;
    return @main-node.elems - 1;
}
sub sub_node-add-collation-elems-from-p6node (sub_node:D $sub_node is rw, p6node:D $p6node is rw, @collation-elements --> sub_node:D) is rw {
    die "!\$p6node.has-collation" unless $p6node.has-collation;
    my Int:D $before-elems = @collation-elements.elems;
    for $p6node.get-collation <-> $element {
        @collation-elements.push: $element;
    }
    my Int:D $after-elems = @collation-elements.elems;
    $sub_node.collation_key_link  = $before-elems;
    $sub_node.collation_key_elems = $after-elems - $before-elems;
    #say "Adding collation data for $sub_node.codepoint()";
    $sub_node;
}
my @main-node;
my @collation-elements;
my $main-p6node = p6node.new;

parse-test-data($main-p6node);

use Data::Dump;
#say Dump $main-p6node;
my $main-node-elems = add-main-node-to-c-data($main-p6node, @main-node);
#say Dump $main-p6node;
#exit;
sub_node-flesh-out-tree-from-main-node-elems($main-p6node, @main-node, @collation-elements);
say Dump @main-node;
use JSON::Fast;
spurt 'out_nodes', to-json(@main-node.map(*.build));
#for ^@main-node {
    #say "\@main-node[$_]:\n", Dump @main-node[$_];
#}
say now - INIT now;

#say Dump @main-node;
 #`｢
%data{20} = p6node
p6node =
    cp = 20,
    collation_elements = [11890 32 2 0],
    link = hash
        hash{21} = p6node
｣
#`(
struct collation_key_storage {
    unsigned int primary :16;
    unsigned int secondary :9;
    unsigned int tertiary :5;
    unsigned int special :1;
};
typedef struct collation_key_storage collation_key_storage;

struct sub_node {
    unsigned int codepoint :18;
    unsigned int sub_node_elems :20;
    int sub_node_link :11;
    unsigned int collation_key_elems :5;
    int collation_key_link :15;
};
)
