my %point-index = 1 => 'this', 2 => 'this', 3 => 'that', 4 => 'this';
my $saw = '';
my $i = -1;
my %ranges;
use nqp;
#say %point-index.perl;
for ^1000 {
    for %point-index.keys.sort(+*) {
        $saw eq %point-index{$_}
        ?? do { push %ranges{$i}, $_     }
        !! do { $saw = %point-index{$_};
                push %ranges{++$i}, $_ ; }
    }
}
say %ranges.sort(*.key.Int);
say now - INIT now;
#say %ranges.perl;
#`{{
if $saw eq %point-index{$_} {
    push %ranges{$i}, $_;
    #say "Same: ", %point-index{$_}, " i: ", $i
}
else {
    $i++;
    #say "not same: ", %point-index{$_}, " i: ", $i;
    $saw = %point-index{$_};
    push %ranges{$i}, $_;
}
}}
