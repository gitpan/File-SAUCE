use ExtUtils::MakeMaker;
WriteMakefile(
	NAME         => 'File::SAUCE',
	VERSION_FROM => 'lib/File/SAUCE.pm',
	PREREQ_PM    => {
		'Test::More'      => 0,
		'IO::File'        => 0,
		'IO::String'      => 0,
		'Time::Piece'     => 0,
		'File::Slurp'     => 0,
		'Class::Accessor' => 0
	},
);
