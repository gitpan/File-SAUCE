use Test::More tests => 3;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my $date = '20031207';

my $expected = 'M&E-!54-%,#`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@' . "\n" .
'M("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`R,#`S,3(P' . "\n" .
'G-P`````````````````````@("`@("`@("`@("`@("`@("`@("`@' . "\n";

my $sauce = File::SAUCE->new;
$sauce->set_date( $date );

my $out   = $sauce->as_string;

is( length( $out ), 129, 'length( $sauce->as_string )' );

$out = pack 'u*', $out;

is( $out, $expected, '$sauce->as_string' );