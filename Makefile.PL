use ExtUtils::MakeMaker;


WriteMakefile(
    'NAME'	=> 'XML::Twig',
    'ABSTRACT'  => 'XML, The Perl Way',
    'AUTHOR'    => 'Michel Rodriguez <mirod@xmltwig.com>',
    'VERSION_FROM' => 'Twig.pm', # finds $VERSION
    'PREREQ_PM' => { 'XML::Parser' => '2.23' },
    'dist'  => { COMPRESS    => 'gzip -9f',
                 SUFFIX	     => 'gz',
               },
    'depend' => { 'Twig.pm' => "Twig.pm.slow\n\tperl speedup Twig.pm.slow > Twig.pm\n\tperl check_optional_modules"},
);
