package File::SAUCE;

use strict;
use Carp;

$File::SAUCE::VERSION = '0.03';

# some SAUCE constants
use constant SAUCE_ID      => 'SAUCE';
use constant SAUCE_VERSION => '00';
use constant SAUCE_FILLER  => ' ' x 22;
use constant COMNT_ID      => 'COMNT';

# export ID constants
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( SAUCE_ID COMNT_ID );  

# vars for use with pack() and unpack()
my $sauce_template = 'A5 A2 A35 A20 A20 A8 L C C S S S S C A23';
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
		flags     => { 0 => 'None', 1 => 'iCE Color' }
	},
	Graphics   => {
		filetypes => [ qw( GIF PCX LBM/IFF TGA FLI FLC BMP GL DL WPG PNG JPG MPG AVI ) ],
		flags     => { 0 => 'None' }
	},
	Vector     => {
		filetypes => [ qw( DXF DWG WPG 3DS ) ],
		flags     => { 0 => 'None' }
	},
	Sound      => {
		filetypes => [ qw( MOD 669 STM S3M MTM FAR ULT AMF DMF OKT ROL CMF MIDI SADT VOC WAV SMP8 SMP8S SMP16 SMP16S PATCH8 PATCH16 XM HSC IT ) ],
		flags     => { 0 => 'None' }
	},
	BinaryText => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None', 1 => 'iCE Color' }
	},
	XBin       => {
		filetypes => [ qw( Undefined ) ],
		flags     => { 0 => 'None' }
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
	$self->read( $filedata, $raw ) if $filedata;
	return $self;
}

sub clear {
	my $self = shift;

	# Set empty SAUCE and COMMENT values

	@{ $self->{record}->{ @sauce_fields } }   = '';
	@{ $self->{comments}->{ @comnt_fields } } = '';
	$self->{ comments }->{ data }             = [];
}

sub read {
	my ( $self, $filedata, $raw ) = @_;

	return undef unless $filedata;

	if ( ref( $filedata ) eq 'GLOB' ) {
		$self->_read_filehandle( $filedata );
	}
	elsif ( $raw ) {
		$self->_read_rawdata( $filedata );
	}
	else {
		$self->_read_filename( $filedata );
	}
}

sub _read_filehandle {
	my ( $self, $filedata ) = @_;

	my $data;

	binmode( $filedata );
	seek( $filedata, -128, 2 );
	read( $filedata, $data, 128 );

	$self->_unpack_sauce( $data );

	# Do we have any comments?
	if( $self->{record}->{comments} > 0 ) {
		seek( $filedata, -128 - 5 - $self->{record}->{comments} * 64, 2 );
		read( $filedata, $data, 5 + $self->{record}->{comments} * 64 );

		$self->_unpack_comments( $data );
	}
}

sub _read_rawdata {
	my ( $self, $filedata ) = @_;

	my $data;

	$data = substr( $filedata, length( $filedata ) - 128 );

	$self->_unpack_sauce( $data );

	# Do we have any comments?
	if( $self->{record}->{comments} > 0 ) {
		$data = substr( $filedata, -128 - 5 - $self->{record}->{comments} * 64, 5 + $self->{record}->{comments} * 64 );

		$self->_unpack_comments( $data );
	}	
}

