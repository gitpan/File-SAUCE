use ExtUtils::MakeMaker;
WriteMakefile(
	NAME         => 'File::SAUCE',
	VERSION_FROM => 'lib/File/SAUCE.pm',
	PREREQ_PM    => {
		'Test::More' => 0
	},
);
