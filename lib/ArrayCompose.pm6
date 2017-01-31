use UCDlib;
multi compose-array ( Str:D $type, Str:D $name, Cool:D $elems,
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
multi compose-array
    ( Str:D $type, Str:D $name, @body, Bool :$header = False ) is export {
    say "Composing array [$name] type: $type";
    if $type.contains('char *') {
        say "Choosing char *";
        return compose-array($type, $name, @body.elems, '"' ~ @body.join('","') ~ '"', :header($header));
    }
    elsif $type.contains('char') {
        say "choosing char";
        # Use a null char to denote empty items since you can't have an empty
        # char in C
        $_ = '\0' if $_ eq '' for @body;
        return compose-array($type, $name, @body.elems, ｢'｣ ~ @body.join(｢','｣) ~ ｢'｣, :header($header));
    }
    compose-array($type, $name, @body.elems, @body.join(','), :header($header));
}
sub break-into-lines (Str $string, Str $breakpoint) {
    my $copy = $string;
    $copy ~~ s:g/(.**70..79 $breakpoint)/$0\n/;
    return $copy;
}
