use File::Copy;
use Test::More tests => 13;

my $original = 't/test.dat';
my $file     = 't/test_remove.dat';

BEGIN { 
    use_ok( 'File::SAUCE' );
}

open( FILE, $original );
my $data = do { local $/; <FILE> };
close( FILE );

my $sauce = File::SAUCE->new( $data, 1 );

isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 1, 'Raw data read OK' );

$data  = $sauce->remove( $data, 1 );
$sauce = File::SAUCE->new( $data, 1 );

isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 0, '$sauce->remove (raw data) successful' );

copy( $original, $file ) or die $!;

open( FILE, "+<$file" ) or die $!;

$sauce = File::SAUCE->new( \*FILE );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 1, 'Filehandle read OK' );

$sauce->remove( \*FILE );

$sauce = File::SAUCE->new( \*FILE );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 0, '$sauce->remove (filehandle) successful' );

close( FILE ) or die $!;

unlink( $file ) or die $!;

copy( $original, $file ) or die $!;

$sauce = File::SAUCE->new( $file );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 1, 'File read OK' );

$sauce->remove( $file );

$sauce = File::SAUCE->new( $file );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );
is( $sauce->has_sauce, 0, '$sauce->remove (filename) successful' );

unlink( $file ) or die $!;
