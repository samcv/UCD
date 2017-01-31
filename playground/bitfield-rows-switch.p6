my %point-index = 1 => 'this', 2 => 'this', 3 => 'that', 4 => 'this';
my $saw = '';
my $i = -1;
my %ranges;
say %point-index.perl;
for %point-index.keys.sort(+*) {
    if $saw eq %point-index{$_} {
        push %ranges{$i}, $_;
        say "Same: ", %point-index{$_}, " i: ", $i
    }
    else {
        $i++;
        say "not same: ", %point-index{$_}, " i: ", $i;
        $saw = %point-index{$_};
        push %ranges{$i}, $_;
    }
}
say %ranges.perl;
