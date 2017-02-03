constant $debug = False;
sub get-points-ranges (%point-index) is export {
    my %ranges;
    my $saw = '';
    my $i = -1;
    my $point-no = -1;
    my @keys = %point-index.keys.sort(+*);
    for ^@keys.elems -> $elem {
        my $cp = @keys[$elem];
        say "start point-no: $point-no key $cp" if $debug;
        $point-no++;

        if $cp != $point-no {
            say "missing one" if $debug;
            say "next one is ", @keys[$elem] if $debug;
            my $between = @keys[$elem] - $point-no;
            say "Between this and the next one there are ", $between if $debug;
            $i++;
            if $between == 1 {
                push %ranges{$i}, $point-no;
            }
            else {
                my $range = Range.new($point-no, $point-no + $between - 1);
                say $range if $debug;
                for $range.lazy {
                    say $_ if $debug;
                    push %ranges{$i}, $_;
                }
            }
            $point-no += $cp - $point-no;
        }
        if $saw eq %point-index{$cp} {
            push %ranges{$i}, $cp;
        }
        else {
            $saw = %point-index{$cp};
            push %ranges{++$i}, $cp ;
        }
    }
    %ranges;
}
sub test-it {
    my %point-index = 1 => 'test', 2 => 'this', 2 => 'this', 3 => 'that', 4 => 'this', 5 => 'this', 6 => 'that', 7 => 'that';
    my %points-ranges = get-points-ranges(%point-index);
    say %points-ranges;
    my @range-str;
    my $min-elems = 1;
    my $indent = '';
    say %points-ranges.perl;
    for %points-ranges.sort(*.key.Int) {
        my $range-no = .key;
        my $range = .value;
        say "range-no ", $range-no;
        say "range[0] ", $range[0];
        my $diff = $range[*-1] - $range[0];
        if %point-index{$range[0]}:exists {
            if $range.elems > $min-elems {
                @range-str.push: $indent ~ 'if (cp >= ' ~ $range[0] ~ ') {';
                $indent ~= ' ';
                @range-str.push( $indent ~ 'return_val += ' ~ $diff ~ ';') unless $diff == 0;
                @range-str.push: $indent ~ 'if (cp <= ' ~ $range[*-1] ~ ')';
                @range-str.push: $indent ~ '  ' ~ 'return ' ~ %point-index{$range[0]} ~ ';';
            }
        }
        else {
            say "donet exist";
            @range-str.push: $indent ~ 'if (cp >= ' ~ $range[0] ~ ') {';
            $indent ~= ' ';
            @range-str.push( $indent ~ 'return_val += ' ~ $diff ~ ';') unless $diff == 0;
            @range-str.push: $indent ~ 'if (cp <= ' ~ $range[*-1] ~ ')';
            @range-str.push: $indent ~ '  ' ~ 'return BITFIELD_DEFAULT;';
        }
    }
    while $indent.chars {
        $indent = ' ' x $indent.chars - 1;
        @range-str.push: $indent ~ '}';
    }
    say "Range str: \n", @range-str.join("\n");
    say now - INIT now;

}
test-it;