sub _read_filename {
	my ( $self, $filedata ) = @_;

	my $data;

	# Stop if the file isn't big enough to hold a SAUCE record
	return if -s $filedata < 128;

	if ( not open( FILE, $filedata ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}
	binmode( FILE );

	$self->_read_filehandle( \*FILE );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub _unpack_sauce {
	my ( $self, $data ) = @_;

	# Stop if our data doesn't have a valid SAUCE ID
	return 0 unless substr( $data, 0, 5 ) eq SAUCE_ID;

	my %data;

	@data{ @sauce_fields } = unpack( $sauce_template, $data );
	$self->{ record }      = \%data;

	return 1;
}

sub _unpack_comments {
	my ( $self, $data ) = @_;

	# Stop if our data doesn't have a valid COMMENT ID
	return 0 unless substr( $data, 0, 5 ) eq COMNT_ID;

	my ( $id, @comment_temp ) = unpack( ( split( / /, $comnt_template ) )[ 0 ] . ( ( split( / /, $comnt_template ) )[ 1 ] x ( ( length( $data ) - 5 ) / 64 ) ), $data );

	$self->{ comments } = {
		id   => $id,
		data => \@comment_temp
	};

	return 1;
}

sub as_string {
	my $self = shift;

	# Fix values incase they've been changed
	$self->{ record }->{ id }       = SAUCE_ID;
	$self->{ record }->{ version }  = SAUCE_VERSION;
	$self->{ record }->{ filler }   = SAUCE_FILLER;
	$self->{ comments }->{ id }     = COMNT_ID;
	$self->{ record }->{ comments } = scalar @{ $self->{ comments }->{ data } };

	my $record   = $self->{ record };
	my $comments = $self->{ comments };

	# EOF marker...
	my $output   = chr( 26 );

	# comments...	
	$output     .= pack( (split(/ /, $comnt_template))[0] . ((split(/ /, $comnt_template))[1] x $record->{comments}), $comments->{id}, @{$comments->{data}} ) if $record->{comments};

	# SAUCE...
	for (0..$#sauce_fields) {
		$output .= pack( ( split( / /, $sauce_template ) )[ $_ ], $record->{ $sauce_fields[ $_ ] } );
	}

	return $output;
}

sub write {
	my ( $self, $filedata, $raw ) = @_;

	return undef unless $filedata;

	# Fix file date
	$self->auto_date( $filedata, $raw );

	# Remove current SAUCE record
	$self->remove( $filedata, $raw );

	if ( ref( $filedata ) eq 'GLOB' ) {
		$self->_write_filehandle( $filedata );
	}
	elsif ( $raw ) {
		return $self->_write_rawdata( $filedata );
	}
	else {
		$self->_write_filename( $filedata );
	}
}

sub _write_filehandle {
	my ( $self, $filedata ) = @_;

	binmode( $filedata );

	# Fix file size
	$self->{ record }->{ filesize } = ( stat( $filedata ) )[ 7 ];

	print $filedata $self->as_string;
}

sub _write_rawdata {
	my ( $self, $filedata ) = @_;

	# Fix file size
	$self->{ record }->{ filesize } = length( $filedata );

	$filedata .= $self->as_string;

	return $filedata;
}

sub _write_filename {
	my ( $self, $filedata ) = @_;

	if ( not open( FILE, ">>$filedata" ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}

	$self->_write_filehandle( \*FILE );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub remove {
	my ( $self, $filedata, $raw ) = @_;

	return undef unless $filedata;

	my $sauce = File::SAUCE->new( $filedata, $raw );

	return unless $sauce->get_sauce_id eq SAUCE_ID;

	my $comments = scalar @{ $sauce->get_comments };

	if ( ref( $filedata ) eq 'GLOB' ) {
		$self->_remove_filehandle( $filedata, $comments );
	}
	elsif ( $raw ) {
		return $self->_remove_rawdata( $filedata, $comments );
	}
	else {
		$self->_remove_filename( $filedata, $comments );
	}
}

sub _remove_filehandle {
	my ( $self, $filedata, $comments ) = @_;

	binmode( $filedata );

	truncate( $filedata, ( stat( $filedata ) )[ 7 ] - 128 - 1 - ( $comments ? 5 + $comments * 64 : 0 ) ) or carp( "File truncate error ($filedata): $!" );
}

sub _remove_rawdata {
	my ( $self, $filedata, $comments ) = @_;

	return substr( $filedata, 0, ( length( $filedata ) - 128 - 1 - ( $comments ? 5 + $comments * 64 : 0 ) ) );
}

sub _remove_filename {
	my ( $self, $filedata, $comments ) = @_;

	if ( not open( FILE, ">>$filedata" ) ) {
		$@ = "File open error ($filedata): $!";
		return;
	}

	$self->_remove_filehandle( \*FILE, $comments );

	close( FILE ) or carp( "File close error ($filedata): $!" );
}

sub auto_date {
	my ( $self, $filedata, $raw ) = @_;

	# don't do anything if the record already has a date
	return if $self->{ record }->{ date };

	# current date if raw data or no data
	if ( not $filedata or $raw ) {
		$self->{ record }->{ date } = $self->convert_localtime;
		return;
	}

	if ( ref( $filedata ) eq 'GLOB' ) {
		$self->_auto_date_filehandle( $filedata );
	}
	else {
		if ( not open( FILE, "$filedata" ) ) {
			$@ = "File open error ($filedata): $!";
			return;
		}

		$self->_auto_date_filehandle( \*FILE );
	}
}

sub _auto_date_filehandle {
	my ( $self, $filedata ) = @_;

	$self->{ record }->{ date } = $self->convert_localtime( ( stat( $filedata ) )[ 9 ] );
}

sub convert_localtime {
	my $self      = shift;
	my $localtime = shift || time;

	my ( $mday, $mon, $year )   = ( localtime( $localtime ) )[ 3, 4, 5 ];
	return sprintf( '%4d%02d%02d', $year += 1900, ++$mon, $mday );
}

sub datatype {
	# Return the datatype name
	return $datatypes[ $_[ 0 ]->{ record }->{ datatype } ];
}

sub filetype {
	# Return the filetype name
	return $filetypes->{ $_[ 0 ]->datatype }->{ filetypes }->[ $_[ 0 ]->{ record }->{ filetype } ];
}

sub flags {
	# Return an english description of the flags
	return $filetypes->{ $_[ 0 ]->datatype }->{ flags }->{ ord( $_[ 0 ]->{ record }->{ flags } ) };
}

sub has_sauce {
	return $_[ 0 ]->{ record }->{ id } eq SAUCE_ID ? 1 : 0;
}

sub pretty_print {
	my $self = shift;

	for ( @sauce_fields ) {
		if ( $_ eq 'datatype' || $_ eq 'filetype' || $_ eq 'flags' ) {
			printf( "%10s: %s\n", ucfirst( $_ ), $self->$_ );
		}
		elsif ( $_ eq 'date' ) {
			printf( "      Date: %04d/%02d/%02d\n",
				substr( $self->{ record }->{ date }, 0, 4 ),
				substr( $self->{ record }->{ date }, 4, 2 ),
				substr( $self->{ record }->{ date }, 6, 2 )
			);
		}
		else {
			printf( "%10s: %s\n", ucfirst( $_ ), $self->{ record }->{ $_ } );
		}
	}
	print 'Comment Id: ', $self->{ comments }->{ id }, "\n";
	print '  Comments: ';
	print "\n" unless $self->{ record }->{ comments };
	for ( 0..$#{ $self->{ comments }->{ data } } ) {
		printf( $_ == 0 ? "%s\n" : "            %s\n", $self->{ comments }->{ data }->[ $_ ] );
	}
}

# Mutator
sub set {
	my ( $self, %options ) = @_;

	for (  keys %options ) {
		if ( $_ eq 'sauce_id' ) {
			$self->{ record }->{ id } = $options{ $_ };
		}
		elsif ( $_ eq 'comnt_id' ) {
			$self->{ comments }->{ id } = $options{ $_ };
		}
		elsif ( $_ eq 'comments' ) {
			# auto-truncate long comment lines
			substr( $_, 0, 64 ) for @{ $options{ $_ } };

			$self->{ record }->{ comments } = scalar @{ $options{ $_ } };
			$self->{ comments }->{ data } = $options{ $_ };
		}
		else {
			$self->{ record }->{ $_ } = $options{ $_ };
		}
	}
}

# Accessor
sub get {
	my ( $self, @options ) = @_;

	my @return;
	for ( @options ) {
		if ( $_ eq 'sauce_id' ) {
			push @return, $self->{ record }->{ id };
		}
		elsif ( $_ eq 'comnt_id' ) {
			push @return, $self->{ comments }->{ id };
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
	$self->set( $2, $value ) if $1 eq 'set'; 
}

1;

=pod

=head1 NAME

File::SAUCE - A library to manipulate SAUCE metadata

=head1 SYNOPSIS

	use File::SAUCE;

	# Read the data...
	# ...a filename, a reference to a filehandle, or raw data
	my $ansi = File::SAUCE->new('myansi.ans');

	# Does the file have a SAUCE rec?
	print $ansi->get_sauce_id eq SAUCE_ID ? "has SAUCE" : "does not have SAUCE";

	# Print the metadata...
	$ansi->pretty_print;

	# Get a value...
	my $title = $ansi->get_title;

	# Set a value...
	$ansi->set_title('ANSi is 1337');

	# Get the SAUCE record as a string...
	my $sauce = $ansi->as_string;

	# Write the data...
	#...a filename, a reference to a filehandle, or raw data
	$ansi->write('myansi.ans');

	# Clear the in-memory data...
	$ansi->clear;

	# Read the data... (Note, auto-read when new is called)
	#...a filename, a reference to a filehandle, or raw data
	$ansi->read('myansi.ans');

	# Remove the data...
	#...a filename, a reference to a filehandle, or raw data
	$ansi->remove('myansi.ans');

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

	+----------------+------+------+---------+-----------+
	| Field          | Size | Type | Default | set / get |
	+----------------+------+------+---------+-----------+
	| ID             | 5    | Char | COMNT   | comnt_id  |
	+----------------+------+------+---------+-----------+
	| Comment Line 1 | 64   | Char |         | comments  |
	+----------------+------+------+---------+-----------+
	| ...                                                |
	+----------------+------+------+---------+-----------+
	| Comment Line X | 64   | Char |         | comments  |
	+----------------+------+------+---------+-----------+

And lastly, the SAUCE Record. It is exactly 128 bytes long:

	+----------------+------+------+---------+-----------+
	| Field          | Size | Type | Default | set / get |
	+----------------+------+------+---------+-----------+
	| ID             | 5    | Char | SAUCE   | sauce_id  |
	+----------------+------+------+---------+-----------+
	| SAUCE Version  | 2    | Char | 00      | version   |
	+----------------+------+------+---------+-----------+
	| Title          | 35   | Char |         | title     |
	+----------------+------+------+---------+-----------+
	| Author         | 20   | Char |         | author    |
	+----------------+------+------+---------+-----------+
	| Group          | 20   | Char |         | group     |
	+----------------+------+------+---------+-----------+
	| Date           | 8    | Char |         | date      |
	+----------------+------+------+---------+-----------+
	| FileSize       | 4    | Long |         | filesize  |
	+----------------+------+------+---------+-----------+
	| DataType       | 1    | Byte |         | datatype  |
	+----------------+------+------+---------+-----------+
	| FileType       | 1    | Byte |         | filetype  |
	+----------------+------+------+---------+-----------+
	| TInfo1         | 2    | Word |         | tinfo1    |
	+----------------+------+------+---------+-----------+
	| TInfo2         | 2    | Word |         | tinfo2    |
	+----------------+------+------+---------+-----------+
	| TInfo3         | 2    | Word |         | tinfo3    |
	+----------------+------+------+---------+-----------+
	| TInfo4         | 2    | Word |         | tinfo4    |
	+----------------+------+------+---------+-----------+
	| Comments       | 1    | Byte |         | comments  |
	+----------------+------+------+---------+-----------+
	| Flags          | 1    | Byte |         | flags     |
	+----------------+------+------+---------+-----------+
	| Filler         | 22   | Byte |         | filler    |
	+----------------+------+------+---------+-----------+

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

=over 4

=item new([$filename or \*FILEHANDLE or $rawdata, $is_raw_data])

Creates a new File::SAUCE object. All arguments are optional. It will read a file's (or raw data's)
SAUCE data (by calling C<read>) if it has any. If you're reading from raw data, you must specify a
true value for $is_raw_data, otherwise it is not required.

=item read($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Explicitly read's all SAUCE data from the file.

=item write($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Writes the in-memory SAUCE data to the file, or appends it to raw data. It calls C<remove> before writing the data.

=item as_string()

Returns the SAUCE record (including EOF char and comments) as a string.

=item remove($filename or \*FILEHANDLE or $rawdata, [$is_raw_data])

Removes any SAUCE data from the file, or raw data.

=item clear()

Resets the in-memory SAUCE data to the default information.

=item datatype()

Return the string version of the file's datatype. Use get_datatype to get the integer version.

=item filetype()

Return the string version of the file's filetype. Use get_filetype to get the integer version.

=item flags()

Return the string version of the file's flags. Use get_flags to get the integer version.

=item pretty_print()

View the SAUCE structure (including comments) in a "pretty" format.

=item auto_date( [$filename or \*FILEHANDLE or $rawdata], [$is_raw_data] )

Tries to automatically set the SAUCE record's date. This will do nothing if the record already has
a date defined. Omitting all args will use the current date.

=item convert_localtime( [$time] )

Converts a localtime-able value into a valid SAUCE record date. Uses time() if no args are passed.

=item set(%options)

Set an element's (or several elements') value. Everything is pretty straight forward except the
comments section. Giving the C<set> function the C<comments> key along with an arrayref will, along
with assigning the comments, it will set the number of comments in the SAUCE Record.

You can also use C<set_field(value)>, where field is the SAUCE Record field to set.

=item get(@options)

Get an element's (or several elements') value. Similar to above, C<comments> will return an arrayref.

=back

=head1 BUGS

If you have any questions, comments, bug reports or feature suggestions, 
email them to Brian Cassidy <brian@alternation.net>.

=head1 CREDITS

This module was originally written by Brian Cassidy (http://www.alternation.net/) with
help from Ray Brinzer (http://www.brinzer.net/).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms
of the Artistic License, distributed with Perl.

=cut