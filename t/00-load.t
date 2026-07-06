use strict;
use warnings;
use Test::More;

use_ok('Physics::CPD')              or BAIL_OUT('Physics::CPD failed to load');
use_ok('Physics::CPD::Stellerator') or BAIL_OUT('Physics::CPD::Stellerator failed to load');

ok( Physics::CPD->can('new'),              'Physics::CPD has a constructor' );
ok( Physics::CPD::Stellerator->can('new'), 'Stellerator has a constructor' );

my $s = Physics::CPD::Stellerator->new;
isa_ok( $s, 'Physics::CPD::Stellerator', 'object' );
isa_ok( $s, 'Physics::CPD', 'inherits from Physics::CPD' );

done_testing;
