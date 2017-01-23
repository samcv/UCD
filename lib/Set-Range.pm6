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
            %!range-nos{$item}{$!range-no}<first> = $point;
            %!range-nos{$item}{$!range-no}<last> = $point;
        }
        elsif %!range-nos{$item}{$!range-no}:exists.not {
            %!range-nos{$item}{$!range-no}<first> = $point;
            %!range-nos{$item}{$!range-no}<last> = $point;
        }
        # if the points are just one off we're part of the same range
        elsif %!range-nos{$item}{$!range-no}<last> + 1 == $point {
            %!range-nos{$item}{$!range-no}<last> = $point;
        }
        # Otherwise it's part of a new range
        else {
            $!range-no++;
            %!range-nos{$item}{$!range-no}<first> = $point;
            %!range-nos{$item}{$!range-no}<last> = $point;
        }
    }
    method get-range {
        %!range-nos;
    }
}
