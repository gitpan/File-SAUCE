use Test::More tests => 9;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my %fields = (
	sauce_id       => 'SAUCE',
	version        => '00',
	title          => 'Test Title',
	author         => 'Test Author',
	group          => 'Test Group',
	date           => '20030101',
	filesize       => 0,
	datatype       => 1,
	filetype       => 1,
	tinfo1         => 1,
	tinfo2         => 1,
	tinfo3         => 1,
	tinfo4         => 1,
	flags          => 1,
	filler         => ' ' x 22,
	comnt_id       => 'COMNT',
	sauce_comments => 0
);

my $sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

# test set of a hash
$sauce->set( %fields );

is( $sauce->datatype, 'Character', '$sauce->datatype' );
is( $sauce->filetype, 'ANSi', '$sauce->filetype' );
is( $sauce->flags, 'iCE Color', $sauce->flags );
is( $sauce->tinfo1, 'Width', $sauce->tinfo1 );
is( $sauce->tinfo2, 'Height', $sauce->tinfo2 );
is( $sauce->tinfo3, undef, $sauce->tinfo3 );
is( $sauce->tinfo4, undef, $sauce->tinfo4 );