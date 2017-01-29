use v6;
class seen-words is export {
    has $.saved-bytes;
    has %.seen-words;
    my @shift-one-array;
    has %shift-one;
    has %seen-words-shift-one;
    has %seen-words-shift-two;
    has %seen-words-shift-three;
    has Int $.longest-name = 0;


    has $.levels-to-gen = 0;
    method saw-line ( Str:D $line ) {
        for $line.split([' ', '-']) {
            %!seen-words{$_}++;
            %seen-words-shift-one{$_} += (.chars * 2/3) - 2/3 * 2; # Calculate how much we save if we shorten it
            %seen-words-shift-two{$_} += (.chars * 2/3) - 2/3 * 3; # for first and second shifts
            %seen-words-shift-three{$_} += (.chars * 2/3) - 2/3 * 4;
        }
        $!longest-name = $line.chars if $line.chars > $!longest-name;
    }
    method get-shift-one {
        if !%shift-one {
            my $i = 0;
            for %seen-words-shift-one.sort(-*.value) {
                @shift-one-array.push(.key);
                %!shift-one{.key} = $i;
                $!saved-bytes += .value;
                $i++;
                last if $i >= 40;
            }
            note "Can save: " ~ $!saved-bytes / 1000 ~ " KB with first shift level";
        }
        return %shift-one;
    }
    method get-shift-one-array {
        self.get-shift-one;
        return @shift-one-array;
    }

}
