use Test::More tests => 25;

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

my @comments = ( 'Test Comment' );

my $sauce = File::SAUCE->new( 't/bogus.dat' );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for short bogus data' );

$sauce = File::SAUCE->new( 't/bogus.dat' );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 0, 'has_sauce is correct for long bogus data' );

$sauce = File::SAUCE->new( 't/test.dat' );
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

is( $sauce->has_sauce, 1, 'has_sauce is correct for good data' );

for( keys %fields ) {
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
