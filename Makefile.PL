use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'XML::Twig',
    'VERSION_FROM' => 'Twig.pm', # finds $VERSION
    'dist'  => { COMPRESS    => 'gzip -9f',
                 SUFFIX	     => 'gz',
               },
);
