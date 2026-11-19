# Model card: Physics-Constrained Quantum-Dot Digital Twin 1.5.1

## Intended use

Interactive design exploration, simulation, sensitivity studies, teaching,
experimental planning, and a numerical tool callable by a higher-level agent.
The default calibration represents a nominal spherical CdSe core with a ZnS
barrier/shell. It is not a certification model for a fabricated device.

## Fidelity tier

The tier is a model-path identifier, not a universal ranking of accuracy:

- `modelTier = 1`: finite-barrier analytic effective mass plus the Markov
  population model (materials 1 and 5).
- `modelTier = 2`: a published empirical optical baseline plus mechanistic
  perturbation deltas and the same Markov dynamics (materials 2–4).

Tier 2 is more source-specific inside its stated envelope, but it is not a
radial finite-volume, multiband k·p, tight-binding or atomistic solver. The tier
is reported with every run so downstream agents can distinguish the model
paths. `modelTier` does not encode whether the optional ID-4 optical protocol
adapter is active; inspect `mlOpticalAdaptationActive` and `selectedModel` in
the `predictQDHybrid` result.

## Equations and state

The electron/hole ground states solve the finite spherical well with
BenDaniel–Duke mass-discontinuous matching. Energy terms are assembled as

```text
Eabs = Eg(T) + Ee + Eh - Jeh + Epolarization + Estrain + EStark
EPL  = Eabs - EStokes
```

For IDs 2–4, the zero-perturbation `Eabs` is replaced by the relevant published
baseline. The difference between the current mechanistic calculation and its
reference-boundary value is then added as an input-dependent delta. ID 4 also
uses source-tabulated Stokes/PL values and its measured temperature slope. This
hybrid construction preserves field, strain, dielectric and barrier inputs but
does not experimentally validate those deltas outside the source envelope.

Carrier kinetics use ground, exciton, biexciton and trap probabilities. Pump,
radiative/nonradiative loss, surface capture, detrapping and Auger transitions
form a continuous-time generator. The implementation uses the exact matrix
exponential over each constant 10 ps interval (and exact fractional intervals
in MATLAB). An augmented Markov reward matrix integrates absorption, total
emission, and the trap-emission subset without endpoint quadrature bias.

## Physics-constrained learning

The candidate benchmark includes Gaussian processes, boosted/tree ensembles,
and a compact neural regressor. A large or deep neural model was not deployed:
there are only seven protocol-specific optical points and 34 kinetic rows with
21 distinct PL energies. Lower-variance constrained models performed more
consistently under grouped validation.

For ID 4, cubic ridge models predict the directly measured total lifetime
`tau(EPL)` and PLQY `Q(EPL)`. The engine derives `kr = Q/tau` and
`knr = (1-Q)/tau`, enforcing nonnegative rates, `0 <= Q <= 1`, and exact rate
closure. The 25 development rows contain 16 distinct energy groups; ridge
`lambda = 0.1` was selected with leave-one-energy-group-out validation. Nine
rows in five predeclared groups form the frozen evaluation. These metrics are
conditional on PL energy and do not include size-to-PL error.

For ID 3, a four-coefficient bilinear model predicts biexciton Auger lifetime
from outer diameter and shell thickness. It is activated only inside the
convex hull of 13 measurements from three cation-exchange series. Whole-series
cross-validation prevents rows from one synthesis series appearing in both
training and validation. All other ID-3 kinetic channels remain generic.

`predictQDHybrid` is a separate MATLAB-only ID-4 absorption protocol adapter.
The `mondal2019` correction was selected on four sizes and evaluated on three
untouched sizes; it never changes PL or `lambda2`. The frozen deployed
coefficients need no ML runtime. Statistics and Machine Learning Toolbox is
needed only to regenerate `benchmarkQDHybridModels`.

## Photon-count interface (v1.2)

The MATLAB-facing pulse interface adds `incidentPhotonCount`,
`inputWavelength_nm`, `beamArea_um2` and `pumpDuration_ns`. A value of `0` for
`incidentPhotonCount` selects legacy mode, in which `pumpIntensity_Wcm2` and
`pumpPhotonEnergy_eV` are used directly. For a positive count, the interface
maps the incident wavelength \(\lambda_1\) and pulse geometry onto those same
legacy variables:

```text
pumpPhotonEnergy_eV = 1239.841984 / inputWavelength_nm
photonEnergy_J = pumpPhotonEnergy_eV * elementaryCharge_C
pumpIntensity_Wcm2 = incidentPhotonCount * photonEnergy_J ...
                     / ((beamArea_um2 * 1e-8) * (pumpDuration_ns * 1e-9))
```

