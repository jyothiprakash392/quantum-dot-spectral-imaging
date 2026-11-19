# Accuracy summary — Physics-Constrained Quantum-Dot Digital Twin 1.5.1

## Release checks

- MATLAB/Simulink regression tests: **20/20 passed**
- Published-reference workflow tests: **7/7 passed**
- Material IDs 2–4 calibration/ML tests: **22/22 passed**
- Dedicated hybrid model-selection/scope tests: **10/10 passed**
- Ensemble/instrument/detector observation tests: **14/14 passed**
- Total across five delivered suites: **73/73 passed**
- Tested with MATLAB R2026a Update 4
- Exact tested-file hashes: `VALIDATION_MANIFEST.json`

The numerical tests cover the finite-well solver (including shallow states),
probability conservation, exact Markov event integration, zero and fractional
pulses, delivered photon counts, MATLAB/Simulink execution, spectrum Jacobians,
pump-edge smoothness, Stokes-shift override, input rejection, and calibration
scope flags.

The 22-test v1.4 suite additionally covers equal-volume geometry conversion,
published ID 2–4 optical baselines, observable-specific scope flags, ID-4
optical and grouped kinetic evaluation, an ID-3 whole-series Auger test,
10,001-point kinetic physicality/rate closure, protocol adaptation,
photon-count/lambda1 compatibility, and Simulink/direct-engine agreement. Its frozen report is
`MULTIMATERIAL_CALIBRATION_RESULTS.txt`.

## Physics + small-data learning decision

Gaussian processes, boosted/tree ensembles, and a compact neural regressor
were benchmarked. Deep learning was not selected: the data are too small and
the constrained regressions won leak-resistant grouped validation. The
deployed ID-4 model predicts measured lifetime and PLQY, then derives rates to
enforce positivity and exact rate closure. The ID-3 learner predicts only
biexciton Auger lifetime inside its measured convex geometry envelope.

`predictQDHybrid` optionally adapts ID-4 absorption to the Mondal-2019
protocol. Four development sizes selected a constant −0.066715909 eV residual
(LOOCV RMSE 0.0118791 eV). On three untouched sizes, RMSE falls from 0.0725149
eV to **0.0370127 eV** with −0.00421591 eV bias. This is protocol-specific,
not universal and not a formal confidence interval. It never alters PL or
`lambda2`.

## Ensemble and detector observation accuracy

Version 1.5 adds `simulateQDEnsemble`. Its deterministic lognormal quadrature
reproduces an arithmetic 3 nm mean and 10% radius CV to floating-point
precision in the supplied fixture. The independently derived analytic
absorption-area result is also reproduced: because the current 350 nm line
area scales as `R^3`, a 10%-CV lognormal distribution increases that area by
`(1 + CV^2)^3 = 1.030301`; the test obtains the corresponding
`1.53027516627e-18 m^2` result.

The suite also verifies exact collapse to `simulateQD` at zero dispersion,
measured discrete fraction arithmetic, deterministic/RNG-independent results,
energy-to-wavelength Jacobian conservation, Gaussian instrument area
conservation, band-edge/trap count separation and exact detector efficiency,
dark-count, excess-noise and read-noise formulas.

These are mathematical validation results, not new experimental RMSE values.
The quality of an ensemble prediction still depends on the supplied radius
histogram, material calibration and instrument parameters. Absolute count
predictions additionally require an explicit dot count and the optically thin
approximation. Pump depletion, reabsorption and inter-dot energy transfer are
not modeled.

## CdSe absorption accuracy

Two CdSe choices are intentionally separate:

| Preset | Intended use | Energy comparison over 3–8 nm diameter |
|---|---|---|
| Material 1 — CdSe/ZnS mechanistic | Physics exploration with tunable barriers, temperature, field, strain, traps and shell-dependent kinetics | RMSE 43.84 meV vs Yu, 27.79 meV vs Jasieniak, 43.90 meV vs Donega/Koole, and 37.80 meV vs their mean |
| Material 5 — scoped CdSe empirical | Highest delivered bare-CdSe absorption consistency at 300 K, zero field/strain, no shell and environment dielectric 2.25 | Calibration RMSE 0.371 meV vs the three-curve mean; 5.57/10.85/9.97 meV vs the individual curves; wavelength RMSE 0.115 nm vs the mean |

