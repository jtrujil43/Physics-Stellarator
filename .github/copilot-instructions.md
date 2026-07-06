# Copilot instructions for Physics-Stellarator

Perl distribution (ExtUtils::MakeMaker, `Moo` classes) for computational plasma
dynamics with a Wendelstein 7‑X (W7‑X) stellarator model and optional 3‑D
plotting. Two modules ship: `Physics::CPD` (base engine) and
`Physics::CPD::Stellarator` (subclass).

## Build, test, lint

```sh
perl Makefile.PL && make && make test    # full build + test
prove -l t/                              # run the whole test suite (adds lib/ to @INC)
prove -lv t/01-cpd.t                     # run ONE test file, verbose
perl -Ilib t/05-fusion.t                 # alternative single-file run
```

- Tests use `Test::More` + `done_testing` (no plan count). There is no configured
  linter; keep files `use strict; use warnings;`‑clean.
- `t/04-plotting.t` and any PDL path `plan skip_all` / skip cleanly when PDL or
  gnuplot is absent — mirror that pattern for new plotting tests; never make the
  core suite hard‑depend on PDL.
- Numeric tests compare with a relative-tolerance helper (`approx` in
  `t/05-fusion.t`), not `is`/`==`. Reuse that style for floating‑point checks.

## Architecture

- `lib/Physics/CPD.pm` — pure‑Perl engine. State lives in a handful of `Moo`
  attributes (density, temperatures, `magnetic_field`, `ion_species`); every
  physical quantity is a **plain method that recomputes from current state**, so
  changing an attribute changes all derived results. No caching/memoization.
- `lib/Physics/CPD/Stellarator.pm` — `extends 'Physics::CPD'`. Adds device
  geometry, ISS04 confinement, Sudo limit, Bosch‑Hale D‑T fusion power, VMEC‑style
  Fourier boundary geometry, and plotting. Overrides an inherited default with
  `has '+magnetic_field' => (default => sub { 2.5 })`.
- **Plotting is an optional, lazily‑loaded layer.** PDL / `PDL::Graphics::Gnuplot`
  are `require`d inside `eval` at call time (`_new_gpwin`, `_pdl`) and `croak` if
  missing — they are `recommends`, not `PREREQ_PM`, in `Makefile.PL`. Core physics
  must keep working without them.
- Geometry (`boundary_point`, `surface_grid`, `magnetic_axis`, `modular_coils`,
  …) returns pure‑Perl arrayrefs and needs no PDL; only the `plot_*` methods do.
  The device is parameterised via `boundary_coeffs` (`[m, n, Rbc, Zbs]` rows) so
  other stellarators can be modelled by supplying new coefficients.

## Conventions

- **Units:** temperatures are in **eV**; everything else is SI unless the method
  name carries a unit suffix (`_MJ`, `_MW`, `_hz`, `_kelvin`, `_joules`). Follow
  this when adding methods. `as_hash` keys embed the unit (e.g. `debye_length_m`).
- Physical constants are `use constant` blocks (CODATA 2018 in `CPD.pm`); add new
  constants there rather than inlining magic numbers.
- `Moo` style: `has ... default => sub { ... }`; expensive/derived attributes use
  `lazy => 1` with a `_build_<name>` builder; private helpers are `_`‑prefixed.
  Validate inputs with `Carp::croak` (see `_lookup_species`).
- Each module ends with `__END__` + POD (`=head1 NAME/SYNOPSIS/...`). Update the
  POD and the top‑level `README.md` API tables when you add or rename a public
  method/attribute.
- Reporting methods (`report`, `device_report`, `power_report`) build a `@lines`
  array of `sprintf`‑formatted rows and return joined text; extend those rather
  than printing directly.
- Physics formulas cite their source in a comment (NRL Plasma Formulary,
  Bosch‑Hale, ISS04/Yamada, Sudo). Keep that citation habit for new physics.

## Release hygiene

- `$VERSION` is declared in **both** modules and must stay in sync;
  `Makefile.PL` reads `VERSION_FROM => lib/Physics/CPD/Stellarator.pm`.
- Record user‑visible changes in `Changes`, and add any new file to `MANIFEST`
  (the build ships only what MANIFEST lists).