This is an interface transformation, not an additional Hamiltonian term. The
second wavelength, \(\lambda_2\), remains `emissionWavelength_nm` (fixed
Simulink output 10), obtained from `plEnergy_eV`. It is mostly a property of the
dot and its environment rather than a direct conversion of \(\lambda_1\).

Expected absorbed, emitted and trap-emission photon counts are obtained from
the exact interval reward integral. The values are per-dot expectations and
may therefore be fractional. They are not discrete event samples and should
not be interpreted as measured detector counts.

The pulse model assumes a spatially uniform beam and constant intensity for a
square `pumpDuration_ns` window. It does not resolve Gaussian beam profiles,
finite rise/fall time or pulse-to-pulse noise.
The core model's population saturation and protective generation/rate caps
remain active, so extreme fluence is a bounded qualitative extrapolation.

## Ensemble and experimental-observation layer (v1.5)

`simulateQDEnsemble` is a MATLAB-only wrapper and does not alter the fixed
Simulink vector. It represents a number-weighted physical distribution of
independent dot radii while holding the other public inputs fixed. The
distribution may be a deterministic lognormal quadrature or explicit measured
radius nodes with number fractions, such as a TEM histogram.

Each radius is propagated through `simulateQD`. Member spectra are regenerated
on one common energy grid and summed in energy space. Only after mixing are the
wavelength densities calculated with the exact Jacobian. The API reports the
energy centroid, wavelength centroid, spectral peak and numerical FWHM
separately; it does not assume that `mean(lambda) = hc/mean(E)` or that a
multimodal mixture is Gaussian.

The band-edge episode spectrum is weighted by each member's integrated emitted
photon count. Trap-emission photons are subtracted from that line and reported
as an unresolved spectral count because the core model has no calibrated trap
emission center or width. If no dynamic photons exist, the documented fallback
order is final PL rate, generation times instantaneous yield, then number
fraction.

The detector mapping accepts a stated dot count, collection efficiency,
optical transmission, detector quantum efficiency, dark-count rate, excess
noise factor and per-pixel read noise. After quantum efficiency, signal values
are expected primary photoelectrons, not photons. It reports expectations and
analytic variance; no random photon-event record is generated. The default ensemble run
has zero duration and is intended for fast static spectra. A positive duration
is required for episode photon/detector counts.

This layer assumes independent, noninteracting dots that all see the same
uniform pump. Per-dot absorbed/emitted counts may be multiplied by
`NumberOfDots` only in an optically thin sample. A photon-budget diagnostic
warns when predicted aggregate absorption exceeds five percent of delivered
photons. Without a finite incident-photon count the depletion assessment is
explicitly unknown, not valid. The diagnostic is not an optical-depth estimate.
Beer–Lambert pump depletion, emission reabsorption, Förster transfer,
concentration-dependent quenching, scattering, detector dead time, blinking,
antibunching and arrival-time statistics remain outside scope.

## Validity bitmask

| Bit value | Meaning |
|---:|---|
| 1 | radius invalid/clipped |
| 2 | temperature invalid/clipped |
| 4 | electric field outside weak-field envelope |
| 8 | strain outside ±3% calibration envelope |
| 16 | electron state unbound |
| 32 | hole state unbound |
| 64 | atomistic-radius warning |
| 128 | outside strong-confinement envelope |
| 256 | material ID invalid, noninteger, or replaced by material 1 |
| 512 | below-gap pump uses tail model |
| 1024 | population state reset/renormalized |
| 2048 | barrier override clipped |
| 4096 | target-radius sensitivity too small |
| 8192 | pump input replaced |
| 16384 | shell input replaced |
| 32768 | trap-density input replaced |
| 65536 | outside permittivity replaced |
| 131072 | generation rate reached its protective cap |
| 262144 | populated dynamics are fast relative to the reporting step |
| 524288 | empirical CdSe preset used outside its calibration envelope |
| 1048576 | Stokes-shift override invalid/clipped |
| 2097152 | empirical optical baseline outside its published size/temperature/perturbation envelope |
| 4194304 | PL/Stokes wavelength not calibrated for this material and scenario |
| 8388608 | core/shell geometry outside the source-supported transfer range |
| 16777216 | one or more kinetic rates generic or outside their grouped-validation envelope |

Use `qdDecodeFlags(result.validityFlags)` for readable messages.

## Largest uncertainties

- electron/hole band offsets and barrier masses
- dielectric screening at the core/shell/environment interfaces
- scalar hole mass versus wurtzite valence-band mixing
- Stokes shift, trap spectrum and capture cross section
- radiative oscillator strength and local-field factor
- shell-dependent Auger suppression
- real shape, alloying, ligands and size distribution
- beam profile, pulse shape and detection efficiencies in photon-count mode

Consequently, the reported model confidence is a validity prior, not a formal
credible interval. Fit against traceable experimental data before making a
quantitative fabrication decision.

