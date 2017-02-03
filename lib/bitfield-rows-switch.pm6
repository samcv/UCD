sub get-points-ranges (%point-index) is export {
    my %ranges;
    my $saw = '';
    my $i = -1;
    for %point-index.keys.sort(+*) {
        $saw eq %point-index{$_}
        ?? do { push %ranges{$i}, $_     }
        !! do { $saw = %point-index{$_};
                push %ranges{++$i}, $_ ; }
    }
    %ranges;
}
sub test-it {
    my %point-index = 1 => 'this', 2 => 'this', 3 => 'that', 4 => 'this';
    my %ranges = get-points-ranges(%point-index);
    say now - INIT now;
    say %ranges.sort(*.key.Int);
}
