# $Id: Makefile.PL 11 2002-12-18 10:51:55Z mrodrigu $

use ExtUtils::MakeMaker;

# shamelessly lifted from YAML's Makefile.PL
my @programs;

for (split "\n", <<'QUERIES') {
xml_pp|y|XML pretty printer
xml_grep|y|XML grep - grep XML files using XML::Twig's subset of expat
xml_spellcheck|y|spellcheck XML files skipping tags
QUERIES
    my ($program, $default, $description) = split /\|/, $_;
    if (prompt("Do you want to install '$program' ($description)?", 
               $default) =~ /^y/) {
	push(@programs, $program);
    }
}

WriteMakefile(
    NAME	     => 'XML::Twig',
    ABSTRACT     => 'XML, The Perl Way',
    AUTHOR       => 'Michel Rodriguez <mirod@xmltwig.com>',
    EXE_FILES    => [ map {"tools/$_/$_"} @programs],
    VERSION_FROM => 'Twig.pm', # finds $VERSION
    PREREQ_PM    => { 'XML::Parser' => '2.23' },
    dist         => { COMPRESS    => 'gzip -9f',
                      SUFFIX	     => 'gz',
                    },
    'depend'     => { 'Twig.pm' => "Twig.pm.slow\n\t\$(PERL) speedup Twig.pm.slow > Twig.pm\n\t\$(PERL) check_optional_modules"},
);
