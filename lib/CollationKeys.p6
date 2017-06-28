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
            codepoints => @!codepoints.chrs.ords
        )
    }
    method coll-key ($/) {
        my $a = ($<primary>, $<secondary>, $<tertiary>).map(*.Str.parse-base(16)).Array;
        $a.push: ($<dot-star> eq '.' ?? 0 !! $<dot-star> eq '*' ?? 1 !! do { die $<dot-star> });
        @!array.push: $a;

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
sub add-to-trie (@list, %trie, $data) {
    if !@list {
        return;
    }
    my Int $cp = @list.shift;
    if %trie{$cp}:exists {
        if !@list {
            if %trie{$cp} eqv $data {
                say "nexting";
                next;
            }
            die;
        }
        add-to-trie @list, %trie{$cp}, $data;
    }
    else {
        if !@list {
            %trie{$cp} = $data;
        }
        else {
            %trie{$cp} = Hash.new;
            add-to-trie @list, %trie{$cp}, $data;
        }
    }
}
note 'processing data';
for "UNIDATA/UCA/allkeys.txt".IO.lines -> $line {
    next if $line.starts-with('#') or !$line;
    # TODO add implict weights
    next if $line.starts-with('@');
    my $var = Collation-Gram.new.parse($line, :actions(Collation-Gram::Action.new)).made;
    @all.push: $var;
    if $var<codepoints>.elems > 2 {
        %list{$var<codepoints>[0]}<count>++;
        %list{$var<codepoints>[0]}<data>.push: $var;
        add-to-trie($var<codepoints>.Array, %trie, $var);
    }
    if $var<codepoints>.elems > 2 {
        say "more than 2 codepoints in a row: $var";
    }
    #last if $i > 1000;
    $i++;
}
note 'done processing';
my @collation-keys-array;
my @sub_nodes;
my @main_nodes;
my @seen = 0,0;
sub add-sub_node (
    Int:D :$cp!, Int:D :$min!, Int:D :$max!,
    Int:D :$sub_node_elems!, Positional :$collation-keys
) {
    my Int:D $link = @collation-keys-array.elems;
    my Int:D $collation_key_elems = $collation-keys ?? $collation-keys.elems !! -1;
    my Int:D @a = $cp, $min, $max, $sub_node_elems, $collation_key_elems, $link;
    die "collation_key_elems $collation_key_elems == link $link" if $collation_key_elems == $link;
    @sub_nodes.push: @a;
    if $collation_key_elems != -1 {
        die unless $collation-keys.elems;
        my Str:D @keys-to-add = $collation-keys.map({'{' ~ .join(',') ~ '}'});
        @collation-keys-array.append: @keys-to-add;
    }
}
sub make-sub_node (:$cp!, :$node!) {
    #dump-node-info;
    sub dump-node-info (Str:D $description = '')  {
        note "$description cp: $cp keys: $node.keys()\nvalue: $node.gist()";
    }
    #say $node.keys;
    # check if we have any further subnodes
    if $node.keys.any ~~ /^<:Numeric>+$/  {
        say "Numeric match";
        die $node.keys unless $node.keys.all ~~ /^<:Numeric>+$/;
        my @sub-cp's = $node.keys».Int;
        say "sub-cps: ", @sub-cp's.join(' ');
        my Int:D $min = @sub-cp's.min;
        my Int:D $max = @sub-cp's.max;
        my Int:D $sub_node_elems = @sub-cp's.elems;
        my Int:D $collation_key_elems = -1;
        # Add the subnode
        add-sub_node(:cp($cp.Int), :$min, :$max, :$sub_node_elems);
        for @sub-cp's -> $cp {
            say "cp $cp node\{cp\} ", $node{$cp};
            #say "cp $cp whole node $node.gist()";
            #exit;
            # Add the nodes below that node
            make-sub_node :cp($cp.Int), :node($node{$cp});
            CATCH { dump-node-info "FAILURE" }
        }
        #dump-node-info "HAS SUBNODE";
        return;
    }
    # If there's no extra subnodes
    say "going normal";
    dump-node-info "NORMAL";
    my $min = -1;
    my $max = -1;
    my $sub_node_elems = 0;
    add-sub_node :cp($cp.Int), :$min, :$max, :$sub_node_elems, :collation-keys($node<array>);
    # node.keys
    # codepoints, arrary, comment, 3285, 3288
    # holds the current node and also further nodes

}
# Receives pairs where the key is the main node's codepoint and the value is a hash containing
# the subnodes
sub make-main_node (*@pairs) {
    for @pairs -> $pair {
        my $node  = $pair.value;
        my $cp    = $pair.key;
        my $max   = $node.keys.max;
        my $min   = $node.keys.min;
        my $elems = $node.keys.elems;
        my $collation_key_elems = 0;
        my $main-node-c-struct = '{' ~ ($cp, $min, $max, $elems, $collation_key_elems, @sub_nodes.elems).join(',') ~ '}';
        @main_nodes.push: $main-node-c-struct;
        for $node.sort(*.key.Int) -> $pair {
            my ($cp, $node) = ($pair.key, $pair.value);
            make-sub_node :$cp, :$node;
        }
    }
    #say 'main-node-struct: ', $main-node-c-struct;
    #say 'sub-nodes: ', @sub_nodes.perl;
    return 'main-node-strict' => @main_nodes,
        'sub-nodes' => @sub_nodes,
        'collation-keys' => @collation-keys-array
}
sub compose-the-arrays {
    my %nody = make-main_node #`(%trie.pairs) 119128 => %trie{119128};
    say "#define main_nodes_elems @main_nodes.elems()";
    say compose-array 'sub_node', 'main_nodes', @main_nodes;
    say "#define sub_nodes_elems @sub_nodes.elems()";
    say compose-array 'sub_node', 'sub_nodes', @sub_nodes;
    say "#define special_collation_keys_elems @collation-keys-array.elems()";
    say compose-array 'collation_key', 'special_collation_keys', @collation-keys-array;
    use lib 'lib';
    use ArrayCompose;
    #say 'collation-keys: ', @collation-keys-array.perl;
    exit;
    #spurt "temp.txt", $output;
    #my %hash;
}
compose-the-arrays;
my @output;
my $keys = %list.keys;
#my $values = %hash.values;
@output.push: "Max number of cp's: {@all»<codepoints>».elems.max}";
@output.push: "Number of different special first cps: {$keys.elems}";
@output.push: "Number of different total collation thingys: {@all.elems}";
my @biggest = @all»<array>»[0].max, @all»<array>»[1].max, @all»<array>»[2].max;
@output.push: "Biggest primary: @biggest[0] Biggest secondary: @biggest[1] Biggest tertiary: {@biggest[2]}";
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
