package File::SAUCE;

use strict;
use Carp;

$File::SAUCE::VERSION = '0.01';

# some SAUCE constants
use constant SAUCE_ID      => 'SAUCE';
use constant SAUCE_VERSION => '00';
use constant SAUCE_FILLER  => ' ' x 22;
use constant COMNT_ID      => 'COMNT';

# vars for use with pack() and unpack()
my $sauce_template = 'A5 A2 A35 A20 A20 A8 L C C S S S S C A23';
my @sauce_fields   = qw(id version title author group date filesize datatype filetype tinfo1 tinfo2 tinfo3 tinfo4 comments flags filler);
my $comnt_template = 'A5 A64';
my @comnt_fields   = qw(id data);

# define datatypes and filetypes as per SAUCE specs
my @datatypes = qw(None Character Graphics Vector Sound BinaryText XBin Archive Executable);
my $filetypes = {
	None       => {
		filetypes => [ qw(Undefined) ],
		flags     => { 0 => 'None' }
	},
	Character  => {
		filetypes => [ qw(ASCII ANSi ANSiMation RIP PCBoard Avatar HTML Source) ],
		flags     => { 0 => 'None', 1 => 'iCE Color' }
	},
	Graphics   => {
		filetypes => [ qw(GIF PCX LBM/IFF TGA FLI FLC BMP GL DL WPG PNG JPG MPG AVI) ],
		flags     => { 0 => 'None' }
	},
	Vector     => {
		filetypes => [ qw(DXF DWG WPG 3DS) ],
		flags     => { 0 => 'None' }
	},
	Sound      => {
		filetypes => [ qw(MOD 669 STM S3M MTM FAR ULT AMF DMF OKT ROL CMF MIDI SADT VOC WAV SMP8 SMP8S SMP16 SMP16S PATCH8 PATCH16 XM HSC IT) ],
		flags     => { 0 => 'None' }
	},
	BinaryText => {
		filetypes => [ qw(Undefined) ],
		flags     => { 0 => 'None', 1 => 'iCE Color' }
	},
	XBin       => {
		filetypes => [ qw(Undefined) ],
		flags     => { 0 => 'None' }
	},
	Archive    => {
		filetypes => [ qw(ZIP ARJ LZH ARC TAR ZOO RAR UC2 PAK SQZ) ],
		flags     => { 0 => 'None' }
	},
	Executable => {
		filetypes => [ qw(Undefined) ],
		flags     => { 0 => 'None' }
	}
};

sub new {
	my( $class, $filename ) = @_;
	my $self = {
		filename => $filename
	};
	bless $self, $class;
	$self->clear;
	$self->read or return undef;
	return $self;
}

sub read {
	my $self = shift;
	my ($data, %data);

	# Stop if the file isn't big enough to hold a SAUCE record
	return 1 if -s $self->{filename} < 128;

	if ( not open( FILE, $self->{filename} ) ) {
		$@ = 'File open error (' . $self->{filename} . '): ' . " $!";
		return;
	}
	binmode( FILE );
	seek( FILE, -128, 2 );
	read( FILE, $data, 128 );
	close( FILE ) or carp('File close error (' . $self->{filename} . '): ' . " $!");

	# Stop if our data doesn't have a valid SAUCE ID
	return 1 unless $data =~ /^SAUCE/;

	@data{@sauce_fields} = unpack( $sauce_template, $data );
	$self->{record}      = \%data;

	# Do we have any comments?
	if ($self->{record}->{comments}) {
		if ( not open( FILE, $self->{filename} ) ) {
			$@ = 'File open error (' . $self->{filename} . '): ' . " $!";
			return;
		}
		binmode( FILE );
		seek( FILE, -128 - 5 - $self->{record}->{comments} * 64, 2 );
		read( FILE, $data, 5 + $self->{record}->{comments} * 64 );
		close( FILE ) or carp('File close error (' . $self->{filename} . '): ' . " $!");

		# We've been fooled, there weren't any comments
		return 1 unless $data =~ /^COMNT/;

		my ($id, @comment_temp) = unpack( (split(/ /, $comnt_template))[0] . ((split(/ /, $comnt_template))[1] x ((length($data) - 5) / 64)), $data );

		$self->{comments} = {
			id   => $id,
			data => \@comment_temp
		};
	}

	return 1;
}

sub write {
	my $self = shift;

	$self->remove;

	if ( not open( FILE, '>>' . $self->{filename} ) ) {
		$@ = 'File open error (' . $self->{filename} . '): ' . " $!";
		return;
	}

	binmode( FILE );

	# Fix values incase they've been changed
	$self->{record}->{id}       = SAUCE_ID;
	$self->{record}->{version}  = SAUCE_VERSION;
	$self->{record}->{filler}   = SAUCE_FILLER;
	$self->{comments}->{id}     = COMNT_ID;
	$self->{record}->{comments} = scalar @{$self->{comments}->{data}};
	$self->{record}->{filesize} = ( -s $self->{filename} );
	unless ($self->{record}->{date}) {
		my ($mday, $mon, $year) = (localtime((stat( FILE ))[9]))[3, 4, 5];
		$self->{record}->{date} = sprintf('%4d%02d%02d', $year += 1900, ++$mon, $mday);
	}

	my $record   = $self->{record};
	my $comments = $self->{comments};

	# EOF marker...
	print FILE chr(26);

	# Write comments
	print FILE pack( (split(/ /, $comnt_template))[0] . ((split(/ /, $comnt_template))[1] x $record->{comments}), $comments->{id}, @{$comments->{data}} ) if $record->{comments};

	# Write SAUCE
	for (0..$#sauce_fields) {
		print FILE pack( (split(/ /, $sauce_template))[$_], $record->{$sauce_fields[$_]} );
	}

	close( FILE ) or carp('File close error (' . $self->{filename} . '): ' . " $!");

	return 1;
}

