use Test::More tests => 76;

BEGIN { 
    use_ok( 'File::SAUCE' );
}

my( $mday, $mon, $year ) = ( localtime( time ) )[ 3, 4, 5 ];
my $today = sprintf( '%4d%02d%02d', $year += 1900, ++$mon, $mday );

my $defaults = {
	sauce_id       => 'SAUCE',
	version        => '00',
	title          => '',
	author         => '',
	group          => '',
	date           => $today,
	filesize       => 0,
	datatype       => 0,
	filetype       => 0,
	tinfo1         => 0,
	tinfo2         => 0,
	tinfo3         => 0,
	tinfo4         => 0,
	flags          => 0,
	filler         => ' ' x 22,
	comnt_id       => 'COMNT',
	sauce_comments => 0,
	comments       => []
};

my %fields = (
	sauce_id       => 'SAUCE',
	version        => '00',
	title          => 'Test Title',
	author         => 'Test Author',
	group          => 'Test Group',
	date           => '20030101',
	filesize       => 1,
	datatype       => 1,
	filetype       => 1,
	tinfo1         => 1,
	tinfo2         => 1,
	tinfo3         => 1,
	tinfo4         => 1,
	flags          => 1,
	filler         => ' ' x 22,
	comnt_id       => 'COMNT',
	sauce_comments => 1 # incorrect on purpose
);

my @comments = (
	'Comment line 1',
	'Comment line 2'
);

my @default_fields = sort keys %$defaults;
my @custom_fields  = sort keys %fields;

my $sauce = File::SAUCE->new;
isa_ok( $sauce, 'File::SAUCE', 'SAUCE record' );

# test individual get from default setup
for( @default_fields ) {
	my $get = "get_$_";
	if( ref $defaults->{ $_ } eq 'ARRAY' ) {
		is( scalar @{ $sauce->get( $_ ) }, scalar @{ $defaults->{ $_ } }, '[' . $_ . '] get( $field ) from default setup' );
		is( scalar @{ $sauce->$get }, scalar @{ $defaults->{ $_ } }, '[' . $_ . '] get_$field from default setup' );
	}
	else {
		is( $sauce->get( $_ ), $defaults->{ $_ }, '[' . $_ . '] get( $field ) from default setup' );
		is( $sauce->$get, $defaults->{ $_ }, '[' . $_ . '] get_$field from default setup' );
	}
}

is( $sauce->has_sauce, undef, 'default $sauce->has_sauce reply' );

$sauce->set( %fields );
$sauce->has_sauce( 1 );

$sauce->clear;

# test clear to default setup
for( @default_fields ) {
	if( ref $defaults->{ $_ } eq 'ARRAY' ) {
		is( scalar @{ $sauce->get( $_ ) }, scalar @{ $defaults->{ $_ } }, '[' . $_ . '] get( $field ) after clear' );
	}
	else {
		is( $sauce->get( $_ ), $defaults->{ $_ }, '[' . $_ . '] get( $field ) after clear' );
	}
}

is( $sauce->has_sauce, undef, 'default $sauce->has_sauce reply' );

# test set of a hash
$sauce->set( %fields );

# test get of array
my @keys    = ( @custom_fields );
my @results = $sauce->get( @keys );

for( 0..$#results ) {
	is( $results[ $_ ], $fields{ $keys[ $_ ] }, '[' . $keys[ $_ ] . '] get( @array ) from set( %hash )' );
}

$sauce->set( comments => [ @comments ] );

my @newcomments = @{ $sauce->get( 'comments' ) };
ok( compare_arrays( \@comments, \@newcomments ), 'set( comments ) / get( comments )' );

sub compare_arrays {
	my ($first, $second) = @_;
	return 0 if @$first != @$second;
	my $i = 0;
	$second->[$i++] ne $_ && return 0 for @$first;
	return 1;
}  
