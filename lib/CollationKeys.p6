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
            # If we have collation and noncollation link
            elsif %trie{$cp}.keys.all ~~ /^<:Numeric>+$/ {
                say "SPECIAL SUBSTRING data to add: $data.gist";
                say "Special substring existing data: {%trie{$cp}.gist}";
                for $data.keys -> $key {
                    %trie{$cp}{$key} = $data{$key};
                }
                say "Special substring AFTER data: {%trie{$cp}.gist}";
            }
            else {
                # This code allows identical collation data when there is a
                # nonmatching comment. This happens due to after normalization
                # there being repeats
                for %trie{$cp}.keys.grep({$_ ne 'comment' and $_ !~~ /^<:Numeric>+$/ }) -> $key {
                    die "\%trie\{$cp\}\{$key\}: {%trie{$cp}{$key}.gist} \$data\{$key\}: {$data{$key}.gist}"
                        unless %trie{$cp}{$key} eqv $data{$key};
                }
            }
        #    die "\%trie\{$cp\} eqv \$data FAILED\n\%trie\{$cp\}: {%trie{$cp}.gist}\n\$data: $data.gist()";
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
    if 1 < $var<codepoints>.elems {
        %list{$var<codepoints>[0]}<count>++;
        %list{$var<codepoints>[0]}<data>.push: $var;
        #say "adding to trie: $var.gist";
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
sub add-sub_node (
    Int:D :$cp!,
    Int:D :$min!,
    Int:D :$max!,
    Int:D :$sub_node_elems!,
    Positional :$subnode_collation_keys
) {
    my Int:D $collation_link      = $subnode_collation_keys ?? @collation-keys-array.elems   !! -1;
    my Int:D $collation_key_elems = $subnode_collation_keys ?? $subnode_collation_keys.elems !! -1;

    my Int:D $subnode_link        = $sub_node_elems ?? @sub_nodes.elems + 1 !! -1;

    my Int:D @a = $cp, $min, $max, $sub_node_elems, $subnode_link, $collation_key_elems, $collation_link;
    say 'subnode: ', @a.perl;

    die "collation_key_elems $collation_key_elems == sub_node_elems $sub_node_elems\ncollkeys: $subnode_collation_keys.gist()"
        if $collation_key_elems == $sub_node_elems;
    @sub_nodes.push: @a;
    if $collation_key_elems != -1 {
        die "No collation keys found?" unless $subnode_collation_keys.elems;
        my Str:D @keys-to-add = $subnode_collation_keys.map({'{' ~ .join(',') ~ '}'});
        @collation-keys-array.append: @keys-to-add;
    }
}
multi sub make-sub_node (Cool:D(Int) $cp!, Pair:D $node!) {
    sub dump-node-info (Str:D $description = '')  {
        note "$description Pair node: cp: $cp key: {$node.key.gist}\nvalue: {$node.value.gist}";
    }
    dump-node-info;
    my %hash = $node.key => $node.value;
    make-sub_node $cp, %hash;
}
multi sub make-sub_node (Cool:D(Int) $cp!, Hash:D $node!) {
    #dump-node-info;
    sub dump-node-info (Str:D $description = '')  {
        note "$description Hash node: cp: $cp keys: {$node.keys.gist}\nvalues: {$node.values.gist}";
    }
    dump-node-info;
    say 'WHAT: ', $node.WHAT;
    say "node.keys: ", $node.keys;
    my @numeric = only-numeric($node.keys);
    my @non-numeric = not-numeric($node.keys);

    say "NON NUMERIC: {@non-numeric.perl}" if @non-numeric;
    say "NUMERIC: {@numeric.perl}" if @numeric;
    # say $node.keys;
    # check if we have any further subnodes
    #if @numeric and @non-numeric {
    #}node
    #if @numeric {
        #die "There's a mix of numeric and non-numeric nodes. Script hasn't been "
         # ~ "tested for this condition.\n\$node.keys: $node.keys"
        #    unless $node.keys.all ~~ /^<:Numeric>+$/;
        my Int:D $min = @numeric ?? @numeric.min !! -1;
        my Int:D $max = @numeric ?? @numeric.max !! -1;
        my Int:D $sub_node_elems = @numeric.elems;
        # Add the subnode
        $node<array>:exists
            ?? add-sub_node(:$cp, :$min, :$max, :$sub_node_elems, :subnode_collation_keys($node<array>))
            !! add-sub_node(:$cp, :$min, :$max, :$sub_node_elems);
        for @numeric.sort -> $cp {
            say "cp $cp node\{cp\} ", $node{$cp};
            #say "cp $cp whole node $node.gist()";
            #exit;
            # Add the nodes below that node
            make-sub_node $cp, $node{$cp};
            CATCH { dump-node-info "FAILURE" }
        }
        #dump-node-info "HAS SUBNODE";
    #}
    if 0 and @non-numeric {
        die;
        # If there's no extra subnodes
        say "going normal";
        dump-node-info "NORMAL";
        my $min = -1;
        my $max = -1;
        my $sub_node_elems = 0;
        my $subnode_collation_keys = $node<array>;
        add-sub_node :cp($cp.Int), :$min, :$max, :$sub_node_elems, :subnode_collation_keys($node<array>);
        CATCH { dump-node-info }
    }
    # node.keys
    # codepoints, arrary, comment, 3285, 3288
    # holds the current node and also further nodes

}
sub only-numeric ($list) {
    say "trying to turn {$list.perl} into an array";
    my @list = $list.grep(/^<:Numeric>+$/);
    say @list.perl;
    @list = @list».Int;
    say @list.perl;
    @list;
}
sub not-numeric ($list) {
    $list.grep({$_ !~~ /^<:Numeric>+/}).Array;
}
# Receives pairs where the key is the main node's codepoint and the value is a hash containing
# the subnodes
sub make-main_node (*@pairs) {
    for @pairs -> $pair {
        say 'pair: ', $pair.perl;
        say 'value: ', $pair.value;
        say 'key: ', $pair.key;
        my Hash:D $node  = $pair.value;
        my Int:D $cp    = $pair.key.Int;
        my Int:D @numeric-keys = only-numeric($node.keys);
        my Int:D $max   = @numeric-keys.max;
        my Int:D $min   = @numeric-keys.min;
        my Int:D $sub_node_elems = @numeric-keys.elems;
        my Int:D $collation_key_elems = $node<array>:exists ?? $node<array>.elems !! 0;
        my Int:D $collation_key_link = $node<array>:exists ?? @collation-keys-array.elems !! -1;
        die "can't handle main nodes with collation elements" if 0 < $collation_key_elems;
        my $main-node-c-struct = '{' ~ ($cp, $min, $max, $sub_node_elems, @sub_nodes.elems, $collation_key_elems, $collation_key_elems).join(',') ~ '}';
        @main_nodes.push: $main-node-c-struct;
        for @numeric-keys.sort -> $key {
            say 'key: ', $key;
            say 'node: ', $node;
            say 'node{key}: ', $node{$key};
            my Int:D $cp = $key;
            make-sub_node $cp, $node;
        }
    }
    #say 'main-node-struct: ', $main-node-c-struct;
    #say 'sub-nodes: ', @sub_nodes.perl;
    return 'main-node-strict' => @main_nodes,
        'sub-nodes' => @sub_nodes,
        'collation-keys' => @collation-keys-array
}
sub compose-the-arrays {
    my @list-of-cp's-to-make-nodes-for;
    #for %trie.keys.pick(10) -> $random-pick-cp {
    #    @list-of-cp's-to-make-nodes-for.push: ($random-pick-cp => %trie{$random-pick-cp});
    #}
    my %nody = make-main_node #`(%trie.pairs) (4018 => %trie{4018});#, |@list-of-cp's-to-make-nodes-for;
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
