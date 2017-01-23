use v6;
class Set-Range {
    has %.ranges;
    has $.range-no = 0;
    has %!range-nos;
    has $.highest-point;
    method add-to-range ( Cool:D $point, Cool:D $item ) is export {
        if $!highest-point.defined && $point <= $!highest-point {
            die "Points must be added in order";
        }
        # If a first point doesn't exist, this is the first point of a new range
        if ! %!range-nos {
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
            %!range-nos{$!range-no}<name> = $item;
        }
        elsif %!range-nos{$!range-no}:exists.not {
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
            %!range-nos{$!range-no}<name> = $item;
        }
        # if the points are just one off we're part of the same range
        elsif %!range-nos{$!range-no}<last> + 1 == $point {
            die "Conflicting names {%!range-nos{$!range-no}<name>} and $item" if %!range-nos{$!range-no}<name> ne $item;
            %!range-nos{$!range-no}<last> = $point;
        }
        # Otherwise it's part of a new range
        else {
            $!range-no++;
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
            %!range-nos{$!range-no}<name> = $item;
        }
    }
    method get-range {
        %!range-nos;
    }
}
