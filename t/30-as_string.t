use Test::More tests => 3;

BEGIN { 
    use_ok( 'File::SAUCE' );
}
my( $mday, $mon, $year ) = ( localtime( time ) )[ 3, 4, 5 ];
my $today = sprintf( '%4d%02d%02d', $year += 1900, ++$mon, $mday );

my $expected = 'M&E-!54-%,#`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@' . "\n" .
'M("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`R,#`S,3$S' . "\n" .
'G,``````````````````````@("`@("`@("`@("`@("`@("`@("`@' . "\n";

my $sauce = File::SAUCE->new;
my $out   = $sauce->as_string;

is( length( $out ), 129, 'length( $sauce->as_string )' );

$out = pack 'u*', $out;

is( $out, $expected, '$sauce->as_string' );