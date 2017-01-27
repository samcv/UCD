use v6;
class Set-Range {
    has %.ranges;
    has $.range-no = 0;
    has %!range-nos;
    has $.highest-point;
    method add-to-range-no ( Cool:D $range-no, Cool:D $first, Cool:D $last, Cool:D $name, @values?) {
        if %!range-nos{$range-no}<name> and %!range-nos{$range-no}<name> ne $name {
            die "Conflicting names {%!range-nos{$range-no}<name>} and $name";
        }
        %!range-nos{$range-no}<first> = $first;
        %!range-nos{$range-no}<last>  = $last;
        %!range-nos{$range-no}<name>  = $name;
        %!range-nos{$range-no}<value> = @values if @values;
    }
    method add-to-range ( Cool:D $point, Cool:D $name, *@values ) is export {
        if $!highest-point.defined && $point <= $!highest-point {
            die "Points must be added in order";
        }
        # If a first point doesn't exist, this is the first point of a new range
        if ! %!range-nos {
            self.add-to-range-no($!range-no, $point, $point, $name, @values);
        }
        elsif %!range-nos{$!range-no}:exists.not {
            self.add-to-range-no($!range-no, $point, $point, $name, @values);
        }
        # if the points are just one off we're part of the same range
        elsif %!range-nos{$!range-no}<last> + 1 == $point {
            %!range-nos{$!range-no}<last> = $point;
        }
        # Otherwise it's part of a new range
        else {
            $!range-no++;
            self.add-to-range-no($!range-no, $point, $point, $name, @values);
        }
    }
    method get-range { %!range-nos       }
    method elems     { %!range-nos.elems }
    method generate-c ( Str:D $varname) {
        my $string;
        my $indent = "\c[SPACE]" x 4;
        for ^self.get-range.elems -> $elem {
            my ($return, $code);
            if self.get-range{$elem}<value>.elems > 1 {
                $return = self.get-range{$elem}<value>.pop;
                $code = self.get-range{$elem}<value>.join("\n$indent");
                $code = $code ~ "\n"  ~ $indent ~ "return " ~ $return;
            }
            else {
                $return = self.get-range{$elem}<value>.pop;
                $code = "return " ~ $return;
            }
            $string ~= qq:to/END/;
            // {self.get-range{$elem}<name>}
            if ($varname >= {self.get-range{$elem}<first>} && $varname <= {self.get-range{$elem}<last>}) \{
                $code;
            \}
            if ($varname > {self.get-range{$elem}<last>})
                return {self.get-range{$elem}<last> + 1};
            END
        }
        $string;
    }
}
