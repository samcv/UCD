constant $debug = False;
use nqp;
#| Makes a hash where the keys "range numbers". These range numbers start at 0
#| and we push onto each range number all of the contiguous codepoints which
#| have the same bitfield row. We also fill in any gaps and add those to their
#| own range number.
sub get-points-ranges (%point-index) is export {
    my %ranges;
    my $saw = '';
    my int $i = -1;
    my int $point-no = -1;
    %ranges<0> = [];
    for %point-index.keys.sort(*.Int) -> $cp {
        $point-no++;
        # This code path is taken if there are noncontiguous gaps in the ranges.
        # We populate the ranges hash with these missing values.
        if $cp != $point-no {
            my $between = $cp - $point-no;
            $between == 1
            ?? %ranges{++$i}.push: $point-no
            !! %ranges{++$i}.append: ($point-no)..($point-no + $between - 1);
            $point-no += $cp - $point-no;
        }
        if $saw eq nqp::atkey(%point-index, $cp) {
            %ranges{$i}.push: $cp;
        }
        else {
            $saw = nqp::atkey(%point-index, $cp);
            %ranges{++$i} = [];
            %ranges{$i}.push($cp);
        }
    }
    %ranges;
}
