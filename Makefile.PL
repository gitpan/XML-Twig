use ExtUtils::MakeMaker;

sub MY::speedup 
 { "Twig.pm: Twig.pm.slow\n\tspeedup Twig.pm.slow > Twig.pm\n";    }


WriteMakefile(
    'NAME'	=> 'XML::Twig',
    'VERSION_FROM' => 'Twig.pm', # finds $VERSION
    'dist'  => { COMPRESS    => 'gzip -9f',
                 SUFFIX	     => 'gz',
               },
    'depend' => { 'Twig.pm' => "Twig.pm.slow\n\tperl speedup Twig.pm.slow > Twig.pm\n"},
);
