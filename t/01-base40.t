#!/usr/bin/env perl6
use v6;
use Test;
use lib 'lib';
use EncodeBase40;
my $string = 'HERE IS A STRING-';
my @one = encode-base40-string($string);
#say @one.perl;
is @one.elems, ($string.chars/3).ceiling, "'$string' with shift set returns {($string.chars/3).ceiling} elements";

is decode-base40-nums(@one), $string, "'$string' can be round tripped with no shift";
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
my @two = encode-base40-string($string);
#say @two.perl ~ "XXX";
is decode-base40-nums(@two), $string, "'$string' can be round-tripped with shift set, when it's the last shift value";
$string = "CAPITAL";
is decode-base40-nums(encode-base40-string($string)), $string, "'$string' can be round-tripped with shift set, it's the last shift value";
done-testing;