## Scoped empirical material calibrations

`qdCalibratedMaterialInputs(materialID,sourceSize_nm)` creates reference inputs
without changing the fixed 14-input engine or 40-output Simulink interface. It
also prevents silent confusion between the source geometries:

- ID 2 interprets `sourceSize_nm` as the edge `a` of an approximately regular
  tetrahedral InP core. With `V = a^3/(6*sqrt(2))`, the engine radius is the
  equal-volume-sphere value `(3*V/(4*pi))^(1/3)`.
- ID 3 interprets it as spherical PbS core diameter `d`, excluding any CdS
  shell; the engine radius is `d/2`.
- ID 4 interprets it as CsPbBr3 cube edge `L`; the engine uses equal-volume
  radius `(3/(4*pi))^(1/3)*L`.

### ID 2 — InP

The absorption baseline is the Almeida et al. (2023) volume law
`Eabs = 1.33 + 1.219/V^0.251` eV for approximately tetrahedral bare InP cores.
Its implemented scope is `V = 1–10 nm^3`, 293–303 K, zero field/strain,
reference dielectric/barriers and shell `<=0.05 nm` as a numerical bare-core
tolerance. The reference equation is exactly
reproduced by regression tests; this is implementation consistency, not an
independent accuracy estimate. PL/Stokes shift and kinetics are unvalidated.
Any resolved ZnSe shell above that tolerance is outside scope and raises the
core/shell flag. Source:
[Almeida et al., Nano Letters (2023)](https://doi.org/10.1021/acs.nanolett.3c02630).
As an explicit limitation check, one geometry-mismatched InP/ZnSe sample has
signed errors of -206.795 meV for absorption and -96.795 meV for PL; the
scenario is flagged out of scope and is not an in-scope calibration metric.
[Holdout source](https://doi.org/10.1021/acsphotonics.8b00615).

### ID 3 — PbS absorption and provisional PbS/CdS Auger learner

The absorption baseline is the Moreels et al. (2009) first-exciton relation
`Eabs = 0.410 + 1/(0.0252*d^2 + 0.283*d)` eV for PbS core diameter `d` in nm.
The bare-core scope is `d = 3.9–13.3 nm`, 293–303 K, zero field/strain and
reference dielectric/barriers. A conservative validity transfer covers the
Justo et al. cation-exchanged geometry only for PbS core diameter 3.9–5.8 nm
and CdS shell 0.5–1.25 nm. It does not represent a calibrated shell-induced
spectral shift. The source equation is exactly reproduced by regression tests.
PL/Stokes shift, radiative/nonradiative rates and total lifetime remain
unvalidated.

A separate 2026 calibration predicts biexciton Auger lifetime for
cation-exchanged dots with PbS core diameter 5.32–7.63 nm, CdS shell 0–0.84
nm, and `(outer diameter, shell)` inside the measured convex hull. Holding out
each complete synthesis series gives **8.9463 ps RMSE**, 6.5183 ps MAE and
Q² = 0.9714, versus 100.688 ps RMSE for the old generic Auger law on those
rows. This uses only three reported series and rounded lifetime targets, so
it is provisional and does not validate other kinetic channels. Sources:
[Moreels et al., ACS Nano (2009)](https://doi.org/10.1021/nn900863a),
[Justo et al., J. Phys. Chem. C (2013)](https://doi.org/10.1021/jp406774p), and
[Stylianou et al., Nano Letters (2026)](https://doi.org/10.1021/acs.nanolett.6c00158).
An independent thick-shell series gives 134.996 meV PL RMSE and 0.17455
electron-hole-overlap RMSE, quantifying the omitted quasi-type-II physics.
[Thick-shell source](https://doi.org/10.1021/acsnano.0c05907).

### ID 4 — CsPbBr3

The optical baseline linearly interpolates the Brennan et al. (2017) cube
absorption/PL/Stokes table over edge lengths 3–12.8 nm and applies the measured
near-ambient slope `+2.24e-4 eV/K` over 250–300 K. The optical scope further
requires zero field/strain, reference dielectric/barriers and no shell.
[Primary optical table](https://doi.org/10.1021/jacs.7b05683).

An external cross-source/protocol comparison to the Chemical Science absorption
series gives **0.069587 eV RMSE** and **+0.064909 eV bias**. Cross-protocol PL
anchors give **0.0436757 eV RMSE**.
[External optical source](https://doi.org/10.1039/C9SC01339C).

The 293–303 K constrained rate learner uses 25 of 34 Abbas et al. rows for
development and nine predeclared energy-grouped rows for frozen evaluation.
Its kinetic envelope additionally requires a PL energy of
2.445466802–2.654928626 eV and zero added surface-trap density. Frozen RMSE is
**0.0145593 ns^-1** for radiative rate, **0.0103094 ns^-1** for nonradiative
rate, **0.0896423 ns** for total lifetime, **0.180421 ns** for radiative
lifetime and **3.48661 percentage points** for PLQY.
[Primary kinetic source](https://doi.org/10.1038/s41467-025-60848-5).

The optional Mondal-2019 absorption residual has 0.0118791 eV development
LOOCV RMSE. On three untouched sizes it reduces RMSE from 0.0725149 eV to
**0.0370127 eV**. It is synthesis-protocol-specific and never shifts the
source PL curve.

These optical and kinetic errors are dataset/protocol-specific validation
statistics, not universal confidence intervals. Outside the stated envelope,
the engine still returns a finite extrapolation and sets observable-specific
flags; that output should be treated as qualitative.

## Published empirical comparison

The delivered comparison evaluates the first-exciton absorption output against
the Yu (2003), Jasieniak (2009), and de Mello Donega/Koole (2009) bare-core
CdSe relationships over 3–8 nm diameter. Energy RMSE is 43.84, 27.79, and
43.90 meV, respectively; RMSE versus their mean is 37.80 meV. The model is most
credible around 4–6 nm and is systematically too blue at 3 nm.

The 400-sample assumption-driven input band has a mean 37.59 meV half-width
and 83.3% coverage of the Yu checkpoints. It is not a calibrated confidence
interval. Published-curve spread averages 22.15 meV and is retained separately.

The intrinsic radiative-lifetime comparison has 9.548 ns RMSE and -27.97% mean
relative error. Energy prediction is therefore better supported than the
oscillator-strength/lifetime submodel. See `REAL_WORLD_VALIDATION.md` for the
complete observable mapping and error decomposition.

For this diagnostic, `shellThickness_nm=0` does not change the electronic
boundary masses and offsets; the nominal ZnS-like finite barriers act as an
effective ligand/interface boundary. This is not a true microscopic bare-core
boundary condition.

Material 5 is a separate, explicitly empirical CdSe-core preset. Its effective
single-band parameters were fitted to the mean of the three published sizing
equations on a dense 3–8 nm diameter grid at 300 K. The resulting calibration
RMSE is 0.371 meV versus their mean (0.115 nm wavelength), and 5.57, 10.85,
and 9.97 meV versus the individual Yu, Jasieniak, and Donega/Koole equations.
Because the same equations were used for fitting, these are training residuals,
not independent validation. The empirical radiative relation is likewise a
calibration identity inside scope. PL wavelength remains unvalidated unless a
sample-specific Stokes shift is supplied.

## Omitted physics

Anisotropic multiband valence structure, crystal-field/fine-structure splitting,
bright/dark exciton kinetics, atomistic interfaces, ligand orbitals, coherent
femtosecond motion, non-Markovian phonons, blinking power laws, stochastic
photon emission/detection, charge-state master equations, cotunneling and full
Poisson–Schrödinger self-consistency.

## Frozen validation point

For the analytic infinite-barrier CdSe check at R=3 nm and T=300 K:

| Quantity | Value |
|---|---:|
| bulk gap | 1.7567924528301888 eV |
| electron confinement | 0.3213933009879792 eV |
| hole confinement | 0.09284695361874955 eV |
| Coulomb correction | 0.09023777833146754 eV |
| transition | 2.08079492910545 eV |
| wavelength | 595.8501566 nm |

The delivered finite-barrier default gives 1.942753759 eV PL / 638.187922 nm.
All twenty delivered core/Simulink tests and all seven empirical workflow
tests passed on MATLAB 26.1.0.3312084 (R2026a)
Update 4 and were rerun on 2026-08-27.

The v1.4 material-ID calibration/ML suite additionally passed **22/22 tests**
on the same MATLAB release on 2026-08-27. It covers the unchanged 14-input/
40-output contract, ID 2–4 source equations and size bridges, observable-level
scope flags, ID-3 whole-series Auger validation, ID-4 protocol/kinetic grouped
evaluation, physicality/rate closure, photon/lambda compatibility, and
Simulink/direct-engine agreement. See
`MULTIMATERIAL_CALIBRATION_RESULTS.txt` for the frozen result.
The dedicated physics-plus-ML suite additionally passed **10/10 tests**; see
`QD_HYBRID_TEST_RESULTS.txt`.
The v1.5.1 ensemble/observation suite passed **14/14 tests** for analytic radius
moments, the exact R-cubed absorption-area oracle, spectral conservation,
instrument and detector arithmetic, bounded-distribution conditioning,
zero-weight invariance, scope aggregation and limiting behavior. The five
delivered suites therefore contain **73/73 passing checks**. See
`QD_ENSEMBLE_TEST_RESULTS.txt`.
