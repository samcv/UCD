use UCDlib;
sub compose-array ( Str:D $type, Str:D $name, Cool:D $elems,
                    Str:D $body, Bool :$header = False ) is export {

    if $header {
        $type ~ " $name\[" ~ $elems ~ '];';
    }
    else {
        ($type,
        " $name\[" ~ $elems ~ '] = {' ~ "\n",
        break-into-lines($body, ','),
        '};',
        "\n").join;
    }
}

sub break-into-lines (Str $string, Str $breakpoint) {
    my $copy = $string;
    $copy ~~ s:g/(.**70..79 $breakpoint)/$0\n/;
    return $copy;
}
