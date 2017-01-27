multi sub prefix:< ¿ > ( Str $str ) is export { $str.defined and $str ne '' ?? True !! False }
multi sub prefix:< ¿ > ( Bool $bool ) { $bool.defined and $bool != False }

sub infix:< =? > ($left is rw, $right) is export { $left = $right if ¿$right }
sub infix:< ?= > ($left is rw, $right) is export { $left = $right if ¿$left }
