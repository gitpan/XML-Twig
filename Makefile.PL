# $Id: Makefile.PL,v 1.4 2002/06/24 21:38:19 mrodrigu Exp $

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
    'depend' => { 'Twig.pm' => "Twig.pm.slow\n\t\$(PERL) speedup Twig.pm.slow > Twig.pm\n\t\$(PERL) check_optional_modules"},
);
