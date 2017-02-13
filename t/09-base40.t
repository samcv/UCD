#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use EncodeBase40;

my @array = "CAPITAL","LETTER","LATIN","DIGIT","PARENTHESIS","SIGN","SMALL",
"BRACKET","SOLIDUS","HYPHEN-MINUS","GREATER-THAN","EXCLAMATION","SQUARE",
"ACCENT","COMMERCIAL","CIRCUMFLEX","APOSTROPHE","MARK","QUOTATION","AMPERSAND",
"SEMICOLON","LESS-THAN","RIGHT","QUESTION","ASTERISK","PERCENT","REVERSE",
"LEFT","EQUALS","NUMBER","DOLLAR","COLON","COMMA","SEVEN","EIGHT","SPACE",
"GRAVE","THREE","LINE","PLUS";

my $string = 'HERE IS A STRING-';
my $one_o = base40-string.new;
$one_o.push($string);
is-deeply $one_o.join(","), "13018,9489,31881,59980,29174,12720";

my $two_o = base40-string.new;
$two_o.set-shift-level-one(@array);
$two_o.push('RIGHT');
$two_o.done;
is-deeply $two_o.join(','), '63280';

my base40-string $three_o .= new(set-shift-level-one => @array);
$three_o.push("PLUS");
is-deeply $three_o.join(','), '26101';

my base40-string $four_o .= new(set-shift-level-one => @array);
$four_o.push("PLUS");
$four_o.done;
is-deeply $four_o.join(','), '26101';
is-deeply $four_o.encoded-str.ords, (80, 76, 85, 83, 0).Seq;

$four_o.push("BLAHCOLON");
# Possibly incorrect result, but adding to catch any changes
is-deeply $four_o.join(','), "26101,3681,12935,19814";
is-deeply $four_o.encoded-str.ords, (80, 76, 85, 83, 0, 66, 76, 65, 72, 67, 79, 76, 79, 78, 0).Seq;
done-testing;
