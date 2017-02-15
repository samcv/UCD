use Test;
use lib '.';
use experimental :collation;
{
    my $c = Collation.new;
    is $c.collation-level, 15, "15 is default collation-level";
    is $c.primary, True, "primary is default";
    is $c.secondary, True, "secondary is default";
    is $c.tertiary, True, "tertiary is default";
    is $c.quaternary, True, "tetriary is default";
}
{
    my $c = Collation.new(collation-level => 1);
    is $c.collation-level, 1;
    is $c.primary, True;
    is $c.secondary, False;
    is $c.tertiary, False;
    is $c.quaternary, False;
}
{
    my $c2 = Collation.new;
    is $c2.primary, True;
    is $c2.collation-level, 15;
    $c2.set(:primary(False));
    is $c2.collation-level, 14;
}
done-testing;
