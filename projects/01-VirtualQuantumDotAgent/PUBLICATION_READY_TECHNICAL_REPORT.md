# A Physics-Constrained MATLAB/Simulink Digital Twin for Quantum-Dot Optical, Kinetic, and Ensemble-Measurement Simulation

## Abstract

This work presents a MATLAB/Simulink digital twin for input-dependent simulation
of colloidal quantum dots. The software combines a finite-barrier, single-band
effective-mass model; empirical optical anchors for selected materials; a
four-state continuous-time population model; finite-pulse photon accounting;
small-data, physics-constrained regressions; inverse radius design; and a
number-weighted ensemble/instrument/detector layer. Five material identifiers
are provided: a mechanistic CdSe/ZnS-like baseline, InP, PbS/CdS, CsPbBr3, and
an empirical bare-CdSe optical preset. The output wavelength is obtained from
the predicted photoluminescence transition and is not a direct conversion of
the pump wavelength. Version 1.5.1 passes 73 software and mathematical checks
across five suites in MATLAB R2026a Update 4. These checks establish numerical
consistency, limiting behavior, conservation, scope gating, and agreement
between the MATLAB and Simulink paths; they do not establish universal
experimental accuracy. The strongest external optical evidence is an
unadapted cross-source/protocol CsPbBr3 comparison with 69.587 meV root-mean-
square error and +64.909 meV bias. Internal frozen evaluations give 37.013 meV
RMSE for a protocol-specific CsPbBr3 absorption correction and 0.180421 ns RMSE
for CsPbBr3 radiative lifetime conditional on measured PL energy. A provisional
PbS/CdS Auger learner gives 8.9463 ps whole-series cross-validation RMSE on 13
rounded rows from three reported synthesis series. The model is intended for
research exploration, experimental planning, and batch-specific calibration,
not certification or unrestricted transfer across quantum-dot systems.

**Keywords:** quantum dots; MATLAB; Simulink; digital twin; effective-mass
model; photoluminescence; ensemble broadening; photon accounting; small-data
machine learning

## 1. Scope and contribution

The software exposes a fixed 14-input/40-output Simulink interface and matching
MATLAB functions. Inputs include core radius, temperature, electric field,
hydrostatic strain, pump intensity and energy, shell thickness, surface trap
density, dielectric environment, finite barriers, target emission energy,
material identifier, and an optional Stokes-shift override. A MATLAB adapter
also accepts incident photon number, pump wavelength, beam area, and pulse
duration. Outputs include absorption and PL transition energies, emission
wavelength, populations, rates, lifetime, yield, spectra, photon expectations,
inverse-design guidance, validity flags, and a heuristic model-validity score.

The implementation is a physics-constrained digital twin with an inverse-design
API. It is not, by itself, an autonomous artificial-intelligence agent. A
higher-level agent may call the numerical API, but no language model, planner,
or autonomous experimental controller is embedded in the Simulink model.

## 2. Methods

### 2.1 Static electronic and optical model

For the mechanistic path, electron and hole ground states are obtained from a
finite spherical well with mass-discontinuous BenDaniel-Duke matching. The
absorption transition is assembled as

```text
Eabs = Eg(T) + Ee + Eh - Jeh + Epol + Estrain + EStark,
EPL  = Eabs - EStokes,
lambda2 = hc/EPL.
```

