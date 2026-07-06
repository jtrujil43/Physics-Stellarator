package Physics::CPD::Stellerator;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

extends 'Physics::CPD';

our $VERSION = '0.01';

use constant PI => 3.14159265358979;

#---------------------------------------------------------------------------
# Default Wendelstein 7-X-like boundary (VMEC-style Fourier series).
#
#   R(u,v) = sum  Rbc(m,n) cos(m u - n Nfp v)
#   Z(u,v) = sum  Zbs(m,n) sin(m u - n Nfp v)
#
# u = poloidal angle, v = toroidal angle, Nfp = number of field periods.
# Each element is [ m, n, Rbc, Zbs ] in metres.  The m=0 terms define the
# helical magnetic axis; m>=1 terms define the rotating, bean-shaped cross
# section that gives the stellarator its characteristic five-fold twist.
#---------------------------------------------------------------------------
sub _default_boundary_coeffs {
    return [
        [ 0, 0,  5.50,  0.00 ],   # major radius R0
        [ 0, 1, -0.28, -0.18 ],   # major-radius breathing + axis excursion
        [ 1, 0,  0.50,  0.55 ],   # base (elongated) cross section
        [ 1, 1,  0.26, -0.28 ],   # rotating elongation -> bean shape + twist
        [ 2, 0, -0.05,  0.04 ],   # triangularity
        [ 2, 1, -0.05,  0.04 ],   # triangularity modulation
    ];
}

#---------------------------------------------------------------------------
# Device attributes  (defaults describe Wendelstein 7-X)
#---------------------------------------------------------------------------
has config_name => (
    is      => 'rw',
    default => sub { 'Wendelstein 7-X (standard EIM configuration)' },
);

has major_radius => (            # R0  [m]
    is      => 'rw',
    default => sub { 5.5 },
);

has minor_radius => (            # a  [m]
    is      => 'rw',
    default => sub { 0.53 },
);

has num_field_periods => (       # Nfp
    is      => 'rw',
    default => sub { 5 },
);

has iota => (                    # rotational transform (effective, ~2/3 radius)
    is      => 'rw',
    default => sub { 0.96 },
);

has heating_power => (           # P  [MW]
    is      => 'rw',
    default => sub { 10 },
);

has num_nonplanar_coils => (
    is      => 'rw',
    default => sub { 50 },
);

has num_planar_coils => (
    is      => 'rw',
    default => sub { 20 },
);

has beta_limit => (              # design MHD beta limit
    is      => 'rw',
    default => sub { 0.05 },
);

has pulse_length => (            # [s]
    is      => 'rw',
    default => sub { 1800 },
);

has gyrotron_frequency => (      # ECRH gyrotron frequency  [Hz]
    is      => 'rw',
    default => sub { 140e9 },
);

has boundary_coeffs => (
    is      => 'rw',
    default => \&_default_boundary_coeffs,
);

# --- coil-geometry styling (used by the 3-D diagram) ---
has coil_radius     => ( is => 'rw', default => sub { 0.95 } );  # [m]
has coil_elongation => ( is => 'rw', default => sub { 1.25 } );
has coil_tilt       => ( is => 'rw', default => sub { 0.16 } );  # rad

# W7-X runs a strong field; override the CPD default of 1 T.
has '+magnetic_field' => ( default => sub { 2.5 } );

#---------------------------------------------------------------------------
# Basic device geometry
#---------------------------------------------------------------------------
sub aspect_ratio {
    my ($self) = @_;
    return $self->major_radius / $self->minor_radius;
}

# Toroidal angle spanned by one field period  [rad]
sub field_period_angle {
    my ($self) = @_;
    return 2 * PI / $self->num_field_periods;
}

# Plasma volume of the toroidal plasma  V = 2 pi^2 R0 a^2  [m^3]
sub plasma_volume {
    my ($self) = @_;
    return 2 * PI**2 * $self->major_radius * $self->minor_radius**2;
}

# Plasma surface area (approx.)  S = 4 pi^2 R0 a  [m^2]
sub plasma_surface_area {
    my ($self) = @_;
    return 4 * PI**2 * $self->major_radius * $self->minor_radius;
}

# Rotational transform and its inverse, the stellarator "safety factor"
sub rotational_transform { $_[0]->iota }
sub safety_factor        { 1 / $_[0]->iota }

