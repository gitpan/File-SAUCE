package File::SAUCE;

use strict;
use Carp;

our $VERSION = '0.06';

# some SAUCE constants
use constant SAUCE_ID      => 'SAUCE';
use constant SAUCE_VERSION => '00';
use constant SAUCE_FILLER  => ' ' x 22;
use constant COMNT_ID      => 'COMNT';

# export ID constants
use base qw( Exporter );
our @EXPORT = qw( SAUCE_ID COMNT_ID );  

# vars for use with pack() and unpack()
my $sauce_template = 'A5 A2 A35 A20 A20 A8 L C C S S S S C C A22';
my @sauce_fields   = qw( id version title author group date filesize datatype filetype tinfo1 tinfo2 tinfo3 tinfo4 comments flags filler );
my $comnt_template = 'A5 A64';
my @comnt_fields   = qw( id data );

# define datatypes and filetypes as per SAUCE specs
my @datatypes = qw(None Character Graphics Vector Sound BinaryText XBin Archive Executable);
my $filetypes = {
	None       => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None' }
	},
	Character  => {
		filetypes => [ qw( ASCII ANSi ANSiMation RIP PCBoard Avatar HTML Source ) ],
		flags     => { 0 => 'None', 1 => 'iCE Color' },
		tinfo     => [
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Colors' },
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
		]
	},
	Graphics   => {
		filetypes => [ qw( GIF PCX LBM/IFF TGA FLI FLC BMP GL DL WPG PNG JPG MPG AVI ) ],
		flags     => { 0 => 'None' },
		tinfo     => [
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
			{ tinfo1 => 'Width', tinfo2 => 'Height', tinfo3 => 'Bits Per Pixel' },
		]
	},
	Vector     => {
		filetypes => [ qw( DXF DWG WPG 3DS ) ],
		flags     => { 0 => 'None' }
	},
	Sound      => {
		filetypes => [ qw( MOD 669 STM S3M MTM FAR ULT AMF DMF OKT ROL CMF MIDI SADT VOC WAV SMP8 SMP8S SMP16 SMP16S PATCH8 PATCH16 XM HSC IT ) ],
		flags     => { 0 => 'None' },
		tinfo     => [
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ },
			{ tinfo1 => 'Sampling Rate' },
			{ tinfo1 => 'Sampling Rate' },
			{ tinfo1 => 'Sampling Rate' },
			{ tinfo1 => 'Sampling Rate' },
		]
	},
	BinaryText => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None', 1 => 'iCE Color' }
	},
	XBin       => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None' },
		tinfo     => [
			{ tinfo1 => 'Width', tinfo2 => 'Height' },
		]
	},
	Archive    => {
		filetypes => [ qw( ZIP ARJ LZH ARC TAR ZOO RAR UC2 PAK SQZ ) ],
		flags     => { 0 => 'None' }
	},
	Executable => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None' }
	}
};

sub new {
	my( $class, $filedata, $raw ) = @_;
	my $self = {};
	bless $self, $class;
	$self->clear;
	$self->read( $filedata, $raw ) if @_ >= 2;
	return $self;
}

sub clear {
	my $self = shift;

	# Set empty/default SAUCE and COMMENT values
	$self->set( $_ => '' ) for qw( author title group );
	$self->set( $_ => 0 ) for qw( datatype filetype filesize tinfo1 tinfo2 tinfo3 tinfo4 flags );
	$self->set(
		sauce_id => SAUCE_ID,
		version  => SAUCE_VERSION,
		filler   => SAUCE_FILLER,
		comnt_id => COMNT_ID,
		date     => $self->convert_localtime
	);
	$self->set_comments( [] );
	$self->has_sauce( undef );
}

sub read {
	my( $self, $filedata, $raw ) = @_;

	return undef unless @_ >= 2;

	if( ref( $filedata ) eq 'GLOB' ) {
		$self->_read_filehandle( $filedata );
	}
	elsif( $raw ) {
		$self->_read_rawdata( $filedata );
	}
	else {
		$self->_read_filename( $filedata );
	}
}

sub _read_filehandle {
	my( $self, $filedata ) = @_;

	my $data;

	binmode( $filedata );
	seek( $filedata, -128, 2 );
	CORE::read( $filedata, $data, 128 );

	$self->_unpack_sauce( $data );

	# Do we have any comments?
	my $comments = $self->get_sauce_comments;
	if( $comments > 0 ) {
		seek( $filedata, -128 - 5 - $comments * 64, 2 );
		CORE::read( $filedata, $data, 5 + $comments * 64 );

		$self->_unpack_comments( $data );
	}
}

