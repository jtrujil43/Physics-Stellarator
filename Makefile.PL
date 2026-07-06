use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Physics::CPD',
    DISTNAME      => 'Physics-Stellarator',
    VERSION_FROM  => 'lib/Physics/CPD/Stellarator.pm',
    ABSTRACT      => 'Computational plasma dynamics with Wendelstein 7-X stellarator modelling and 3-D visualisation',
    AUTHOR        => 'Physics-Stellarator project',
    LICENSE       => 'gpl_3',
    MIN_PERL_VERSION => '5.010',

    # Core physics only needs Moo; plotting needs PDL (declared as recommended).
    PREREQ_PM => {
        'Moo'         => 0,
        'Carp'        => 0,
        'Test::More'  => 0,
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs     => {
            runtime => {
                recommends => {
                    'PDL'                     => 0,
                    'PDL::Graphics::Gnuplot'  => 0,
                },
            },
        },
        resources => {
            homepage => 'https://www.ipp.mpg.de/w7x',
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES    => 'Physics-Stellarator-* *.png' },
);
