use Test::More tests => 4;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my $sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

my $lt   = '1070891287';
my $date = '20031208';

is( $sauce->convert_localtime( $lt ), $date, '$sauce->convert_localtime' );

$sauce->set_date( '' );
$sauce->auto_date;

is( $sauce->get_date, $sauce->convert_localtime, '$sauce->auto_date' );
