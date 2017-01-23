#!/usr/bin/env perl6
use v6;
use Test;
todo 4, "Needs rework";
use nqp;
use lib 'lib';
use EncodeBase40;
my $string = 'HERE IS A STRING-';
my $one := encode-base40-string($string);
my $one_o := base40-string.new;
$one_o.push($string);
#is $one_o.elems, 6;
#say $one.perl;
is nqp::elems($one), ($string.chars/3).ceiling, "'$string' with shift set returns {($string.chars/3).ceiling} elements";
my @p6_one;
nqp::while(nqp::elems($one) != 0, (
    @p6_one.push(nqp::shift_s($one))
));
is decode-base40-nums(@p6_one), $string, "'$string' can be round tripped with no shift";
my @array = "CAPITAL","LETTER","LATIN","DIGIT","PARENTHESIS","SIGN","SMALL","BRACKET","SOLIDUS",
"HYPHEN-MINUS","GREATER-THAN","EXCLAMATION","SQUARE","ACCENT","COMMERCIAL","CIRCUMFLEX",
"APOSTROPHE","MARK","QUOTATION","AMPERSAND","SEMICOLON","LESS-THAN","RIGHT","QUESTION",
"ASTERISK","PERCENT","REVERSE","LEFT","EQUALS","NUMBER","DOLLAR","COLON","COMMA","SEVEN",
"EIGHT","SPACE","GRAVE","THREE","LINE","PLUS";
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