#---------------------------------------------------------------------------
# Confinement, limits and fusion figures of merit
#---------------------------------------------------------------------------
# ISS04 international stellarator energy-confinement scaling  [s]
#   tau_E = 0.134 a^2.28 R^0.64 P^-0.61 n19^0.54 B^0.84 iota^0.41
# a,R in m; P in MW; n19 = line-averaged density in 1e19 m^-3; B in T.
sub confinement_time_iss04 {
    my ($self) = @_;
    my $a    = $self->minor_radius;
    my $R    = $self->major_radius;
    my $P    = $self->heating_power;
    my $n19  = $self->electron_density / 1e19;
    my $B    = $self->magnetic_field;
    my $iota = $self->iota;
    return 0.134
        * $a**2.28
        * $R**0.64
        * $P**-0.61
        * $n19**0.54
        * $B**0.84
        * $iota**0.41;
}

# Stored thermal plasma energy  W = (3/2) p V  [J]
sub stored_energy {
    my ($self) = @_;
    return 1.5 * $self->plasma_pressure * $self->plasma_volume;
}
sub stored_energy_MJ { $_[0]->stored_energy / 1e6 }

# Sudo density limit for stellarators  [m^-3]
#   n_max = 0.25 * sqrt( P B / (a^2 R) ) * 1e20 ;  P in MW, B in T, a,R in m.
sub sudo_density_limit {
    my ($self) = @_;
    return 0.25
        * sqrt( $self->heating_power * $self->magnetic_field
                / ( $self->minor_radius**2 * $self->major_radius ) )
        * 1e20;
}

# Fraction of the design beta limit currently used
sub beta_fraction {
    my ($self) = @_;
    return $self->plasma_beta / $self->beta_limit;
}

# Fraction of the Sudo density limit currently used
sub density_fraction {
    my ($self) = @_;
    return $self->electron_density / $self->sudo_density_limit;
}

# Lawson triple product  n T_i tau_E  [keV s m^-3]
sub triple_product {
    my ($self) = @_;
    return $self->electron_density
        * ( $self->ion_temperature / 1000 )      # eV -> keV
        * $self->confinement_time_iss04;
}

# Resonant field for electron-cyclotron heating at the gyrotron frequency
#   f = n * (e B) / (2 pi m_e)  ->  B_res = 2 pi m_e f / (n e)
sub ecrh_resonance_field {
    my ( $self, $harmonic ) = @_;
    $harmonic ||= 2;   # W7-X uses 2nd-harmonic X-mode at 2.5 T / 140 GHz
    return 2 * PI * Physics::CPD::ELECTRON_MASS() * $self->gyrotron_frequency
        / ( $harmonic * Physics::CPD::ELEMENTARY_CHARGE() );
}

#---------------------------------------------------------------------------
# Radial profiles (illustrative, peaked shapes)
#   x = r/a in [0,1];  f(x) = f0 (1 - x^2)^alpha
#---------------------------------------------------------------------------
sub density_profile {
    my ( $self, $x, $alpha ) = @_;
    $alpha = defined $alpha ? $alpha : 0.5;
    my $v = 1 - $x * $x;
    $v = 0 if $v < 0;
    return $self->electron_density * $v**$alpha;
}

sub temperature_profile {
    my ( $self, $x, $alpha ) = @_;
    $alpha = defined $alpha ? $alpha : 2.0;
    my $v = 1 - $x * $x;
    $v = 0 if $v < 0;
    return $self->electron_temperature * $v**$alpha;
}

#===========================================================================
# GEOMETRY  (pure Perl; returns array references so no PDL is required)
#===========================================================================
# Evaluate the Fourier boundary at (u,v).  A scale in [0,1] shrinks the
# poloidal (m>=1) modes toward the axis, generating nested flux surfaces.
sub boundary_point {
    my ( $self, $u, $v, $scale ) = @_;
    $scale = 1 unless defined $scale;
    my $Nfp = $self->num_field_periods;
    my ( $R, $Z ) = ( 0, 0 );
    for my $c ( @{ $self->boundary_coeffs } ) {
        my ( $m, $n, $rbc, $zbs ) = @$c;
        my $sc  = $m == 0 ? 1 : $scale;
        my $ang = $m * $u - $n * $Nfp * $v;
        $R += $sc * $rbc * cos($ang);
        $Z += $sc * $zbs * sin($ang);
    }
    return ( $R, $Z );
}

# Cartesian point on a flux surface at (u,v).
sub surface_point_xyz {
    my ( $self, $u, $v, $scale ) = @_;
    my ( $R, $Z ) = $self->boundary_point( $u, $v, $scale );
    return ( $R * cos($v), $R * sin($v), $Z );
}

