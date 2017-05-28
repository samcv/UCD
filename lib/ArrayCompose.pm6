use UCDlib;
multi compose-array ( Str:D $type, Str:D $name, Cool:D $elems,
                      Str:D $body, Bool :$header = False, Str:D :$delim = ',' ) is export {
    if $header {
        "#define {$name}_elems $elems" ~ "\n" ~ $type ~ " $name\[" ~ $elems ~ '];';
    }
    else {
        ($type,
        " $name\[" ~ $elems ~ '] = {' ~ "\n",
        break-into-lines($body, $delim),
        '};',
        "\n").join;
    }
}
multi compose-array (
    Str:D $type,
    Str:D $name,
    @body where { all($_ Z~~ any(Str, Int), *) },
    Bool :$header = False,
    Str:D :$delim = ','
) is export {
    say "Composing array [$name] type: $type";
    if $type.contains('char *') {
        return compose-array($type, $name, @body.elems, '"' ~ @body.join('","') ~ '"', :header($header), :$delim);
    }
    elsif $type.contains('char') {
        # Use a null char to denote empty items since you can't have an empty
        # char in C
        $_ = '\0' if $_ eq '' for @body;
        return compose-array($type, $name, @body.elems, ｢'｣ ~ @body.join(｢','｣) ~ ｢'｣, :header($header), :$delim);
    }
    compose-array($type, $name, @body.elems, @body.join(','), :header($header), :$delim);
}
multi compose-array (
    Str:D $type,
    Str:D $name,
    @body where { .all ~~ Positional },
    Bool :$header = False,
    Str:D :$delim = ','
) is export {
    compose-array($type, $name, @body.map({ '{' ~ .map({ $_ ~~ Str ?? “"$_"” !! $_}).join(',') ~ '}' }), :$header, :$delim);
}

sub break-into-lines (Str $string, Str $breakpoint) {
    my $copy = $string;
    $copy ~~ s:g/(.**70..79 $breakpoint)/$0\n/;
    return $copy;
}
