use Test::More tests => 5;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my $date = '20031207';

my $expected = 'M&E-!54-%,#`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@' . "\n" .
'M("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`@("`R,#`S,3(P' . "\n" .
'G-P`````````````````````@("`@("`@("`@("`@("`@("`@("`@' . "\n";

my $sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

$sauce->set_date( $date );
is( $sauce->get_date, $date, 'Date set OK' );

my $out = $sauce->as_string;

is( length( $out ), 129, 'length( $sauce->as_string )' );

$out = pack 'u*', $out;

is( $out, $expected, '$sauce->as_string' );