sub remove {
	my $self = shift;
	my ($data, %data);

	# Stop if the file isn't big enough to hold a SAUCE record
	return 1 if -s $self->{filename} < 128;

	if ( not open( FILE, $self->{filename} ) ) {
		$@ = 'File open error (' . $self->{filename} . '): ' . " $!";
		return;
	}

	binmode( FILE );
	seek( FILE, -128, 2 );
	read( FILE, $data, 128 );
	close( FILE ) or carp('File close error (' . $self->{filename} . '): ' . " $!");

	# did it have SAUCE to begin with?
	return 1 unless $data =~ /^SAUCE/;

	@data{@sauce_fields} = unpack( $sauce_template, $data );

	if ( not open( FILE, '>>' . $self->{filename} ) ) {
		$@ = 'File open error (' . $self->{filename} . '): ' . " $!";
		return;
	}

	binmode( FILE );
	# I'm trusting the SAUCE record's comment field, that's probably a bad thing
	truncate( FILE, (stat(FILE))[7] - 128 - 1 - ($data{comments} ? 5 + $data{comments} * 64 : 0) ) or carp('File truncate error (' . $self->{filename} . '): ' . " $!");
	close( FILE ) or carp('File close error (' . $self->{filename} . '): ' . " $!");

	return 1;
}

sub clear {
	my $self = shift;

	# Set default SAUCE values
	$self->{record} = {
		id       => SAUCE_ID,
		version  => SAUCE_VERSION,
		title    => '',
		author   => '',
		group    => '',
		date     => '',
		filesize => 0,
		datatype => 0,
		filetype => 0,
		tinfo1   => 0,
		tinfo2   => 0,
		tinfo3   => 0,
		tinfo4   => 0,
		comments => 0,
		flags    => 0,
		filler   => SAUCE_FILLER
	};

	$self->{comments} = {
		id       => COMNT_ID,
		data     => []
	};
}

sub datatype {
	# Return the datatype name
	return $datatypes[$_[0]->{record}->{datatype}];
}

sub filetype {
	# Return the filetype name
	return $filetypes->{$_[0]->datatype}->{filetypes}->[$_[0]->{record}->{filetype}];
}

sub flags {
	# Return an english description of the flags
	return $filetypes->{$_[0]->datatype}->{flags}->{ord($_[0]->{record}->{flags})};
}

sub pretty_print {
	my $self = shift;

	print '      File: ', uc($self->{filename}), "\n";
	for (@sauce_fields) {
		if ($_ eq 'datatype' || $_ eq 'filetype' || $_ eq 'flags') {
			printf("%10s: %s\n", ucfirst($_), $self->$_);
		}
		elsif ($_ eq 'date') {
			printf("      Date: %04d/%02d/%02d\n", , substr($self->{record}->{date}, 0, 4), substr($self->{record}->{date}, 4, 2), substr($self->{record}->{date}, 6, 2));
		}
		else {
			printf("%10s: %s\n", ucfirst($_), $self->{record}->{$_});
		}
	}
	print 'Comment Id: ', $self->{comments}->{id}, "\n";
	print '  Comments: ';
	print "\n" unless $self->{record}->{comments};
	for (0..$#{$self->{comments}->{data}}) {
		printf($_ == 0 ? "%s\n" : "            %s\n", $self->{comments}->{data}->[$_]);
	}
}

# Mutator
sub set {
	my ( $self, %options ) = @_;

	for (  keys %options ) {
		if ( $_ eq 'comments' ) {
			$self->{record}->{comments} = scalar @{$options{$_}};
			$self->{comments}->{data} = $options{$_};
		}
		else {
			$self->{record}->{$_} = $options{$_};
		}
	}
}

# Accessor
sub get {
	my ( $self, @options ) = @_;

	my @return;
	for ( @options ) {
		push @return, /^comments$/ ? $self->{comments}->{data} : $self->{record}->{$_};
	}

	return wantarray ? @return : $return[0];
}

# Autoloaded accessors and mutators
sub AUTOLOAD {
	our $AUTOLOAD;

	my $self  = shift;
	my $value = shift;
	my $name  = $AUTOLOAD;
	$name     =~ s/^.*:://;

	return if $name =~ /DESTROY/;

	carp(sprintf "No method '$name' available in package %s.", __PACKAGE__) unless $name =~ /^(set|get)_(.+)/;

	return $self->get( $2 )  if $1 eq 'get'; 
	$self->set( $2, $value ) if $1 eq 'set'; 
}

1;

=pod

=head1 NAME

File::SAUCE - A library to manipulate SAUCE metadata

=head1 SYNOPSIS

	use File::SAUCE;

	my $ansi = File::SAUCE->new('myansi.ans');

	# Print the metadata...
	$ansi->pretty_print;

	# Get a value...
	my $title = $ansi->get_title;

	# Set a value...
	$ansi->set_title('ANSi is 1337');

	# Write the data...
	$ansi->write;

	# Clear the in-memory data...
	$ansi->clear;

	# Read the data... (Note, auto-read when new is called)
	$ansi->read;

	# Remove the data...
	$ansi->remove;

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
	| ID             | 5    | Char | COMNT   | N/A       |
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
	| ID             | 5    | Char | SAUCE   | id        |
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

For more information see ACiD.org's SAUCE page at http://www.acid.org/info/sauce/sauce.htm.

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

=item new($filename)

Creates a new File::SAUCE object. Reads the file's SAUCE data (by calling C<read>) if it has any.

=item read()

Explicitly read's all SAUCE data from the file.

=item write()

Writes the in-memory SAUCE data to the file. It calls C<remove> before writing the data.

=item remove()

Removes any SAUCE data from the file.

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