use lib 'Unicode-Grant/lib';
use PropertyAliases;
use Test;
my $TODO = <kOtherNumeric General_Category Bidi_Paired_Bracket_Type Numeric_Value kPrimaryNumeric kAccountingNumeric kOtherNumeric>;
is GetPropertyAliasesLookupHash<WSpace>, 'White_Space';
is GetPropertyAliasesList.elems, 468;
is GetPropertyAliasesList.keys.sort.unique.elems, GetPropertyAliasesList.keys.elems, "no repeat elements";
is GetPropertyAliasesList.grep({ $_ ~~ /:i space$/ and $_ !~~ /:i pattern/ }).any, all('White_Space', 'space','WSpace');
#done-testing;
use PropertyValueAliases;
use experimental :collation;
say GetPropertyAliasesRevLookupHash.elems; #.keys.sort(&[unicmp]);
say GetPropertyAliasesLookupHash.elems;
say GetPropertyAliases<short>.elems;
say GetPropertyAliasesLookupHash.elems;
say GetPropertyValueLookupHash.elems;
my %hash = GetPropertyValueLookupHash(:!use-short-pnames);

for %hash.keys {
    my $query =  %hash{$_}[0][0];
    next if $query.starts-with('<');
    todo("todo $_", 1), if $_ eq $TODO.any;
    my $cmd = run './build/property-value-c-array', $_, $query, :out, :err;
    #"Prop $_ Query $query".say;
    my @lines = $cmd.out.slurp.lines;
    is @lines.elems, 2, "Prop $_ Query $query";
}
done-testing;
exit;
{
    #plan 1;
    my %hash = GetPropertyValueLookupHash;
    for %hash.keys {
        # skip int properties
        next if %hash{$_} !~~ Positional;
        is %hash{$_}.WHAT.gist, '(Array)', "pname: '$_' is an Array";
        for ^%hash{$_}.elems -> $t {
            is %hash{$_}[$t].WHAT.gist, '(Array)', "pname: '$_' pvalue: '{%hash{$_}[$t].perl}' is an Array";
        }
        ok %hash{$_}.elems >= 2, "pname: '$_' pvalues: {%hash{$_}.perl}";
        ok %hash{$_}».elems.all >= 2, "pname: '$_' each of the elements have 2 or more elems";
    }
}
is-deeply %hash<Script_Extensions>, %hash<Script>, "Script and Script_Extensions have the same value";
done-testing;
