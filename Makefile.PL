use 5.028001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# my $JSON = "$ENV{HOME}/KSP/KSP_linux/GameData/SolarSystemDump/SolarSystemDump.json";
# -f $JSON and system "cp", "-v", $JSON, "lib/KSP";

WriteMakefile(
    NAME              => 'KSP',
    VERSION_FROM      => 'lib/KSP.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/KSP.pm', # retrieve abstract from module
    AUTHOR            => 'peteletroll',
    LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
    'EXE_FILES'       => [qw(bin/ksp bin/ksp-parse bin/ksp-delta-v bin/ksp-shell bin/ksp-sfs-sql bin/ksp-dds-tool bin/ksp-mbm2any bin/ksp-mbminfo)],
    dist => {
	    COMPRESS => "gzip -f",
    },
);