sub _read_rawdata {
	my( $self, $filedata ) = @_;

	# Stop if the file isn't big enough to hold a SAUCE record
	if( length( $filedata ) < 128 ) {
		$self->has_sauce( 0 );
		return;
	}

	my $data;

	$data = substr( $filedata, length( $filedata ) - 128 );

	$self->_unpack_sauce( $data );

	# Do we have any comments?
	my $comments = $self->get_sauce_comments;
	if( $comments > 0 ) {
		$data = substr( $filedata, -128 - 5 - $comments * 64, 5 + $comments * 64 );

		$self->_unpack_comments( $data );
	}	
}

sub _read_filename {
	my( $self, $filedata ) = @_;

	my $data;

	# Stop if the file doesn't exist.
	if( not -e $filedata ) {
		$@ = "File doesn't exist";
		return;
	}

	# Stop if the file isn't big enough to hold a SAUCE record
	if( -s $filedata < 128 ) {
		$self->has_sauce( 0 );
		return;
	}

	if( not open( FILE, $filedata ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}
	binmode( FILE );

	$self->_read_filehandle( \*FILE );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub _unpack_sauce {
	my( $self, $data ) = @_;

	# Stop if our data doesn't have a valid SAUCE ID
	unless( substr( $data, 0, 5 ) eq SAUCE_ID ) {
		$self->has_sauce( 0 );
		return;
	}

	$self->has_sauce( 1 );

	my %data;

	@data{ @sauce_fields } = unpack( $sauce_template, $data );

	# because trailing spaces are stripped....
	$data{ filler } = SAUCE_FILLER; 

	$self->set(
		sauce_id       => $data{ id },
		sauce_comments => $data{ comments }
	);

	$self->set( $_ => $data{ $_ } ) for qw( version title author group date datatype filetype filesize tinfo1 tinfo2 tinfo3 tinfo4 flags filler );

	return 1;
}

sub _unpack_comments {
	my( $self, $data ) = @_;

	# Stop if our data doesn't have a valid COMMENT ID
	return 0 unless substr( $data, 0, 5 ) eq COMNT_ID;

	my( $id, @comment_temp ) = unpack( ( split( / /, $comnt_template ) )[ 0 ] . ( ( split( / /, $comnt_template ) )[ 1 ] x ( ( length( $data ) - 5 ) / 64 ) ), $data );

	$self->set(
		comnt_id => $id,
		comments => \@comment_temp
	);

	return 1;
}

sub as_string {
	my $self = shift;

	# Fix values incase they've been changed
	$self->set(
		sauce_id => SAUCE_ID,
		version  => SAUCE_VERSION,
		filler   => SAUCE_FILLER,
		comnt_id => COMNT_ID,
		comments => $self->get_comments
	);

	# EOF marker...
	my $output   = chr( 26 );

	# comments...
	my $comments = $self->get_sauce_comments;
	if( $comments ) {
		$output .= pack( (split(/ /, $comnt_template))[0] . ((split(/ /, $comnt_template))[ 1 ] x $comments), $self->get_comnt_id, @{ $self->get_comments } )
	}

	# SAUCE...
	my @template = split( / /, $sauce_template );
	for(0..$#sauce_fields) {
		my $field = $sauce_fields[ $_ ];
		my $value;

		if( $field eq 'id' ) {
			$value = $self->get_sauce_id;
		}
		elsif( $field eq 'comments' ) {
			$value = $self->get_sauce_comments;
		}
		else {
			$value = $self->get( $field );
		}

		$output .= pack( $template[ $_ ], $value );
	}

	return $output;
}

sub write {
	my( $self, $filedata, $raw ) = @_;

	return undef unless @_ >= 2;

	# Fix file date
	$self->auto_date( $filedata, $raw );

	# Remove current SAUCE record
	$self->remove( $filedata, $raw );

	if( ref( $filedata ) eq 'GLOB' ) {
		$self->_write_filehandle( $filedata );
	}
	elsif( $raw ) {
		return $self->_write_rawdata( $filedata );
	}
	else {
		$self->_write_filename( $filedata );
	}
}

sub _write_filehandle {
	my( $self, $filedata ) = @_;

	binmode( $filedata );

	# Fix file size
	$self->set_filesize( ( stat( $filedata ) )[ 7 ] );

	print $filedata $self->as_string;
}

sub _write_rawdata {
	my( $self, $filedata ) = @_;

	# Fix file size
	$self->set_filesize( length( $filedata ) ) if defined $filedata;

	$filedata .= $self->as_string;

	return $filedata;
}

sub _write_filename {
	my( $self, $filedata ) = @_;

	if( not open( FILE, ">>$filedata" ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}

	$self->_write_filehandle( \*FILE );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub remove {
	my( $self, $filedata, $raw ) = @_;

	return undef unless $filedata;

	my $sauce = File::SAUCE->new( $filedata, $raw );

	return unless $sauce->has_sauce;

	if( ref( $filedata ) eq 'GLOB' ) {
		$self->_remove_filehandle( $filedata, $sauce );
	}
	elsif( $raw ) {
		return $self->_remove_rawdata( $filedata, $sauce );
	}
	else {
		$self->_remove_filename( $filedata, $sauce );
	}
}

sub _remove_filehandle {
	my( $self, $filedata, $sauce ) = @_;

	binmode( $filedata );

	my $sizeondisk = ( stat( $filedata ) )[ 7 ];
	my $sizeinrec  = $sauce->get_filesize;
	my $comments   = $sauce->get_sauce_comments;
	my $saucesize  = 128 - ( $comments ? 5 + $comments * 64 : 0 );

	# for spoon compatibility
	# Size on disk - size in record - SAUCE size (w/ comments) == 0 or 1 --> use size in record
	if( $sizeondisk - $sizeinrec - $saucesize =~ /^0|1$/ ) {
		truncate( $filedata, $sizeinrec ) or carp( "File truncate error ($filedata): $!" );
	}
	# figure it out on our own -- spoon just balks
	else {
		truncate( $filedata, $sizeondisk - $saucesize - 1 ) or carp( "File truncate error ($filedata): $!" );
	}
}

sub _remove_rawdata {
	my( $self, $filedata, $sauce ) = @_;

	my $sizeondisk = length( $filedata );
	my $sizeinrec  = $sauce->get_filesize;
	my $comments   = $sauce->get_sauce_comments;
	my $saucesize  = 128 - ( $comments ? 5 + $comments * 64 : 0 );

	# for spoon compatibility
	# Size on disk - size in record - SAUCE size (w/ comments) == 0 or 1 --> use size in record
	if( $sizeondisk - $sizeinrec - $saucesize =~ /^0|1$/ ) {
		return substr( $filedata, 0, $sizeinrec );
	}
	# figure it out on our own -- spoon just balks
	else {
		return substr( $filedata, 0, $sizeondisk - $saucesize - 1 );
	}
}

sub _remove_filename {
	my( $self, $filedata, $sauce ) = @_;

	if( not open( FILE, ">>$filedata" ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}

	$self->_remove_filehandle( \*FILE, $sauce );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub auto_date {
	my( $self, $filedata, $raw ) = @_;

	# don't do anything if the record already has a date
	return if $self->get_date;

	# current date if raw data or no data
	if( not $filedata or $raw ) {
		$self->set_date( $self->convert_localtime );
		return;
	}

	if( ref( $filedata ) eq 'GLOB' ) {
		$self->_auto_date_filehandle( $filedata );
	}
	else {
		if( not open( FILE, "$filedata" ) ) {
			$@ = "File open error ($filedata): $!";
			return;
		}

		$self->_auto_date_filehandle( \*FILE );
	}
}

sub _auto_date_filehandle {
	my( $self, $filedata ) = @_;

	$self->set_date( $self->convert_localtime( ( stat( $filedata ) )[ 9 ] ) );
}

sub convert_localtime {
	my $self      = shift;
	my $localtime = shift || time;

	my( $mday, $mon, $year )   = ( localtime( $localtime ) )[ 3, 4, 5 ];
	return sprintf( '%4d%02d%02d', $year += 1900, ++$mon, $mday );
}

sub datatype {
	# Return the datatype name
	return $datatypes[ $_[ 0 ]->get_datatype ];
}

sub filetype {
	# Return the filetype name
	return $filetypes->{ $_[ 0 ]->datatype }->{ filetypes }->[ $_[ 0 ]->get_filetype ];
}

sub flags {
	# Return an english description of the flags
	return $filetypes->{ $_[ 0 ]->datatype }->{ flags }->{ $_[ 0 ]->get_flags };
}

sub tinfo1 {
	# Return an english description of info flag (1) or blank if there is none
	return $filetypes->{ $_[ 0 ]->datatype }->{ tinfo }->[ $_[ 0 ]->get_filetype ]->{ tinfo1 };
}

sub tinfo2 {
	# Return an english description of info flag (2) or blank if there is none
	return $filetypes->{ $_[ 0 ]->datatype }->{ tinfo }->[ $_[ 0 ]->get_filetype ]->{ tinfo2 };
}

sub tinfo3 {
	# Return an english description of info flag (3) or blank if there is none
	return $filetypes->{ $_[ 0 ]->datatype }->{ tinfo }->[ $_[ 0 ]->get_filetype ]->{ tinfo3 };
}

sub tinfo4 {
	# Return an english description of info flag (4) or blank if there is none
	return $filetypes->{ $_[ 0 ]->datatype }->{ tinfo }->[ $_[ 0 ]->get_filetype ]->{ tinfo4 };
}

sub has_sauce {
	my $self = shift;

	$self->{ _HAS_SAUCE } = $_[ 0 ] if @_;

	return $self->{ _HAS_SAUCE };
}

sub pretty_print {
	my $self  = shift;
	my $width = 10;
	my $label = '%' . $width . 's:';

	for( @sauce_fields ) {
		if( /^(datatype|filetype|flags)$/ ) {
			printf( "$label %s\n", ucfirst( $_ ), $self->$_ );
		}
		elsif( /^tinfo\d$/ ) {
			printf( "$label %s", ucfirst( $_ ), $self->get( $_ ) );
			print ( $self->$_ ? ' (' . $self->$_ . ")\n" : "\n" );
		}
		elsif( $_ eq 'date' ) {
			my $date = $self->get_date;
			printf( "$label %04d/%02d/%02d\n",
				'Date',
				substr( $date, 0, 4 ),
				substr( $date, 4, 2 ),
				substr( $date, 6, 2 )
			);
		}
		elsif( $_ eq 'comments' ) {
			printf( "$label %s\n", 'Comments', $self->get_sauce_comments );
		}
		else {
			printf( "$label %s\n", ucfirst( $_ ), $self->get( $_ ) );
		}
	}
	printf( "$label %s\n", 'Comment Id', $self->get_comnt_id );
	printf( $label, 'Comments' );

	my @comments = @{ $self->get_comments };

	print "\n" unless @comments;
	for( 0..$#comments ) {
		printf( $_ == 0 ? " %s\n" : ( ' ' x ( $width + 1 ) ) . " %s\n", $comments[ $_ ] );
	}
}

# Mutator
sub set {
	my( $self, %options ) = @_;

	for(  keys %options ) {
		if( $_ eq 'sauce_id' ) {
			$self->{ record }->{ id } = $options{ $_ };
		}
		elsif( $_ eq 'comnt_id' ) {
			$self->{ comments }->{ id } = $options{ $_ };
		}
		elsif( $_ eq 'sauce_comments' ) {
			$self->{ record }->{ comments } = $options{ $_ };
		}
		elsif( $_ eq 'date' ) {
			$self->{ record }->{ date } = $options{ $_ } if $options{ $_ } =~ /^(\d+|)$/;
		}
		elsif( $_ eq 'comments' ) {
			# auto-truncate long comment lines
			for( 0.. $#{ $options{ $_ } } ) {
				$options{ comments }->[ $_ ] = substr( $options{ comments }->[ $_ ], 0, 64 );
			}

			$self->set_sauce_comments( scalar @{ $options{ $_ } } );
			$self->{ comments }->{ data } = $options{ $_ };
		}
		else {
			my $key = $_;
			$self->{ record }->{ $_ } = $options{ $_ } if grep { /^$key$/ } @sauce_fields;
		}
	}
}

# Accessor
sub get {
	my( $self, @options ) = @_;

	my @return;
	for( @options ) {
		if( $_ eq 'sauce_id' ) {
			push @return, $self->{ record }->{ id };
		}
		elsif( $_ eq 'comnt_id' ) {
			push @return, $self->{ comments }->{ id };
		}
		elsif( $_ eq 'sauce_comments' ) {
			push @return, $self->{ record }->{ comments };
		}
		else {
			push @return, /^comments$/ ? $self->{ comments }->{ data } : $self->{ record }->{ $_ };
		}
	}

	return wantarray ? @return : $return[ 0 ];
}

# Autoloaded accessors and mutators
sub AUTOLOAD {
	our $AUTOLOAD;

	my $self  = shift;
	my $value = shift;
	my $name  = $AUTOLOAD;
	$name     =~ s/^.*:://;

	return if $name =~ /DESTROY/;

	carp( sprintf "No method '$name' available in package %s.", __PACKAGE__ ) unless $name =~ /^(set|get)_(.+)/;

	return $self->get( $2 )  if $1 eq 'get'; 
	$self->set( $2 => $value ) if $1 eq 'set'; 
}

1;

=pod

=head1 NAME

File::SAUCE - A library to manipulate SAUCE metadata

=head1 SYNOPSIS

	use File::SAUCE;

	# Read the data...
	# ...a filename, a reference to a filehandle, or raw data
	my $ansi = File::SAUCE->new( 'myansi.ans' );

	# Does the file have a SAUCE rec?
	print $ansi->has_sauce ? "has SAUCE" : "does not have SAUCE";

	# Print the metadata...
	$ansi->pretty_print;

	# Get a value...
	my $title = $ansi->get_title;

	# Set a value...
	$ansi->set_title( 'ANSi is 1337' );

	# Get the SAUCE record as a string...
	my $sauce = $ansi->as_string;

	# Write the data...
	#...a filename, a reference to a filehandle, or raw data
	$ansi->write( 'myansi.ans' );

	# Clear the in-memory data...
	$ansi->clear;

	# Read the data... (Note, auto-read when new is called)
	#...a filename, a reference to a filehandle, or raw data
	$ansi->read( 'myansi.ans' );

	# Remove the data...
	#...a filename, a reference to a filehandle, or raw data
	$ansi->remove( 'myansi.ans' );

=head1 DESCRIPTION

SAUCE stands for Standard Architecture for Universal Comment Extentions. It is used as metadata
to describe the file to which it is associated. It's most common use has been with the ANSI and
ASCII "art scene."

A file containing a SAUCE record looks like this:

	+----------------+
	| FILE Data      |
	+----------------+
	| EOF Marker     |
	+----------------+
	| SAUCE Comments |
	+----------------+
	| SAUCE Record   |
	+----------------+

The SAUCE Comments block holds up to 255 comment lines, each 64 characters wide. It looks like this:

	+----------------+------+------+---------+----------------+
	| Field          | Size | Type | Default | set / get      |
	+----------------+------+------+---------+----------------+
	| ID             | 5    | Char | COMNT   | comnt_id       |
	+----------------+------+------+---------+----------------+
	| Comment Line 1 | 64   | Char |         | comments       |
	+----------------+------+------+---------+----------------+
	| ...                                                     |
	+----------------+------+------+---------+----------------+
	| Comment Line X | 64   | Char |         | comments       |
	+----------------+------+------+---------+----------------+

And lastly, the SAUCE Record. It is exactly 128 bytes long:

	+----------------+------+------+---------+----------------+
	| Field          | Size | Type | Default | set / get      |
	+----------------+------+------+---------+----------------+
	| ID             | 5    | Char | SAUCE   | sauce_id       |
	+----------------+------+------+---------+----------------+
	| SAUCE Version  | 2    | Char | 00      | version        |
	+----------------+------+------+---------+----------------+
	| Title          | 35   | Char |         | title          |
	+----------------+------+------+---------+----------------+
	| Author         | 20   | Char |         | author         |
	+----------------+------+------+---------+----------------+
	| Group          | 20   | Char |         | group          |
	+----------------+------+------+---------+----------------+
	| Date           | 8    | Char |         | date           |
	+----------------+------+------+---------+----------------+
	| FileSize       | 4    | Long |         | filesize       |
	+----------------+------+------+---------+----------------+
	| DataType       | 1    | Byte |         | datatype       |
	+----------------+------+------+---------+----------------+
	| FileType       | 1    | Byte |         | filetype       |
	+----------------+------+------+---------+----------------+
	| TInfo1         | 2    | Word |         | tinfo1         |
	+----------------+------+------+---------+----------------+
	| TInfo2         | 2    | Word |         | tinfo2         |
	+----------------+------+------+---------+----------------+
	| TInfo3         | 2    | Word |         | tinfo3         |
	+----------------+------+------+---------+----------------+
	| TInfo4         | 2    | Word |         | tinfo4         |
	+----------------+------+------+---------+----------------+
	| Comments       | 1    | Byte |         | sauce_comments |
	+----------------+------+------+---------+----------------+
	| Flags          | 1    | Byte |         | flags          |
	+----------------+------+------+---------+----------------+
	| Filler         | 22   | Byte |         | filler         |
	+----------------+------+------+---------+----------------+

For more information see ACiD.org's SAUCE page at http://www.acid.org/info/sauce/sauce.htm

=head1 WARNING

From the SAUCE documenation:

	SAUCE was initially created for supporting only the ANSi & RIP screens. Since both ANSi
	and RIP are in effect text-based and have no other form of control but the End-Of-File marker,
	SAUCE should never interfere with the workings of a program using either ANSi or RIP. If it
	does, the program is not functionning the way it should. This is NOT true for the other types
	of files however. Adding SAUCE to some of the other filetypes supported in the SAUCE
	specifications may have serious consequences on the proper functionning of programs using those
	files, In the worst case, they'll simply refuse the file, stating it is invalid. 

The author(s) of this software take no resposibility for loss of data!

=head1 METHODS

=head2 new([$filename or \*FILEHANDLE or $rawdata, $is_raw_data])

Creates a new File::SAUCE object. All arguments are optional. It will read a file's (or raw data's)
SAUCE data (by calling C<read>) if it has any. If you're reading from raw data, you must specify a
true value for $is_raw_data, otherwise it is not required.

=head2 read($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Explicitly read's all SAUCE data from the file.

=head2 write($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Writes the in-memory SAUCE data to the file, or appends it to raw data. It calls C<remove> before writing the data.

=head2 has_sauce([$has_sauce])

gets/sets if the last file read has a SAUCE record. This function only returns a useful value (true/false) after a file
is read, otherwise the results don't have much meaning. This is the only way to check a file SAUCE validity.

=head2 as_string()

Returns the SAUCE record (including EOF char and comments) as a string.

=head2 remove($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Removes any SAUCE data from the file, or raw data. This module enforces spoon
(ftp://ftp.artpacks.acid.org/pub/artpacks/programs/dos/editors/spn2d161.zip) compatibility. The following calculation
is used to determine how big the file should be after truncation:

	if( Filesize on disk - Filesize in SAUCE rec - Size of SAUCE rec ( w/ comments ) == 0 or 1 ) {
		truncate to Filesize in SAUCE rec
	}
	else {
		truncate to Filesize on disk - Size of SAUCE rec - 1 (EOF char)
	}

=head2 clear()

Resets the in-memory SAUCE data to the default information.

=head2 datatype()

Return the string version of the file's datatype. Use get_datatype to get the integer version.

=head2 filetype()

Return the string version of the file's filetype. Use get_filetype to get the integer version.

=head2 tinfo1()

Return an english description of what this info value represents (returns undef if there isn't one)

=head2 tinfo2()

Return an english description of what this info value represents (returns undef if there isn't one)

=head2 tinfo3()

Return an english description of what this info value represents (returns undef if there isn't one)

=head2 tinfo4()

Return an english description of what this info value represents (returns undef if there isn't one)

=head2 flags()

Return the string version of the file's flags. Use get_flags to get the integer version.

=head2 pretty_print()

View the SAUCE structure (including comments) in a "pretty" format.

=head2 auto_date( [$filename or \*FILEHANDLE or $rawdata], [$is_raw_data] )

Tries to automatically set the SAUCE record's date. This will do nothing if the record already has
a date defined. Omitting all args will use the current date.

=head2 convert_localtime( [$time] )

Converts a localtime-able value into a valid SAUCE record date. Uses time() if no args are passed.

=head2 set(%options)

Set an element's (or several elements') value. Everything is pretty straight forward except the
comments section. Giving the C<set> function the C<comments> key along with an arrayref will, along
with assigning the comments, it will set the number of comments in the SAUCE Record.

You can also use C<set_field(value)>, where field is the SAUCE Record field to set.

=head2 get(@options)

Get an element's (or several elements') value. Similar to above, C<comments> will return an arrayref.

=head1 BUGS

If you have any questions, comments, bug reports or feature suggestions, 
email them to Brian Cassidy <brian@alternation.net>.

=head1 CREDITS

This module was originally written by Brian Cassidy (http://www.alternation.net/) with
help from Ray Brinzer (http://www.brinzer.net/).

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
