use v6;
class Set-Range {
    has %.ranges;
    has $.range-no = 0;
    has %!range-nos;
    has $.highest-point;
    method add-to-range ( Cool:D $point ) is export {
        if $!highest-point.defined && $point <= $!highest-point {
            die "Points must be added in order";
        }
        # If a first point doesn't exist, this is the first point of a new range
        if ! %!range-nos {
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
        }
        elsif %!range-nos{$!range-no}:exists.not {
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
        }
        # if the points are just one off we're part of the same range
        elsif %!range-nos{$!range-no}<last> + 1 == $point {
            %!range-nos{$!range-no}<last> = $point;
        }
        # Otherwise it's part of a new range
        else {
            $!range-no++;
            %!range-nos{$!range-no}<first> = $point;
            %!range-nos{$!range-no}<last> = $point;
        }
    }
    method get-range {
        %!range-nos;
    }
}
