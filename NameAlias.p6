my $folder = "UNIDATA";
my $names = slurp "$folder/NameAliases.txt";
my $test-file;
my $count = 0;
my %points;
for $names.lines {
    next if .starts-with('#') or .match(/^\s*$/);
    my @parts = .split(';');
    #say @parts.perl;
    my $cp = @parts[0];
    my $alias = @parts[1];
    my $type = @parts[2];
    %points{$cp.parse-base(16)}<NameAlias>{$alias}<type> = $type;
    $count++;
    $test-file ~= qq{is Uni.new(0x$cp).Str, "\\c[$alias]", '"\\c[$alias]" returns $cp.uniname()';\n};
}
$test-file = "use Test;\nplan $count;\n" ~ $test-file;
say dd %points;
