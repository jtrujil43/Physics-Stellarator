#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Physics::CPD::Stellarator;

my $w7x = Physics::CPD::Stellarator->new;
my %trace = (
    turns           => 5,
    points_per_turn => 72,
    scale           => 0.7,
    poloidal_angle  => 0,
);

my ($x, $y, $z) = $w7x->field_line(%trace);
my $length = $w7x->field_line_length(%trace);

printf "Idealized W7-X field-line trace\n";
printf "  rotational transform: %.3f\n", $w7x->rotational_transform;
printf "  samples:               %d\n", scalar @$x;
printf "  sampled path length:   %.2f m\n", $length;
print  "  one coordinate per toroidal turn (m):\n";
print  "    turn          x          y          z\n";
for my $turn (0 .. $trace{turns}) {
    my $index = $turn * $trace{points_per_turn};
    printf "    %4d %10.4f %10.4f %10.4f\n",
        $turn, $x->[$index], $y->[$index], $z->[$index];
}