Material 5 was fitted to those same three sizing equations. Its very small
mean residual is therefore **calibration consistency, not independent held-out
validation**. The three sources themselves differ by as much as 41.5 meV over
the evaluated range. Source disagreement and diameter uncertainty are retained
separately in the prediction report rather than presented as a formal 95%
confidence interval.

Use the scoped preset as follows:

```matlab
inputs = qdAccurateCdSeInputs(3.0); % radius 3 nm = diameter 6 nm
inputs.incidentPhotonCount = 1e5;
inputs.inputWavelength_nm = 405;    % lambda1
inputs.beamArea_um2 = 100;
inputs.pumpDuration_ns = 10;
inputs.stokesShiftOverride_eV = 0.030; % replace with paired sample data

result = simulateQD(inputs,'Duration_ns',50);
result.lambda2_nm
result.deliveredIncidentPhotonCount
result.emittedPhotonCountExpectedPerDot
prediction = predictQDWithError(inputs,400);
```

## Material IDs 2–4: calibrated scope and measured errors

All three calibrated paths report `modelTier = 2`, meaning a published
empirical optical baseline plus mechanistic perturbation deltas. This does not
mean atomistic accuracy. `qdCalibratedMaterialInputs` converts the source size
to the engine's scalar radius: an approximately regular tetrahedral InP edge
and a CsPbBr3 cube edge become equal-volume-sphere radii, while PbS diameter
uses `r = d/2`.

| ID | Supported baseline and envelope | Accuracy evidence | Outside/unsupported observables |
|---:|---|---|---|
| 2 — InP | Almeida 2023 volume law for approximately tetrahedral bare cores, `V = 1–10 nm^3`, 293–303 K, shell `<=0.05 nm` as a numerical bare-core tolerance | Exact source-equation regression; one deliberately out-of-scope InP/ZnSe sample has signed errors −206.795 meV absorption and −96.795 meV PL | PL/Stokes, kinetics and every resolved ZnSe shell |
| 3 — PbS | Moreels 2009 absorption law near ambient; separate 2026 Auger learner at core `5.32–7.63 nm`, shell `0–0.84 nm`, inside the measured convex hull | Exact optical equation regression; Auger whole-series CV RMSE **8.9463 ps** versus 100.688 ps for the old generic law; thick-shell PL RMSE **134.996 meV** | PL/Stokes, total/radiative/nonradiative lifetime and shell-induced spectral shifts; Auger evidence is provisional |
| 4 — CsPbBr3 | Brennan 2017 absorption/PL/Stokes cube table, edge `3–12.8 nm`; measured `+0.224 meV/K` slope over 250–300 K | External cross-source/protocol absorption RMSE **69.587 meV**, bias **+64.909 meV**; cross-protocol PL-anchor RMSE **43.6757 meV** | Optics outside the size/temperature/reference-boundary envelope; kinetics outside the separate 293–303 K PL-energy envelope |

ID 4 kinetics use 25 of 34 Abbas et al. rows (16 distinct energy groups) for
development. Ridge strength was selected with leave-one-energy-group-out
validation before evaluation on nine frozen rows in five energy groups.
Frozen evaluation RMSE values are:

| Quantity | RMSE |
|---|---:|
| radiative rate | 0.0145593 ns^-1 |
| nonradiative rate | 0.0103094 ns^-1 |
| total lifetime | 0.0896423 ns |
| radiative lifetime | 0.180421 ns |
| PLQY | 3.48661 percentage points |

These are source/protocol-specific errors conditional on PL energy, not
confidence limits for arbitrary syntheses or end-to-end size-to-rate errors.
IDs 2 and 3 have no independent **in-scope** optical energy RMSE; their
out-of-scope limitation scores must not be treated as calibration accuracy,
and assigning the ID-4 cross-source error to them would be invalid.

## What lambda2 means