The bulk-gap temperature dependence uses the empirical Varshni relation. The
Coulomb term is a screened effective interaction; dielectric polarization,
strain, and weak-field quadratic Stark terms are effective approximations. The
mechanistic basis follows the strong-confinement treatment introduced by
[Brus](https://doi.org/10.1063/1.447218), while the temperature expression is
associated with [Varshni](https://doi.org/10.1016/0031-8914(67)90062-6).

Material IDs 2–4 replace the zero-perturbation absorption baseline with a
published empirical relation or table and add the change predicted by the
mechanistic model away from a reference boundary. This retains input dependence
but does not experimentally validate field, strain, dielectric, or barrier
perturbations outside the cited source envelope.

### 2.2 Material-specific optical anchors

- **ID 1, mechanistic CdSe/ZnS-like baseline.** The 350 nm absorption cross
  section uses the radius-cubed relation reported by
  [Leatherdale et al.](https://doi.org/10.1021/jp025698c). Optical comparisons
  use the CdSe sizing relations of
  [Yu et al.](https://doi.org/10.1021/cm034081k),
  [Jasieniak et al.](https://doi.org/10.1021/jp906827m), and
  [de Mello Donega and Koole](https://doi.org/10.1021/jp811329r).
- **ID 2, InP.** The implemented baseline is the reported volume-dependent
  first-absorption relation for approximately tetrahedral bare InP cores from
  [Almeida et al.](https://doi.org/10.1021/acs.nanolett.3c02630).
- **ID 3, PbS/CdS.** Bare-core absorption uses the PbS first-exciton sizing
  relation of [Moreels et al.](https://doi.org/10.1021/nn900863a). The
  conservative core/shell geometry interpretation is informed by
  [Justo et al.](https://doi.org/10.1021/jp406774p).
- **ID 4, CsPbBr3.** Absorption, PL, and Stokes shift interpolate the cube-size
  table of [Brennan et al.](https://doi.org/10.1021/jacs.7b05683). The
  near-ambient temperature slope is restricted to the measurement range of
  [Castellanos-Aguila et al.](https://doi.org/10.1021/acs.jpcc.4c06265).
- **ID 5, empirical CdSe.** Effective parameters were fitted to the mean of the
  three CdSe sizing equations above. The fitted parameters are numerical
  surrogates, not new bulk-property measurements.

### 2.3 Pump, populations, and photon expectations

The finite-photon interface maps pump wavelength and photon count to the legacy
energy and uniform square-pulse intensity. Pump absorption uses a continuous
square-root continuum joined to an Urbach-like sub-gap tail and normalized to
the selected reference cross section. The four states are ground, exciton,
biexciton, and trapped excitation. Generation, radiative and nonradiative loss,
surface capture, thermal escape, trap decay, and Auger loss form a constant-rate
generator over each integration interval. Matrix exponentiation propagates
state probabilities. An augmented reward system integrates absorbed, total
emitted, and trap-emitted event expectations without endpoint quadrature.

The values are expected events per dot and may be fractional. They are not
single-photon trajectories and do not demonstrate antibunching.

### 2.4 Physics-constrained regression

The labeled datasets are too small to support a defensible high-capacity deep
network. For CsPbBr3, cubic ridge models predict total lifetime and PLQY as
functions of measured PL energy, after which nonnegative radiative and
nonradiative rates are derived by rate closure. Development used 25 rows in 16
energy groups; nine rows in five predeclared groups were retained for internal
frozen evaluation. The source data are from
[Abbas et al.](https://doi.org/10.1038/s41467-025-60848-5). These errors are
conditional on PL energy and are not end-to-end size-to-rate errors.

For PbS/CdS, a four-coefficient bilinear model predicts biexciton Auger lifetime
inside the convex hull of 13 rounded measurements from three reported series in
[Stylianou et al.](https://doi.org/10.1021/acs.nanolett.6c00158). Whole-series
cross-validation prevents rows from one reported series appearing in both
training and evaluation. All other ID-3 kinetic channels remain generic.

An optional MATLAB-only adapter corrects CsPbBr3 absorption for the 2019
protocol of [Mondal et al.](https://doi.org/10.1039/C9SC01339C). Four sizes were
used for model selection and three untouched sizes for internal evaluation.
The adapter does not change PL or `lambda2`.

### 2.5 Ensemble, instrument, and detector layer

`simulateQDEnsemble` propagates either a lognormal number distribution or
measured radius/number-fraction pairs through the single-dot model. Lognormal
integration uses deterministic quadrature and explicitly conditions on finite
radius bounds whenever excluded probability is non-negligible. Zero-weight
histogram bins are removed before simulation. Member spectra are mixed on one
energy grid, optionally convolved with a Gaussian energy-domain instrument
response, and transformed to wavelength density with the correct Jacobian.

Band-edge and unresolved trap emission are reported separately. Detector
throughput is the product of collection efficiency, optical transmission, and
quantum efficiency. After quantum efficiency, the signal is an expected primary
photoelectron count, not a photon count. Dark counts, an optional excess-noise
variance multiplier, and independent per-pixel read-noise variance are included.
Gain, saturation, dead time, arrival-time statistics, and detector spectral
response are not modeled.

## 3. Verification and validation design

Evidence is separated into four classes:

1. **Software/mathematical verification:** analytic values, conservation laws,
   deterministic repeatability, unit transformations, limiting cases, and
   MATLAB/Simulink agreement.
2. **Source-equation regression:** exact reproduction of a published equation
   or tabulated interpolation. This is implementation consistency, not
   independent prediction.
3. **Internal evaluation:** rows or groups withheld from model selection within
   the same published source.
4. **External cross-source/protocol comparison:** a published dataset not used
   to fit the tested baseline, while recognizing that batch and protocol
   differences remain confounded with model error.

The five suites contain 20 core/Simulink tests, seven CdSe workflow tests, 22
material-ID 2–4 tests, ten hybrid-model tests, and 14 ensemble/observation tests:
73/73 passed in the frozen v1.5.1 run. Passing tests do not imply 100%
experimental accuracy.

## 4. Quantitative results

| Path or observable | Evaluation | Result | Interpretation |
|---|---|---:|---|
| ID 1 CdSe absorption | comparison with three published equations, diameter 3–8 nm | 43.84, 27.79, and 43.90 meV RMSE; 37.80 meV versus their mean | equation-based external comparison, not raw held-out measurements |
| ID 5 CdSe absorption | fit to mean of the same three equations | 0.371 meV RMSE; 0.115 nm wavelength RMSE | calibration consistency only |
| ID 2 InP absorption | published volume equation | numerical regression tolerance <= 2e-12 eV | implementation consistency only |
| ID 3 PbS absorption | published sizing equation | numerical regression tolerance <= 2e-12 eV | implementation consistency only |
| ID 3 PbS/CdS Auger lifetime | whole-reported-series cross-validation | 8.9463 ps RMSE; 6.5183 ps MAE; Q² 0.9714 | provisional, 13 rounded rows, only inside geometry hull |
| ID 4 CsPbBr3 absorption | external Mondal-vs-Brennan cross-source/protocol comparison, seven points | 69.587 meV RMSE; +64.909 meV bias | external model-form scale; not a per-case confidence interval |
| ID 4 protocol adapter | three untouched Mondal sizes | 37.0127 meV RMSE; -4.21591 meV bias | internal, protocol-specific evaluation |
| ID 4 radiative lifetime | nine-row grouped frozen evaluation | 0.180421 ns RMSE | conditional on measured PL energy |
| ID 4 total lifetime | same internal evaluation | 0.0896423 ns RMSE | conditional on measured PL energy |
| ID 4 PLQY | same internal evaluation | 3.48661 percentage points RMSE | conditional on measured PL energy |

The ensemble demonstration at 2.8 nm mean radius predicts a 630.047 nm PL peak
and 30.007 nm FWHM for the monodisperse case. With 6% radius CV, the result is
630.277 nm and 33.094 nm under the stated model and instrument parameters. This
is a deterministic demonstration, not a comparison with a new experiment.

## 5. Applicability and limitations

The model does not apply unchanged to all quantum dots. Quantitative use is
restricted to each material, shape, size, temperature, boundary, shell, and
observable envelope reported by the software. Major omissions include
multiband valence structure, atomistic interfaces, nonspherical confinement,
bright/dark fine structure, phase changes, alloy disorder, ligand orbitals,
spectral diffusion, blinking, charge-state dynamics, non-Markovian phonons, and
full Poisson-Schrödinger self-consistency.

The ensemble layer assumes independent dots under a spatially uniform,
undepleted pump. It omits Beer-Lambert attenuation, reabsorption, Förster
transfer, concentration quenching, and multiple scattering. Its
`pumpDepletionIndicator` is a photon-budget diagnostic, not optical depth. If no
finite incident-photon budget is supplied, depletion status is unknown.

The scalar `modelConfidence` output is a heuristic validity score and is not a
probability, credible interval, or frequentist confidence level. Input-scenario
bands likewise reflect declared perturbation assumptions and must not be
reported as 95% confidence intervals.

## 6. Reproducibility and availability

The exact entry points, commands, expected test counts, MATLAB release, and
artifact policy are documented in `REPRODUCIBILITY.md`. SHA-256 hashes are stored
in `VALIDATION_MANIFEST.json`. The Simulink interface remains unchanged from the
tested model; v1.5.1 corrections are in the MATLAB ensemble/API and publication
metadata layer.

Before journal submission or public data deposition, the authors must supply
authorship, affiliations, corresponding-author information, funding,
conflict-of-interest and contribution statements, choose a software license,
and verify redistribution permission for transcribed source tables. No new
experimental data were collected for this work.

## 7. Conclusion

The delivered system is a reproducible, scope-aware MATLAB/Simulink quantum-dot
digital twin that combines mechanistic equations, empirical optical anchors,
small-data constrained regression, finite-photon dynamics, and ensemble
observation modeling. Its principal strength is transparent separation of
numerical verification, calibration consistency, internal evaluation, external
cross-source comparison, and out-of-scope warnings. Its results should support
experimental planning and batch-specific calibration, not universal claims
across quantum-dot materials.
