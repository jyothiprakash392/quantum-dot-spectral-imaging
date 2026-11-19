# Model card: voltage-selected QD UV-to-NIR downconverter

## Intended use

This is a system-architecture and computational-spectrometer model for:

1. passive one-photon conversion of 280-420 nm input photons into a selected
   visible/NIR emission band;
2. voltage-commanded selection among fixed-emission QD films;
3. split silicon-CCD/InGaAs detection; and
4. reconstruction of the incident UV spectrum from calibrated spatial filter
   measurements.

It is not a fabrication recipe, radiometric standard, optical-safety model, or
quantitative prediction of a specific manufactured film.

## Physical interpretation

The selector has six calibrated voltage windows. An ADC/window decoder drives
solid-state optical gates so that one film is illuminated without mechanical
motion. The default selector is hard nearest-channel selection:

```text
w_i(Vselect) = 1 for the closest calibrated channel voltage, otherwise 0.
```

An optional adjacent-channel blend represents a finite electronic transition
width between neighboring decoder windows. It is not a continuous QD bandgap
law.

In the generated Simulink models, an explicit decoder first quantizes the
command with a 12-bit, 3.3 V ADC, applies midpoint voltage windows and 20 mV
comparator hysteresis, and emits an exact one-hot six-gate vector. Its selected
calibrated voltage is then passed to the optical film-bank and reconstruction
blocks. Both the gate vector and six-field decoder telemetry are logged.

For film `i`, the illustrative absorptance is

```text
A_i(lambda) = Apeak_i exp[-4 ln(2) ((lambda-lambda_abs_i)/FWHM_abs_i)^2].
```

The emitted photons per incident photon in a filter channel are

```text
H_ij = T_filter_ij A_i(lambda_j) PLQY_i eta_extract_i.
```

The output spectral basis is Gaussian in photon energy rather than wavelength:

```text
P_i(E) proportional to exp[-4 ln(2) ((E-Eemit_i)/FWHM_E_i)^2].
```

Every sampled basis column is normalized to one photon. Modeling linewidth in
energy avoids unrealistically narrow long-wave NIR peaks.

The spatial detector measurement is

```text
y = diag(g_detector) H s + dark + noise,
```

where `s` is the 36-bin incident UV spectrum and `H` contains 12 spatial
filters sampled at five sequential filter-bias states. The nonnegative inverse
solves a weighted smooth Tikhonov problem with projected FISTA.

## Conservation checks

For every input bin and selector channel, the model checks:

```text
0 <= emitted photons / incident photon <= 1
0 <= emitted optical energy / incident optical energy <= 1.
```

All nominal output centers are longer than the complete input band. The passive
branch has no electrical optical-gain term. The ADC, decoder, and electronic
gates consume control power, but that power is not counted as emitted photon
energy.

The original attached SWIR-to-visible branch is different: it is an active
photodiode/QLED transducer, and its electrical supply explicitly provides the
anti-Stokes energy.

## Detector model

The common output grid is 420-1800 nm in 5 nm bins. A smooth dichroic crossover
near 960 nm sends the visible/NIR-I light to silicon and longer NIR light to
InGaAs. The delivered QE curves are illustrative and replaceable.

Spectral-output pixels are provided for inspection. Computational inversion
uses the 60 spatial channel measurements, because emission color alone cannot
recover a 36-bin UV spectrum.

## Voltage and QCSE limitation

Ordinary colloidal-QD Stark shifts are typically small relative to the
470-1410 nm span, often with field-dependent quenching and broadening. The model
therefore sets `QCSEPeakShift_nm = 0` by default. Wide tuning is implemented as
film selection. If measured QCSE calibration is added, keep it bounded within
the measured field range and do not conflate selector voltage with active-layer
electric field.

## Default calibration status

`UNMEASURED DEFAULT - replace film and detector curves`

Synthetic/default quantities include:

- film UV absorptance;
- PLQY and extraction efficiency;
- energy linewidths and emission centers;
- electro-absorption filter centers, widths, and bias shift;
- silicon/InGaAs QE and dichroic response;
- read noise, dark current, and full well; and
- end-to-end spatial response.

Measured film spectra can differ with packing, ligands, reabsorption,
temperature, irradiance, oxidation, and device geometry. Solution PLQY is not
interchangeable with film PLQY, extraction efficiency, or LED EQE.

## Known limitations

- The film model is steady-state; it does not include carrier lifetime or
  electronic switching transients.
- The standalone response function is stateless unless a previous channel is
  supplied; the Simulink decoder retains the previous channel and models
  comparator hysteresis.
- ADC integral/nonlinear error, switching delay, leakage, gate cross-talk, and
  break-before-make timing are not yet modeled.
- Temperature, photobleaching, reabsorption, scattering, cross-talk, and aging
  are not modeled.
- Detector curves are smooth analytic approximations, not vendor data.
- Material labels are candidates; real composition and passivation must be
  selected and validated experimentally.
- The 60-channel inverse assumes sequential bias exposures observe a stable
  scene.
- The model does not establish optical or chemical safety.

## Acceptance criteria met by the delivered defaults

- finite nonnegative response matrices;
- normalized emission bases;
- full numerical rank 36/36 at all six voltage channels;
- response condition number below 10 at all voltage channels;
- passive photon and energy ratios no greater than one;
- seeded local noise without changing MATLAB global RNG state;
- noisy reconstruction correlation above 0.999 at all voltage channels;
- no default computational-detector saturation; and
- SLX build, bind, save, reopen, update, simulate, and equation-matching tests;
  and
- zero rotary-switch blocks in either generated model.

## References and provenance

- InAs multishell CQDs and 905 nm QLED:
  https://www.nature.com/articles/s41467-025-57746-1
- InAs/ZnSe 1007-1410 nm QLED series:
  https://doi.org/10.1021/acsenergylett.5c03820
- Electric-field-dependent CQD emission and QCSE limitations:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC6814376/
- Multi-emitter voltage-dependent spectral weighting:
  https://www.nature.com/articles/s41467-020-16659-x
- PbS/CdS long-wave NIR LED example:
  https://www.nature.com/articles/s41598-017-15244-5
- IEC 62471 photobiological lamp safety overview:
  https://webstore.iec.ch/en/publication/7076

These references motivate architecture and guardrails. The numerical default
curves are synthetic unless explicitly replaced by measured data.