`lambda2_nm` is calculated from the dot PL transition. It is not a direct
conversion of input `lambda1`. The CdSe, InP and PbS sizing equations measure
the first absorption maximum, not PL. A real sample's PL wavelength therefore
requires its Stokes shift; for IDs 2 and 3, provide a measured value through
`stokesShiftOverride_eV`. ID 4 instead uses source-tabulated PL/Stokes data and
has the cross-protocol PL-anchor error above. The package does not infer a
universal lambda2 error outside these observable-specific cases.

## Photon accounting accuracy

For each constant-input interval, probabilities and absorbed/emitted/trap-
emission event counts come from one augmented matrix exponential. MATLAB uses
the exact requested stop time and pulse edge. Simulink applies fractional duty
correction at non-grid pulse edges; tests conserve all requested photons for
5 ps, 15 ps and 1.005 ns pulses and correctly report half delivery when a run
stops halfway through a pulse.

Counts other than delivered incident photons are expected events **per dot**
and may be fractional. Trap-emission photons are a subset of total emitted
photons and must not be added to the total again. Detector counts additionally
need collection efficiency, optical losses and detector quantum efficiency.

## Main limitations

- Not universal across all quantum dots. IDs 2–4 are calibrated only for the
  material, geometry, size, temperature and observable envelopes above.
- ID 2 PL/kinetics and every resolved ZnSe shell are unvalidated. For ID 3,
  only the separately gated biexciton Auger rate is learned; PL, total
  lifetime and radiative/nonradiative rates remain unvalidated, and shell
  thickness does not calibrate a spectral shift.
- ID 4 has an external cross-source optical check and an internal grouped
  kinetic holdout, but their errors are tied to the cited sources and protocols; they
  do not cover phase changes, arbitrary
  ligands, shells, fields, strains or temperature extrapolation.
- Spherical, single-band effective-mass approximation; no full multiband,
  atomistic, fine-structure or nonspherical solver.
- Shell thickness affects tunneling, trapping and Auger kinetics, but the
  electronic eigenproblem is still a two-region effective barrier—not a full
  core/shell/environment Hamiltonian. Shell-induced spectral shifts are not
  predicted from thickness alone.
- Coulomb and dielectric polarization remain effective approximations.
- Material-5 calibration covers absorption peak energy only. It does not
  validate PL yield, trap/Auger rates, tunneling, photon statistics or counts.
- Bright/dark excitons, blinking, spectral diffusion, coherent ultrafast
  dynamics and stochastic arrival histories are omitted. Static physical
  radius distributions and analytic detector noise are supported, but coupled
  optical-depth, reabsorption and inter-dot transfer physics are not.
- `modelConfidence` is a heuristic validity score, not a probability of being
  correct.

For fabrication-grade predictions, fit radius distribution, band offsets,
environment/shell parameters, Stokes shift, quantum yield and time-resolved
rates to the actual batch, then validate against held-out samples.

## Primary comparison sources

- Yu et al. (2003): https://doi.org/10.1021/cm034081k
- Jasieniak et al. (2009): https://doi.org/10.1021/jp906827m
- de Mello Donega and Koole (2009): https://doi.org/10.1021/jp811329r
- Almeida et al. InP volume law (2023): https://doi.org/10.1021/acs.nanolett.3c02630
- Brodu et al. out-of-scope InP/ZnSe check (2018): https://doi.org/10.1021/acsphotonics.8b00615
- Moreels et al. PbS sizing law (2009): https://doi.org/10.1021/nn900863a
- Justo et al. PbS/CdS cation exchange (2013): https://doi.org/10.1021/jp406774p
- Stylianou et al. PbS/CdS Auger series (2026): https://doi.org/10.1021/acs.nanolett.6c00158
- Krishnamurthy et al. thick-shell PbS/CdS check (2021): https://doi.org/10.1021/acsnano.0c05907
- Brennan et al. CsPbBr3 optical table (2017): https://doi.org/10.1021/jacs.7b05683
- Mondal et al. external CsPbBr3 optical comparison (2019): https://doi.org/10.1039/C9SC01339C
- Castellanos-Aguila et al. CsPbBr3 temperature slope: https://doi.org/10.1021/acs.jpcc.4c06265
- Abbas et al. CsPbBr3 kinetics (2025): https://doi.org/10.1038/s41467-025-60848-5
