# Real-world CdSe prediction and error report

The virtual quantum-dot engine was compared with three independent published
relationships for organically capped, bare CdSe cores:

- Yu et al., *Chemistry of Materials* 15, 2854–2860 (2003),
  [DOI 10.1021/cm034081k](https://doi.org/10.1021/cm034081k)
- Jasieniak et al., *Journal of Physical Chemistry C* 113, 19468–19474 (2009),
  [DOI 10.1021/jp906827m](https://doi.org/10.1021/jp906827m)
- de Mello Donega and Koole, *Journal of Physical Chemistry C* 113,
  6511–6520 (2009),
  [DOI 10.1021/jp811329r](https://doi.org/10.1021/jp811329r)

These checkpoints are evaluations of empirical relationships, not a set of
independent raw observations. Their disagreement is retained as a separate
systematic error level.

## Fair observable and scenario

The sizing comparison uses `absorptionEnergy_eV` (output 8), not `plEnergy_eV`.
All three references use the first excitonic absorption maximum. PL includes a
sample-dependent Stokes shift and is not interchangeable with absorption.

The comparison profile is spherical CdSe at 300 K, zero field, zero strain,
environment relative permittivity 2.25, effective electron/hole barriers
0.90/0.60 eV, zero shell thickness, and no pump or surface traps.

Important limitation: setting `shellThickness_nm=0` removes shell-dependent
kinetic effects, but the present eigenproblem still uses the ZnS-like outside
masses and finite offsets as an effective boundary. This is a model-to-empirical
diagnostic, not a claim that the Yu, Jasieniak, or Donega ligand interfaces are
microscopically ZnS.

## Size-dependent absorption result

| Diameter | Model | Yu error | Jasieniak error | Donega/Koole error | Published-curve spread |
|---:|---:|---:|---:|---:|---:|
| 3 nm | 2.35809 eV | +95.5 meV | +60.7 meV | +79.4 meV | 34.8 meV |
| 4 nm | 2.15938 eV | +41.1 meV | +29.2 meV | +46.6 meV | 17.4 meV |
| 5 nm | 2.04205 eV | +5.7 meV | +5.7 meV | +14.9 meV | 9.3 meV |
| 6 nm | 1.96775 eV | -11.4 meV | -4.6 meV | -10.1 meV | 6.8 meV |
| 7 nm | 1.91800 eV | -17.2 meV | -6.1 meV | -29.2 meV | 23.1 meV |
| 8 nm | 1.88319 eV | -16.3 meV | -2.2 meV | -43.7 meV | 41.5 meV |

Across 3–8 nm, the model energy RMSE is:

- 43.84 meV versus Yu
- 27.79 meV versus Jasieniak
- 43.90 meV versus de Mello Donega/Koole
- 37.80 meV versus the mean of all three curves

The mean published-curve spread is 22.15 meV and its maximum is 41.52 meV.
Against Yu alone, the 4–8 nm RMSE is 21.98 meV and the wavelength RMSE is
6.41 nm. The infinite-barrier Brus approximation is much worse: 445.03 meV
energy RMSE and 83.12 nm wavelength RMSE over 3–8 nm. Finite barriers reduce
those RMSE values by 10.15 times and 7.71 times, respectively.

The strongest operating region for this tier-1 model is about 4–6 nm diameter:
the model errors are small-to-moderate and the three published curves agree
most closely. At 7–8 nm the model remains near Yu and Jasieniak, but published
calibrations diverge. At 3 nm the model is too blue by 76–111 meV and should be
treated as poor without nonparabolic, multiband, atomistic, and surface
corrections.

## Example prediction: 6 nm diameter

For `radius_nm=3.0`, 300 K, zero field and strain:

- model absorption: 1.967754 eV / 630.080 nm
- Yu: 1.979201 eV / 626.436 nm; error -11.447 meV / +3.644 nm
- Jasieniak: 1.972401 eV; error -4.648 meV
- Donega/Koole: 1.977890 eV; error -10.136 meV
- empirical-curve spread: 6.800 meV
- engineering envelope: 1.9440–1.9973 eV

The last interval spans the local input-sensitivity scenario, published source
range, reported diameter uncertainty, and one evaluation RMSE. It is an
engineering envelope, not a calibrated confidence interval.

## Intrinsic radiative lifetime check

de Mello Donega and Koole also report a room-temperature bright-exciton
radiative-rate relation versus PL energy. The correct model quantity is
`1/radiativeRate_Hz`; `effectiveLifetime_ns` includes nonradiative and trap
losses and must not be compared with that relation.

At the 6 nm point, the model intrinsic radiative lifetime is 22.439 ns versus
32.062 ns from the published relation, an error of -30.01%. Across 3–8 nm,
the lifetime RMSE is 9.548 ns and the mean relative error is -27.97%. Thus the
energy prediction is substantially better supported by these comparisons than
the oscillator-strength and lifetime submodel.

## Material 5: scoped calibration-consistency result

`qdAccurateCdSeInputs(radius_nm)` selects an optional effective bare-CdSe
optical preset fitted to the mean of all three equations over 3–8 nm diameter.
On the dense 0.25 nm calibration grid it gives:

- 0.371 meV absorption-energy RMSE versus the three-equation mean
- 0.115 nm wavelength RMSE versus that mean
- 5.57, 10.85, and 9.97 meV RMSE versus Yu, Jasieniak, and Donega/Koole
- all evaluated model energies inside the min/max published-source span

This is interpolation/training consistency, not independent validation. The
same preset directly uses the Donega/Koole radiative-rate equation inside its
declared envelope, so the zero lifetime residual there is also an identity
check. The sources measure absorption; they do not validate lambda2. A paired
experimental Stokes shift must be supplied through
`stokesShiftOverride_eV` for sample-specific PL prediction.

## Approximation and error levels

1. **Numerical error:** finite-well root and probability residuals are tiny
   compared with meV-scale physical errors; the 20/20 core tests still pass.
2. **Reported size uncertainty:** the Donega/Koole 2% diameter uncertainty
   maps locally to about 14.11 meV at 3 nm, falling to 2.68 meV at 8 nm.
3. **Input/parameter scenario:** a seeded 400-sample calculation used 3% radius
   sigma, 5 K temperature sigma, 0.12/0.10 eV barrier sigmas, and 0.25 outside
   permittivity sigma. Its mean nominal 95% half-width is 37.59 meV and it
   contains five of six Yu checkpoints (83.3% coverage).
4. **Reference-choice uncertainty:** the three published curves differ by
   6.8–41.5 meV in the delivered 3–8 nm checkpoints.
5. **Model-form error:** empirical RMSE is 27.8–43.9 meV over 3–8 nm depending
   on the chosen curve. The systematic small-dot residual shows that this is
   physical model discrepancy, not solver noise.

The scenario distributions are declared engineering assumptions, not fitted
experimental distributions. `modelConfidence=0.92` is therefore only a
dimensionless validity score; it is not a 92% probability, accuracy, or
coverage statement.

## Reproduce and request predictions

```matlab
report = validateAgainstRealCdSe(400);
testReport = runRealWorldValidationTests;

inputs = qdAccurateCdSeInputs(3.0);
prediction = predictQDWithError(inputs,400);
```

Generated artifacts:

- `REAL_WORLD_COMPARISON.csv`: predictions, all three references, residuals,
  uncertainty columns, and radiative-lifetime values
- `CdSe_REAL_REFERENCE_CURVES.csv`: frozen empirical reference values
- `REAL_WORLD_VALIDATION_RESULTS.txt`: frozen metric summary
- `RealWorldValidation.mat`: MATLAB report and scenario samples
- `RealWorldCdSeValidation.png`: comparison and error dashboard
- `CALIBRATED_CDSE_COMPARISON.csv` and `CalibratedCdSeValidation.png`:
  material-5 calibration consistency over a dense 3–8 nm grid
- `REAL_WORLD_VALIDATION_TESTS.txt`: 7/7 workflow regression result
