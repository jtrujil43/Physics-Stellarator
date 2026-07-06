# Physics-Stellerator

Computational plasma dynamics in Perl, with a full model and 3‑D visualisation
of the **Wendelstein 7‑X** stellarator.

The distribution provides two modules:

| Module | Role |
|--------|------|
| **`Physics::CPD`** | Pure‑Perl *Computational Plasma Dynamics* engine — fundamental magnetised‑plasma parameters from density, temperature, magnetic field and ion species. |
| **`Physics::CPD::Stellerator`** | Extends `Physics::CPD` with stellarator geometry and physics, using **Wendelstein 7‑X** (W7‑X, IPP Greifswald) as the default configuration, plus plotting and 3‑D design diagrams. |

> **A note on spelling.** The correct English term is *stellarator*. This
> distribution uses the module name **`Physics::CPD::Stellerator`** (with an
> `e`) exactly as requested; the physics and documentation refer to the real
> *stellarator* concept and the Wendelstein 7‑X device.

---

## Features

### `Physics::CPD` — plasma physics engine (no heavy dependencies)

* Characteristic frequencies: electron/ion **plasma** and **cyclotron** frequencies.
* Characteristic lengths/speeds: **Debye length**, electron/ion **Larmor radii**,
  **thermal**, **Alfvén** and **ion‑sound** speeds.
* Energetics: kinetic and magnetic **pressure**, **plasma β**.
* Collisional transport (NRL Plasma Formulary): **Coulomb logarithm**,
  **collision frequency**, **mean free path**, **Spitzer resistivity**.
* Multi‑species ions (`H, D, T, He, He3, C, O, …`); temperatures in **eV**.

### `Physics::CPD::Stellerator` — Wendelstein 7‑X model

* Device parameters: major/minor radius, **5 field periods**, coil counts,
  rotational transform *ι*, design **β limit**, pulse length, ECRH gyrotron.
* Derived physics: **aspect ratio**, **plasma volume/surface**,
  **ISS04 confinement‑time scaling**, **stored energy**, the stellarator
  **Sudo density limit**, β/density‑limit fractions, the **Lawson triple
  product**, and the **ECRH resonant field**.
* 3‑D geometry: the last‑closed flux surface as a **VMEC‑style Fourier series**
  `R(u,v), Z(u,v)`, the **helical magnetic axis**, nested flux surfaces and
  **modular field coils** — fully parameterised so you can model other
  stellarators by supplying your own boundary coefficients.
* Plotting via `PDL::Graphics::Gnuplot` (headless‑safe PNG output):
  **3‑D design diagram**, **poloidal cross sections**, **radial profiles**,
  **confinement scans**.

---

## Installation

```sh
perl Makefile.PL
make
make test
make install
```

Requirements:

* **Runtime (core physics):** [`Moo`](https://metacpan.org/pod/Moo).
* **Plotting / 3‑D (optional):** [`PDL`](https://metacpan.org/pod/PDL),
  [`PDL::Graphics::Gnuplot`](https://metacpan.org/pod/PDL::Graphics::Gnuplot)
  and a `gnuplot` binary. These are loaded on demand — the physics API works
  without them.

---

## Quick start

### Plasma parameters

```perl
use Physics::CPD;

my $plasma = Physics::CPD->new(
    electron_density     => 1e20,   # m^-3
    electron_temperature => 5000,   # eV
    ion_temperature      => 3000,   # eV
    magnetic_field       => 3.0,    # T
    ion_species          => 'D',
);

print $plasma->report;
printf "beta = %.2f %%\n", 100 * $plasma->plasma_beta;
```

### Wendelstein 7‑X

```perl
use Physics::CPD::Stellerator;

my $w7x = Physics::CPD::Stellerator->new(
    electron_density     => 8e19,
    electron_temperature => 4000,
    ion_temperature      => 2500,
    magnetic_field       => 2.5,
    heating_power        => 10,     # MW
);

print $w7x->device_report;

printf "ISS04 tau_E = %.3f s\n",  $w7x->confinement_time_iss04;
printf "stored W    = %.1f MJ\n", $w7x->stored_energy_MJ;

# Visualisations (PNG files)
$w7x->plot_3d( output => 'w7x_3d.png' );              # 3-D design diagram
$w7x->plot_cross_sections( output => 'w7x_cross.png');# flux-surface sections
$w7x->plot_profiles( output => 'w7x_profiles.png' );  # radial profiles
$w7x->plot_confinement_scan( output => 'w7x_conf.png',
                             parameter => 'heating_power', from => 1, to => 20 );
```

The 3‑D diagram shows the twisted, bean‑shaped plasma boundary (the five field
periods), the helical magnetic axis and the tilted modular coils.

---

## Examples

Runnable scripts in [`examples/`](examples):

* `plasma_parameters.pl` — `Physics::CPD` standalone.
* `w7x_simulation.pl` — W7‑X report and a density scan (τ_E, triple product, β).
* `plot_3d_design.pl` — writes all four PNG visualisations
  (`perl examples/plot_3d_design.pl [output_dir]`).

---

## Wendelstein 7‑X reference parameters (defaults)

| Quantity | Value |
|----------|-------|
| Major radius `R0` | 5.5 m |
| Minor radius `a` | 0.53 m |
| Aspect ratio | ≈ 10.4 |
| Field periods | 5 |
| Magnetic field | up to 3 T (2.5 T typical) |
| Plasma volume | ≈ 30 m³ |
| Non‑planar / planar coils | 50 / 20 |
| Rotational transform *ι* | ≈ 0.8 – 1.2 |
| ECRH | 140 GHz, 2nd‑harmonic X‑mode → 2.5 T |
| Design β limit | ≈ 5 % |

---

## Physics references

* Klinger *et al.*, “Overview of first Wendelstein 7‑X high‑performance
  operation”, *Nucl. Fusion* **59** (2019) 112004.
* Yamada *et al.*, ISS04 confinement scaling, *Nucl. Fusion* **45** (2005) 1684.
* Sudo *et al.*, stellarator density limit, *Nucl. Fusion* **30** (1990) 11.
* Huba, *NRL Plasma Formulary* (collisional parameters).

## License

Released under the **GNU General Public License v3.0** — see the
[`LICENSE`](LICENSE) file for the full text.
