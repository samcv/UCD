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
    return if !@list;
    my Int:D $cp = @list.shift;
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
        add-to-trie($var<codepoints>.Array, %trie, $var);
    }
    if $var<codepoints>.elems > 2 {
        say "more than 2 codepoints in a row: $var";
    }
    #last if $i > 1000;
    $i++;
}
my @collation-keys-array;
my @sub_nodes;
my @main_nodes;
#| (primary, secondary, tertiary, dot-star)
sub add-collation-keys (@keys) {
    my Str:D @keys-to-add = @keys.map({'{' ~ .join(',') ~ '}'});
    say 'coll-keys: ', @keys-to-add.perl;
    my Int:D $before-collation-array-elems = @collation-keys-array.elems;
    @collation-keys-array.append: @keys-to-add;
    my Int:D $after-collation-array-elems = @collation-keys-array.elems;
    say "Collation-array-elems: Before $before-collation-array-elems After $after-collation-array-elems";
    return $before-collation-array-elems, @keys.elems;
}
note 'done processing';
sub add-sub_node (
    Int:D  $node's-cp!,
    Int:D :$min!,
    Int:D :$max!,
    Int:D :$sub_node_elems!,
    Positional :$subnode_collation_keys
) {
    my Int:D ($collation_link, $collation_key_elems) = $subnode_collation_keys
        ?? add-collation-keys($subnode_collation_keys)
        !! (-1,-1);
    my Int:D $subnode_link = $sub_node_elems
        ?? @sub_nodes.elems + 1
        !! -1;
    my Int:D @a = $node's-cp, $min, $max, $sub_node_elems, $subnode_link, $collation_key_elems, $collation_link;
    say 'subnode: ', @a.perl;
    @sub_nodes.push: @a;
}
my %hash-done;
my @c-cp-array;
multi sub make-sub_node (Cool:D(Int) $cp!, Pair:D $node!) {
    die;
}
multi sub make-sub_node (Cool:D(Int) $prev-cp!, Hash:D $node!) {
    seen-node($node);
    sub dump-node-info (Str:D $description = '')  {
        note "{$description}Hash node: prev-cp: $prev-cp keys elems {$node.keys.elems} keys: {$node.keys.gist}\nvalues elems {$node.values.elems} values: {$node.values.gist}";
    }
    #say '    WHAT: ', $node.WHAT;
    #say "    node.keys: ", $node.keys;
    my @numeric = only-numeric($node.keys);
    my @non-numeric = not-numeric($node.keys);

    #say "    NON NUMERIC: {@non-numeric.perl}" if @non-numeric;
    #say "    NUMERIC: {@numeric.perl}" if @numeric;
    my Int:D $min = @numeric ?? @numeric.min !! -1;
    my Int:D $max = @numeric ?? @numeric.max !! -1;
    my Int:D $sub_node_elems = @numeric.elems;
    # Add the subnode
    $node<array>:exists
        ?? add-sub_node($prev-cp, :$min, :$max, :$sub_node_elems, :subnode_collation_keys($node<array>))
        !! add-sub_node($prev-cp, :$min, :$max, :$sub_node_elems);
    if @numeric {
        say "     Entering \@numeric loop";
        for @numeric.sort -> $node's-cp {
            say "      in \@numeric loop: running ->make-sub_node cp\[$node's-cp\] node\[", $node{$node's-cp}, "\]";
            # Add the nodes below that node
            make-sub_node $node's-cp, $node{$node's-cp};
            CATCH { dump-node-info "FAILURE" }
        }
    }
}
sub only-numeric ($list) {
    my @list = $list.grep(/^<:Numeric>+$/);
    @list = @list».Int;
    @list;
}
sub not-numeric ($list) {
    $list.grep({$_ !~~ /^<:Numeric>+/}).Array;
}
sub seen-node ($node) {
    if $node<array>:exists {
        my $joined = $node<codepoints>.join(',');
        if %hash-done{$joined}:exists {
            die "    i've processed this one before!!!";
        }
        @c-cp-array.push: Pair.new($node<codepoints>, $node<array>);
        %hash-done{$node<codepoints>.join(',')} =  True;
    }
}
# Receives pairs where the key is the main node's codepoint and the value is a hash containing
# the subnodes
sub make-main_node (*@pairs) {
    say "============ Starting make-main_node =============\n\n";
    for @pairs -> $pair {
        say ' pair: ', $pair.perl;
        say ' value: ', $pair.value;
        say ' key: ', $pair.key;
        my Hash:D $node  = $pair.value;
        my Int:D $cp    = $pair.key.Int;
        my Int:D @numeric-keys = only-numeric($node.keys);
        my Int:D $max   = @numeric-keys ?? @numeric-keys.max !! -1;
        my Int:D $min   = @numeric-keys ?? @numeric-keys.min !! -1;
        my Int:D $sub_node_elems = @numeric-keys.elems;
        my Int:D ($collation_link, $collation_key_elems) = $node<array>:exists
            ?? add-collation-keys($node<array>)
            !! (-1,-1);
        seen-node($node);
        my $main-node-c-struct = '{' ~ ($cp, $min, $max, $sub_node_elems, @sub_nodes.elems, $collation_key_elems, $collation_link).join(',') ~ '}';
        @main_nodes.push: $main-node-c-struct;
        for @numeric-keys.sort -> $key {
            my Int:D $cp = $key;
            say '  in make-main_node loop. cp: ', $cp, ' node: ', $node, ' node{key}: ', $node{$key};
            say "  Running make-sub_node from make-main_node loop";
            make-sub_node $cp, $node{$cp};
        }
    }
    return 'main-node-strict' => @main_nodes,
        'sub-nodes' => @sub_nodes,
        'collation-keys' => @collation-keys-array
}
sub compose-the-arrays {
    my @list-of-cp's-to-make-nodes-for;
    my @composed-arrays;
    my %nody = make-main_node (%trie.pairs) #`(119226 => %trie{119226});#, |@list-of-cp's-to-make-nodes-for;
    @composed-arrays.push: "#define main_nodes_elems @main_nodes.elems()";
    @composed-arrays.push: compose-array('sub_node', 'main_nodes', @main_nodes);
    @composed-arrays.push: "#define sub_nodes_elems @sub_nodes.elems()";
    @composed-arrays.push: compose-array( 'sub_node', 'sub_nodes', @sub_nodes);
    @composed-arrays.push: "#define special_collation_keys_elems @collation-keys-array.elems()";
    @composed-arrays.push: compose-array( 'collation_key', 'special_collation_keys', @collation-keys-array);
    my $collation-txt = slurp-snippets('collation', 'head') ~ @composed-arrays.join("\n") ~ slurp-snippets('collation', 'main');
    spurt "source/collation.c", $collation-txt;
    use lib 'lib';
    use ArrayCompose;
    use UCDlib;
    for ^@c-cp-array -> $index {
        say '{' ~ @c-cp-array[$index].key.join(',') ~ '}' ~ '  ' ~ @c-cp-array[$index].value.map({ '[' ~ .join('.') ~ ']'}).join;
    }
    exit;
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
