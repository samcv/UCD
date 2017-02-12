#!/usr/bin/env perl6
use v6;
use Test;
use nqp;
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
#is-deeply $one_o.join(","), "13018,9489,31881,59980,29174,12720";
my $two_o = base40-string.new;
$two_o.set-shift-level-one(@array);
$two_o.push('RIGHT');
say $two_o.done;
is $two_o.join(','), 63280;
#say $two_o.join(',');
#`{{
#is $one_o.elems, 6;
#say $one.perl;
my @p6_one;
nqp::while(nqp::elems($one) != 0, (
    @p6_one.push(nqp::shift_s($one))
));

my $i = 0;
my %hash;
for @array {
    %hash{$_} = $i++;
}
#i  nit-shift-hashes(@array);
$string = "PLUS";
my $two := encode-base40-string($string);
my @p6_two;
nqp::while(nqp::elems($two), (
    @p6_one.push(nqp::shift_s($two))
));
#say @two.perl ~ "XXX";
is decode-base40-nums(@p6_two), $string, "'$string' can be round-tripped with shift set, when it's the last shift value";
$string = "CAPITAL";
is decode-base40-nums(encode-base40-string($string)), $string, "'$string' can be round-tripped with shift set, it's the last shift value";
done-testing;
}}
