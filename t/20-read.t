use Test::More tests => 73;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my %fields = (
	sauce_id       => 'SAUCE',
	version        => '00',
	title          => 'Test Title',
	author         => 'Test Author',
	group          => 'Test Group',
	date           => '20031127',
	filesize       => 0,
	datatype       => 1,
	filetype       => 0,
	tinfo1         => 1,
	tinfo2         => 1,
	tinfo3         => 0,
	tinfo4         => 0,
	flags          => 0,
	filler         => ' ' x 22,
	comnt_id       => 'COMNT',
	sauce_comments => 1
);

my $bogus      = 't/bogus.dat';
my $bogus_long = 't/bogus_long.dat';
my $normal     = 't/test.dat';

my @comments = ( 'Test Comment' );
my @fields   = sort keys %fields;

my( $data, $sauce );

# From raw data...
open( FILE, $bogus );
$data = do { local $/; <FILE> };
close( FILE );

$sauce = File::SAUCE->new( $data, 1 );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for short bogus data' );

open( FILE, $bogus_long );
$data = do { local $/; <FILE> };
close( FILE );

$sauce = File::SAUCE->new( $data, 1 );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for long bogus data' );

open( FILE, $normal );
$data = do { local $/; <FILE> };
close( FILE );

$sauce = File::SAUCE->new( $data, 1 );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 1, 'has_sauce is correct for good data' );

for( @fields ) {
	is( $sauce->get( $_ ), $fields{ $_ }, "field $_ read OK" );
}

ok( compare_arrays( \@comments, \@{ $sauce->get_comments } ), 'comments read OK' );


# From filehandle...
open( FILE, $bogus );

$sauce = File::SAUCE->new( \*FILE );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for short bogus data' );

close( FILE );

open( FILE, $bogus_long );

$sauce = File::SAUCE->new( \*FILE );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for long bogus data' );

close( FILE );

open( FILE, $normal );

$sauce = File::SAUCE->new( \*FILE );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 1, 'has_sauce is correct for good data' );

for( @fields ) {
	is( $sauce->get( $_ ), $fields{ $_ }, "field $_ read OK" );
}

ok( compare_arrays( \@comments, \@{ $sauce->get_comments } ), 'comments read OK' );

close( FILE );


# From filename...
$sauce = File::SAUCE->new( $bogus );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for short bogus data' );

$sauce = File::SAUCE->new( $bogus_long );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for long bogus data' );

$sauce = File::SAUCE->new( $normal );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 1, 'has_sauce is correct for good data' );

for( @fields ) {
	is( $sauce->get( $_ ), $fields{ $_ }, "field $_ read OK" );
}

ok( compare_arrays( \@comments, \@{ $sauce->get_comments } ), 'comments read OK' );


sub compare_arrays {
	my ($first, $second) = @_;
	return 0 if @$first != @$second;
	my $i = 0;
	$second->[$i++] ne $_ && return 0 for @$first;
	return 1;
}  
