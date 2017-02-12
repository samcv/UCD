constant $debug = False;
sub get-points-ranges (%point-index) is export {
    my %ranges;
    my $saw = '';
    my int $i = -1;
    my int $point-no = -1;
    %ranges<0> = [];
    for %point-index.keys.sort(*.Int) -> $cp {
        #say "start point-no: $point-no key $cp" if $debug;
        $point-no++;
        if $cp != $point-no {
            #say "missing one" if $debug;
            #say "next one is ", @keys[$elem] if $debug;
            my $between = $cp - $point-no;
            #say "Between this and the next one there are ", $between if $debug;
            $i++;
            if $between == 1 {
                %ranges{$i}.push: $point-no;
            }
            else {
                #say $range if $debug;
                for ($point-no)..($point-no + $between - 1) {
                    #say $_ if $debug;
                    %ranges{$i}.push: $_;
                }
            }
            $point-no += $cp - $point-no;
        }
        if $saw eq %point-index{$cp} {
            %ranges{$i}.push: $cp;
        }
        else {
            $saw = %point-index{$cp};
            %ranges{++$i} = [];
            %ranges{$i}.push($cp);
            #push %ranges{++$i}, $cp ;
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