# Magnetic axis: the m=0 part of the boundary (scale = 0).
# Returns ($x_aref, $y_aref, $z_aref) for $n samples over the full torus.
sub magnetic_axis {
    my ( $self, $n ) = @_;
    $n ||= 400;
    my ( @X, @Y, @Z );
    for my $i ( 0 .. $n ) {
        my $v = 2 * PI * $i / $n;
        my ( $x, $y, $z ) = $self->surface_point_xyz( 0, $v, 0 );
        push @X, $x;
        push @Y, $y;
        push @Z, $z;
    }
    return ( \@X, \@Y, \@Z );
}

# One poloidal cross section (R,Z) at toroidal angle $v.
# Returns ($R_aref, $Z_aref).
sub cross_section {
    my ( $self, $v, $nu, $scale ) = @_;
    $nu ||= 200;
    my ( @R, @Z );
    for my $i ( 0 .. $nu ) {
        my $u = 2 * PI * $i / $nu;
        my ( $r, $z ) = $self->boundary_point( $u, $v, $scale );
        push @R, $r;
        push @Z, $z;
    }
    return ( \@R, \@Z );
}

# Flux-surface grid as arrays-of-arrays [nu+1][nv+1] for X, Y, Z.
sub surface_grid {
    my ( $self, $nu, $nv, $scale ) = @_;
    $nu ||= 60;
    $nv ||= 180;
    my ( @X, @Y, @Z );
    for my $i ( 0 .. $nu ) {
        my $u = 2 * PI * $i / $nu;
        my ( @xr, @yr, @zr );
        for my $j ( 0 .. $nv ) {
            my $v = 2 * PI * $j / $nv;
            my ( $x, $y, $z ) = $self->surface_point_xyz( $u, $v, $scale );
            push @xr, $x;
            push @yr, $y;
            push @zr, $z;
        }
        push @X, \@xr;
        push @Y, \@yr;
        push @Z, \@zr;
    }
    return ( \@X, \@Y, \@Z );
}

# Modular coils as tilted, elongated rings following the magnetic axis.
# Returns a list of coil loops, each an arrayref [ $x_aref, $y_aref, $z_aref ].
sub modular_coils {
    my ( $self, $count, $npts ) = @_;
    $count ||= 2 * $self->num_field_periods;   # readable subset of the 50 coils
    $npts  ||= 120;
    my $rc    = $self->coil_radius;
    my $elong = $self->coil_elongation;
    my $tilt  = $self->coil_tilt;
    my @coils;
    for my $k ( 0 .. $count - 1 ) {
        my $phic = ( $k + 0.5 ) * 2 * PI / $count;
        my ( $Rc0, $Zc0 ) = $self->boundary_point( 0, $phic, 0 );   # axis centre
        my ( @X, @Y, @Z );
        for my $i ( 0 .. $npts ) {
            my $u   = 2 * PI * $i / $npts;
            my $dR  = $rc * cos($u);
            my $dZ  = $rc * $elong * sin($u);
            my $phi = $phic + $tilt * sin($u) / $Rc0;
            my $R   = $Rc0 + $dR;
            my $Z   = $Zc0 + $dZ;
            push @X, $R * cos($phi);
            push @Y, $R * sin($phi);
            push @Z, $Z;
        }
        push @coils, [ \@X, \@Y, \@Z ];
    }
    return @coils;
}

#===========================================================================
# PLOTTING  (lazily loads PDL + PDL::Graphics::Gnuplot; writes to a file)
#===========================================================================
sub _new_gpwin {
    my ( $self, %o ) = @_;
    eval {
        require PDL;
        require PDL::Graphics::Gnuplot;
        1;
    } or croak
        "Plotting requires PDL and PDL::Graphics::Gnuplot to be installed: $@";
    my $output = $o{output}   || 'stellarator.png';
    my $term   = $o{terminal} || 'pngcairo';
    my $size   = $o{size}     || [ 10, 8 ];
    my $w = PDL::Graphics::Gnuplot->new(
        $term,
        output => $output,
        size   => $size,
    );
    return $w;
}

# turn an arrayref (or array-of-arrays) into a PDL piddle
sub _pdl { require PDL; return PDL->pdl( $_[0] ); }

