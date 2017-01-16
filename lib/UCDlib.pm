use v6;
use MONKEY-TYPING;
use Data::Dump;
use nqp;
INIT say "Compiling UCDlib.pm";
augment class Str {
    multi method split-trim ( Str $delimiter, Int $limit? ) {
        $limit ?? self.split($delimiter, $limit).».trim
               !! self.split($delimiter).».trim;
    }
    multi method split-trim ( Regex $regex, Int $limit? ) {
        $limit ?? self.split($regex, $limit).».trim
               !! self.split($regex).».trim;
    }
}
sub Dump-Range ( Range $range, Hash $hashy ) is export {
    for $range.lazy -> $point {
        say $point;
        say Dump($hashy{$point}) if $hashy{$point}:exists;
    }
}
sub reverse-hash-int-only ( Hash $hash ) is export {
    my %new-hash{Int};
    for $hash.keys {
        %new-hash{$hash{$_}} = $_ if $hash{$_} ~~ Int and $_ ne any('bitwidth', 'name');
    }
    return %new-hash;
}
sub compute-type ( Int $max, Int $min = 0 ) is export {
    say "max: $max, min: $min";
    die "Not sure how to handle min being higher than max. Min: $min, Max: $max" if $min.abs > $max;
    my $size = $max.base(2).chars / 8;
    if $size < 1 {
        return $min >= 0 ?? "unsigned char" !! 'short';
    }
    elsif $size <= 2 {
        return $min >= 0 ?? 'unsigned short' !! 'int';
    }
    elsif $size <= 4 {
        return $min >= 0 ?? 'unsigned int' !! 'long int';
    }
    elsif $size <= 8 {
        return $min >= 0 ?? 'unsigned long int' !! 'long long int';
    }
    else {
        die "Size is $size. Not sure what to do";
    }
}
#`{{
sub NYI {
our %sizes =
    'MVMGrapheme32' => 32/8,
    'MVMint16'      => 16/8,
    'char *'        => 64/8;
#static struct UnicodeBlock unicode_blocks[] = {
my %hash =
    'name2' => 'char *',
    'name' => 'char *',
    'codepoint' => 'MVMGrapheme32',
    'codepoint2' => 'MVMGrapheme32',
    'strlen', 'MVMint16';
gen-struct('static struct', 'MVMUnicodeNamedAlias', 'uni_namealias_pairs', %hash);
my $align-size = 8;
sub gen-struct ( Str $c-type, Str $struct-type, Str $name, Hash $hash ) {
    my @items;
    my %things;
    my $set;
    for $hash.kv -> $name, $type {
        if !%sizes{$type} {
            die "NYI";
        }
        my $size = %sizes{$type};
        #$set = $set ∪ set($name => %sizes{$type});
        push %things{$size}, $name => $hash{$name};
        say "$type $name is $size bytes long";
    }
    %things.perl.say;
    #say $set;
    #exit;
    #say Dump %things, :gist;
    my %pushed;
    for %things.keys.sort.reverse -> $bytes {
        %things.perl.say;
        say "doing bytes $bytes";
        # We don't have to try and pack anything divisible by 8
        if $bytes % 8 == 0 {
            for %things{$bytes} {
                say $_;
                say "pushing thing $bytes";
                @items.push($_);
            }
            if %things{$bytes}.elems == 0 {
                %things{$bytes}:delete;
            }
        }
        elsif $bytes % 4 == 0 {
            say  %things{$bytes}.elems.perl;
            #die %things{$bytes};
        }
        elsif $bytes % 2 == 0 {
            note "NYI bytes $bytes";
        }
    }
    say Dump @items, :gist;
}
}}
