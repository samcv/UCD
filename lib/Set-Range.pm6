use v6;
INIT print '.';
class Set-Range {
    has %.ranges;
    has $.range-no = 0;
    has %!range-nos;
    has $.highest-point;

    method add-to-range-no ( Cool:D $range-no, Cool:D $first, Cool:D $last, Cool:D $name, Cool $value?) {
        if %!range-nos{$range-no}<name> and %!range-nos{$range-no}<name> ne $name {
            die "Conflicting names {%!range-nos{$range-no}<name>} and $name";
        }
        %!range-nos{$range-no}<first> = $first;
        %!range-nos{$range-no}<last>  = $last;
        %!range-nos{$range-no}<name>  = $name;
        %!range-nos{$range-no}<value> = $value if $value;
    }
    method add-to-range ( Cool:D $point, Cool:D $item, Cool $value? ) is export {
        if $!highest-point.defined && $point <= $!highest-point {
            die "Points must be added in order";
        }
        # If a first point doesn't exist, this is the first point of a new range
        if ! %!range-nos {
            self.add-to-range-no($!range-no, $point, $point, $item, $value);
        }
        elsif %!range-nos{$!range-no}:exists.not {
            self.add-to-range-no($!range-no, $point, $point, $item, $value);
        }
        # if the points are just one off we're part of the same range
        elsif %!range-nos{$!range-no}<last> + 1 == $point {
            %!range-nos{$!range-no}<last> = $point;
        }
        # Otherwise it's part of a new range
        else {
            $!range-no++;
            self.add-to-range-no($!range-no, $point, $point, $item, $value);
        }
    }
    method get-range { %!range-nos       }
    method elems     { %!range-nos.elems }
}
sub set-range-generate-c ( Set-Range $sr, Str:D $varname ) is export {
    my $string;
    for ^$sr.get-range.elems -> $elem {
        $string ~= qq:to/END/;
        // {$sr.get-range{$elem}<name>}
        if ($varname >= {$sr.get-range{$elem}<first>} && $varname <= {$sr.get-range{$elem}<last>})
            return {$sr.get-range{$elem}<value>};
        END
    }
    $string;
}