# --- 3-D diagram of the stellarator design -------------------------------
# Draws the last-closed flux surface, the helical magnetic axis and a set of
# modular field coils.  Options: output, title, size, view [az,el],
# show_axis, show_coils, coil_count, nu, nv, surface_scale.
sub plot_3d {
    my ( $self, %o ) = @_;
    my $w = $self->_new_gpwin(%o);

    my $nu    = $o{nu} || 54;
    my $nv    = $o{nv} || 170;
    my $scale = defined $o{surface_scale} ? $o{surface_scale} : 1;
    my $view  = $o{view} || [ 62, 25 ];
    my $title = defined $o{title} ? $o{title}
              : $self->config_name . ' - 3D design';

    my @items;

    # last-closed flux surface (wireframe)
    my ( $X, $Y, $Z ) = $self->surface_grid( $nu, $nv, $scale );
    push @items,
        ( { with => 'lines', lc => '#c8b0e8' },
          _pdl($X), _pdl($Y), _pdl($Z) );

    # helical magnetic axis
    if ( !defined $o{show_axis} || $o{show_axis} ) {
        my ( $ax, $ay, $az ) = $self->magnetic_axis( 400 );
        push @items,
            ( { with => 'lines', lw => 3, lc => '#000000' },
              _pdl($ax), _pdl($ay), _pdl($az) );
    }

    # modular coils
    if ( !defined $o{show_coils} || $o{show_coils} ) {
        for my $coil ( $self->modular_coils( $o{coil_count} ) ) {
            push @items,
                ( { with => 'lines', lw => 2, lc => '#d83010' },
                  _pdl( $coil->[0] ), _pdl( $coil->[1] ), _pdl( $coil->[2] ) );
        }
    }

    $w->plot3d(
        {   trid   => 1,
            title  => $title,
            view   => $view,
            xlabel => 'X (m)',
            ylabel => 'Y (m)',
            zlabel => 'Z (m)',
        },
        @items,
    );
    $w->close;
    return $o{output} || 'stellarator.png';
}

# --- nested flux-surface cross sections over one field period ------------
# Options: output, title, size, n_angles, n_surfaces, nu.
sub plot_cross_sections {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_cross_sections.png';
    my $w = $self->_new_gpwin(%o);

    my $nang  = $o{n_angles}   || 5;
    my $nsurf = $o{n_surfaces} || 6;
    my $nu    = $o{nu}         || 200;
    my $title = defined $o{title} ? $o{title}
              : 'Flux-surface cross sections over one field period';

    my @plots;
    my @palette = (
        '#1f77b4', '#d62728', '#2ca02c', '#9467bd',
        '#ff7f0e', '#17becf', '#8c564b', '#e377c2',
    );
    for my $a ( 0 .. $nang - 1 ) {
        my $v = ( $nang > 1 ? $a / ( $nang - 1 ) : 0 )
              * $self->field_period_angle;
        my $color = $palette[ $a % @palette ];
        for my $s ( 1 .. $nsurf ) {
            my $scale = $s / $nsurf;
            my ( $R, $Z ) = $self->cross_section( $v, $nu, $scale );
            my %style = ( with => 'lines', lc => $color );
            $style{legend} = sprintf( 'phi = %.0f deg', $v * 180 / PI )
                if $s == $nsurf;    # label only the outermost surface
            push @plots, ( \%style, _pdl($R), _pdl($Z) );
        }
    }

    $w->plot(
        {   title  => $title,
            xlabel => 'R (m)',
            ylabel => 'Z (m)',
        },
        @plots,
    );
    $w->close;
    return $o{output};
}

# --- radial density and temperature profiles -----------------------------
sub plot_profiles {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_profiles.png';
    my $w = $self->_new_gpwin(%o);

    my $n     = $o{n_points} || 100;
    my $alpha_n = defined $o{alpha_n} ? $o{alpha_n} : 0.5;
    my $alpha_T = defined $o{alpha_T} ? $o{alpha_T} : 2.0;

    my ( @x, @ne, @te );
    for my $i ( 0 .. $n ) {
        my $xr = $i / $n;
        push @x,  $xr;
        push @ne, $self->density_profile( $xr, $alpha_n ) / 1e19;   # 1e19 m^-3
        push @te, $self->temperature_profile( $xr, $alpha_T ) / 1000; # keV
    }

    $w->plot(
        {   title  => 'W7-X radial profiles (illustrative)',
            xlabel => 'normalised minor radius  r/a',
            ylabel => 'n_e (1e19 m^-3)  /  T_e (keV)',
        },
        ( { with => 'lines', lw => 2, legend => 'n_e (1e19 m^-3)' },
          _pdl( \@x ), _pdl( \@ne ) ),
        ( { with => 'lines', lw => 2, legend => 'T_e (keV)' },
          _pdl( \@x ), _pdl( \@te ) ),
    );
    $w->close;
    return $o{output};
}

