use Test::More tests => 7;

my $file = 't/test_write.dat';

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my $sauce;

# raw data...
$sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

my $out;

$out = $sauce->write( $out, 1 );

$sauce = File::SAUCE->new( $out, 1 );

is( $sauce->has_sauce, 1, '$sauce->write (raw data) OK' );


# filehandle ...
open( FILE, "+>$file" ) or die $!;

$sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

$sauce->write( \*FILE );

close( FILE );

$sauce = File::SAUCE->new( $file );

is( $sauce->has_sauce, 1, '$sauce->write (filehandle) OK' );

# filename
open( FILE, ">$file" ) or die $!;
close( FILE );

$sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

$sauce->write( $file );

$sauce = File::SAUCE->new( $file );

is( $sauce->has_sauce, 1, '$sauce->write (filehandle) OK' );

unlink( $file ) or die $!;