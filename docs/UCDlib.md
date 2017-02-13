### sub slurp-snippets

```
sub slurp-snippets(
    Str $name, 
    Str $subname?, 
    $numbers?
) returns Mu
```

Slurps files from the snippets folder and concatenates them together The first argument is the folder name inside /snippets that they are in The second argument make it only concat files which contain that string The third argument allows you to request only snippets starting with those numbers if the numbers are positive. If they are negative, it returns all snippets except those numbers. Takes a single number, or a List of numbers