# --- ISS04 confinement-time parameter scan --------------------------------
# Scans one attribute (default 'heating_power') and plots tau_E(ISS04).
sub plot_confinement_scan {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_confinement.png';
    my $w = $self->_new_gpwin(%o);

    my $param = $o{parameter} || 'heating_power';
    my $from  = defined $o{from} ? $o{from} : 1;
    my $to    = defined $o{to}   ? $o{to}   : 20;
    my $n     = $o{n_points} || 60;

    my $saved = $self->$param;                 # restore afterwards
    my ( @x, @tau );
    for my $i ( 0 .. $n ) {
        my $val = $from + ( $to - $from ) * $i / $n;
        $self->$param($val);
        push @x,   $val;
        push @tau, $self->confinement_time_iss04;
    }
    $self->$param($saved);

    ( my $plabel = $param ) =~ s/_/ /g;        # avoid gnuplot subscripting
    $w->plot(
        {   title  => "ISS04 confinement time vs $plabel",
            xlabel => $plabel,
            ylabel => 'tau_E (s)',
        },
        ( { with => 'lines', lw => 2, legend => 'tau_E (ISS04)' },
          _pdl( \@x ), _pdl( \@tau ) ),
    );
    $w->close;
    return $o{output};
}

#---------------------------------------------------------------------------
# Reporting
#---------------------------------------------------------------------------
sub device_report {
    my ($self) = @_;
    my @l;
    push @l, "== Stellarator device: " . $self->config_name . " ==";
    push @l, sprintf( "  major radius       R0     = %.3f m", $self->major_radius );
    push @l, sprintf( "  minor radius       a      = %.3f m", $self->minor_radius );
    push @l, sprintf( "  aspect ratio       R0/a   = %.2f",  $self->aspect_ratio );
    push @l, sprintf( "  field periods      Nfp    = %d",    $self->num_field_periods );
    push @l, sprintf( "  rotational transf. iota   = %.3f (q = %.3f)",
        $self->iota, $self->safety_factor );
    push @l, sprintf( "  magnetic field     B      = %.2f T", $self->magnetic_field );
    push @l, sprintf( "  plasma volume      V      = %.2f m^3", $self->plasma_volume );
    push @l, sprintf( "  plasma surface     S      = %.2f m^2", $self->plasma_surface_area );
    push @l, sprintf( "  non-planar coils          = %d", $self->num_nonplanar_coils );
    push @l, sprintf( "  planar coils              = %d", $self->num_planar_coils );
    push @l, "  -- operating point --";
    push @l, sprintf( "  heating power      P      = %.1f MW", $self->heating_power );
    push @l, sprintf( "  electron density   n_e    = %.3e m^-3", $self->electron_density );
    push @l, sprintf( "  electron temp.     T_e    = %.2f keV", $self->electron_temperature / 1000 );
    push @l, sprintf( "  ion temperature    T_i    = %.2f keV", $self->ion_temperature / 1000 );
    push @l, "  -- derived performance --";
    push @l, sprintf( "  ISS04 confinement  tau_E  = %.3f s", $self->confinement_time_iss04 );
    push @l, sprintf( "  stored energy      W      = %.2f MJ", $self->stored_energy_MJ );
    push @l, sprintf( "  plasma beta        beta   = %.2f %%  (%.0f%% of limit)",
        100 * $self->plasma_beta, 100 * $self->beta_fraction );
    push @l, sprintf( "  Sudo density limit n_max  = %.3e m^-3  (%.0f%% used)",
        $self->sudo_density_limit, 100 * $self->density_fraction );
    push @l, sprintf( "  triple product n T tau    = %.3e keV s m^-3", $self->triple_product );
    push @l, sprintf( "  ECRH 2nd-harm. res. field = %.2f T (at %.0f GHz)",
        $self->ecrh_resonance_field(2), $self->gyrotron_frequency / 1e9 );
    return join( "\n", @l ) . "\n";
}

1;

__END__

=head1 NAME

Physics::CPD::Stellerator - Model and visualise the Wendelstein 7-X stellarator

