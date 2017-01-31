sub packer (@nums is copy, Bool :$debug = False, Bool :$visual = False) is export {
    my $bytes = 0;
    my $yet = 0;
    my $bitsize = 8;
    my $i;
    my $visual-str;
    my @push;
    while @nums {
        my $next = @nums.shift;
        my $i = 0;
        say "Yet: $yet curr $next" if $debug;
        repeat while 0 >= $bitsize {
            say "$i iteration" if $debug;
            if $yet + $next < $bitsize {
                say "less" if $debug;
                $visual-str ~= $next;
                $yet += $next;
            }
            elsif $yet + $next == $bitsize {
                say "equal" if $debug;
                $bytes++;
                $visual-str ~= $next ~ '|';
                $yet = 0;
            }
            else {
                say "greater" if $debug;
                $bytes++;
                $yet = $next;
                $visual-str ~= '|';
                $visual-str ~= $next;
            }
        }
    }
    if $yet > 0 {
        say "final yet($yet) $bytes" if $debug;
        $bytes++;
        $yet = 0;
        $visual-str ~= '|';
    }
    say $yet if $debug;
    say "Bytes $bytes Visual [$visual-str]" if $visual;
    $bytes;
}
sub test {
    my @nums_ = 1, 7, 3,     4, 4,     5, 2;
    my @n = 7,7,7,7,1,1, 16;
    my @n2 = 7,4,4,3,3,2,1, 1;

    say packer(@n);
}
