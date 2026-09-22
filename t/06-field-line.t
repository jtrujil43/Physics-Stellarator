use strict;
use warnings;
use Test::More;
use Physics::CPD::Stellarator;

my $w = Physics::CPD::Stellarator->new(iota => 0.96);
my %options = (
    turns           => 2,
    points_per_turn => 12,
    scale           => 0.7,
    poloidal_angle  => 0.2,
    toroidal_angle  => 0.3,
);
my ($x, $y, $z) = $w->field_line(%options);

is(scalar @$x, 25, 'two turns with twelve intervals return 25 points');
is(scalar @$y, scalar @$x, 'coordinate arrays have equal lengths');
is(scalar @$z, scalar @$x, 'all coordinate arrays have equal lengths');

my @start = $w->surface_point_xyz(0.2, 0.3, 0.7);
approx($x->[0], $start[0], 'trace starts at requested x');
approx($y->[0], $start[1], 'trace starts at requested y');
approx($z->[0], $start[2], 'trace starts at requested z');

my $pi = 3.14159265358979;
my @end = $w->surface_point_xyz(
    0.2 + 0.96 * 4 * $pi,
    0.3 + 4 * $pi,
    0.7,
);
approx($x->[-1], $end[0], 'endpoint follows du/dv = iota in x');
approx($y->[-1], $end[1], 'endpoint follows du/dv = iota in y');
approx($z->[-1], $end[2], 'endpoint follows du/dv = iota in z');

cmp_ok($w->field_line_length(%options), '>', 0, 'field-line length is positive');

# With iota=1, one full toroidal turn is also one full poloidal turn.
my ($cx, $cy, $cz) = $w->field_line(
    turns => 1, points_per_turn => 100, scale => 1, iota => 1,
);
approx($cx->[0], $cx->[-1], 'integer-iota trace closes in x', 1e-10);
approx($cy->[0], $cy->[-1], 'integer-iota trace closes in y', 1e-10);
approx($cz->[0], $cz->[-1], 'integer-iota trace closes in z', 1e-10);

# At scale zero, the trajectory is the magnetic axis and is independent of u.
my ($ax, $ay, $az) = $w->field_line(
    turns => 1, points_per_turn => 8, scale => 0,
    poloidal_angle => 1.7, iota => -0.4,
);
my @axis_start = $w->surface_point_xyz(0, 0, 0);
approx($ax->[0], $axis_start[0], 'scale zero starts on magnetic axis');
approx($ay->[0], $axis_start[1], 'axis y coordinate agrees');
approx($az->[0], $axis_start[2], 'axis z coordinate agrees');

for my $case (
    [ [ turns => 0 ], qr/turns must be a positive integer/, 'zero turns rejected' ],
    [ [ turns => 1.5 ], qr/turns must be a positive integer/, 'fractional turns rejected' ],
    [ [ points_per_turn => 0 ], qr/points_per_turn/, 'zero sampling rejected' ],
    [ [ scale => -0.1 ], qr/scale/, 'negative scale rejected' ],
    [ [ scale => 1.1 ], qr/scale/, 'scale above one rejected' ],
    [ [ poloidal_angle => 'north' ], qr/poloidal_angle/, 'non-numeric angle rejected' ],
    [ [ mystery => 1 ], qr/unknown field_line option/, 'unknown option rejected' ],
    [ [ 'turns' ], qr/expects named options/, 'odd option list rejected' ],
) {
    my ($args, $error, $name) = @$case;
    my $ok = eval { $w->field_line(@$args); 1 };
    ok(!$ok, $name);
    like($@, $error, "$name has a useful message");
}

done_testing;

sub approx {
    my ($got, $expected, $name, $tolerance) = @_;
    $tolerance = 1e-9 unless defined $tolerance;
    cmp_ok(abs($got - $expected), '<', $tolerance, $name);
}