=head1 SYNOPSIS

    use Physics::CPD::Stellerator;

    my $w7x = Physics::CPD::Stellerator->new(
        electron_density     => 8e19,    # m^-3
        electron_temperature => 4000,    # eV
        ion_temperature      => 2000,    # eV
        magnetic_field       => 2.5,     # T
        heating_power        => 10,      # MW
    );

    print $w7x->device_report;

    printf "ISS04 tau_E = %.3f s\n", $w7x->confinement_time_iss04;
    printf "stored W    = %.1f MJ\n", $w7x->stored_energy_MJ;

    # visualisations (written to PNG files)
    $w7x->plot_3d( output => 'w7x_3d.png' );
    $w7x->plot_cross_sections( output => 'w7x_cross.png' );
    $w7x->plot_profiles( output => 'w7x_profiles.png' );
    $w7x->plot_confinement_scan( parameter => 'heating_power',
                                 from => 1, to => 20 );

=head1 DESCRIPTION

C<Physics::CPD::Stellerator> extends L<Physics::CPD> with the geometry and
engineering/plasma parameters needed to simulate a I<stellarator>, using the
B<Wendelstein 7-X> (W7-X) device at IPP Greifswald as its default
configuration.  It inherits every plasma calculation of the base class and
adds:

=over 4

=item * device parameters - major/minor radius, five field periods, coil
counts, rotational transform C<iota>, design beta limit, pulse length;

=item * derived physics - aspect ratio, plasma volume and surface, the ISS04
international stellarator confinement-time scaling, stored thermal energy, the
Sudo density limit, plasma-beta and density-limit fractions, the Lawson triple
product, and the electron-cyclotron-heating resonant field;

=item * three-dimensional geometry - the last-closed flux surface described as
a VMEC-style Fourier series R(u,v), Z(u,v), the helical magnetic axis, nested
flux surfaces and a set of tilted modular field coils; and

=item * plotting - 3-D design diagrams, poloidal cross sections through a field
period, radial profiles and confinement-scaling scans, rendered with
L<PDL::Graphics::Gnuplot>.

=back

Geometry accessors (C<boundary_point>, C<magnetic_axis>, C<cross_section>,
C<surface_grid>, C<modular_coils>) are pure Perl and return array references,
so they can be used and tested without PDL.  Only the C<plot_*> methods require
L<PDL> and L<PDL::Graphics::Gnuplot>; they are loaded on demand and render to an
image file (default terminal C<pngcairo>), so they work on headless machines.

=head1 KEY ATTRIBUTES

C<config_name>, C<major_radius> (5.5 m), C<minor_radius> (0.53 m),
C<num_field_periods> (5), C<iota> (0.96), C<magnetic_field> (2.5 T),
C<heating_power> (10 MW), C<num_nonplanar_coils> (50), C<num_planar_coils>
(20), C<beta_limit> (0.05), C<pulse_length> (1800 s),
C<gyrotron_frequency> (140 GHz), and C<boundary_coeffs> (the Fourier boundary,
overridable to model any stellarator equilibrium).

=head1 PHYSICS METHODS

C<aspect_ratio>, C<plasma_volume>, C<plasma_surface_area>,
C<rotational_transform>, C<safety_factor>, C<confinement_time_iss04>,
C<stored_energy> / C<stored_energy_MJ>, C<sudo_density_limit>,
C<beta_fraction>, C<density_fraction>, C<triple_product>,
C<ecrh_resonance_field>, C<density_profile>, C<temperature_profile>,
C<device_report>.

=head1 GEOMETRY METHODS

C<boundary_point($u,$v,$scale)>, C<surface_point_xyz>, C<magnetic_axis($n)>,
C<cross_section($v,$nu,$scale)>, C<surface_grid($nu,$nv,$scale)>,
C<modular_coils($count,$npts)>.

=head1 PLOTTING METHODS

C<plot_3d>, C<plot_cross_sections>, C<plot_profiles>,
C<plot_confinement_scan>.  Each accepts an C<output> filename (and optional
C<terminal>, C<size> and method-specific options) and returns the filename it
wrote.

=head1 SEE ALSO

L<Physics::CPD>, L<PDL::Graphics::Gnuplot>.

W7-X reference: Klinger et al., "Overview of first Wendelstein 7-X high-
performance operation", Nucl. Fusion 59 (2019).  ISS04 scaling: Yamada et al.,
Nucl. Fusion 45 (2005) 1684.

=head1 AUTHOR

Generated for the Physics-Stellerator project.

=head1 LICENSE

Copyright (C) 2026 the Physics-Stellerator authors.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.  See L<https://www.gnu.org/licenses/gpl-3.0.html>.

=cut
