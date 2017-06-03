my $unsorted-todo = <Jamo_Short_Name kOtherNumeric General_Category
            Bidi_Paired_Bracket_Type Numeric_Value kPrimaryNumeric
            kAccountingNumeric kOtherNumeric>;
my $codepoint-value-props = <Case_Folding Bidi_Mirroring_Glyph Bidi_Paired_Bracket>;
sub TODO_P_ALIAS is export {
    state $a =($unsorted-todo, $codepoint-value-props).flat.list;
    $a;
}
#        :internal-pvalue-code-sort-order = short meaning they sort using the short property value names
#   unless otherwise specified
my %null-pvalue =
'East_Asian_Width' => %(
    :null-pvalue('N'),
),
'Numeric_Type' => 'None',
'Grapheme_Cluster_Break' => 'Other',
'Jamo_Short_Name' => '',
'Bidi_Class' => 'L',
'Joining_Group' => 'No_Joining_Group',
'Joining_Type'=> 'Non_Joining',
'Word_Break'=> 'Other',
'Line_Break'=> 'XX',
;
