# Physics and limitations

## What voltage changes

The selector voltage is an electronic command. After ADC quantization, a
window decoder chooses one calibrated channel voltage and emits a one-hot
solid-state gate vector. Each gate addresses a different fixed-emission QD
film. The package does not claim that a single passive film can be tuned from
470 to 1410 nm by changing voltage.

## UV downconversion

The downconversion path is passive and one-photon. The code enforces:

- emission wavelength longer than the complete UV input band;
- nonnegative optical and detector response matrices;
- at most one emitted photon per incident photon;
- optical energy efficiency no greater than unity;
- silicon detection in the visible/NIR-I region and InGaAs detection at longer
  wavelengths.

The six material labels are design placeholders. Actual material choice must
be reviewed for toxicity, encapsulation, photostability, exposure limits, and
disposal requirements.

## SWIR upconversion

The default SWIR branch represents an electrically assisted PbS CQD detector
driving a visible CdSe/ZnS emitter. External electrical energy supplies the
anti-Stokes energy; it is not a passive one-photon process. The response is
linear only at the configured operating point.

The focused CdSe emitter lookup preserves the validated synthetic design over
1.8-4.0 nm radius without importing the unrelated general virtual-QD agent.
It is a design reference, not new measured material data.

## Intended use

The package is appropriate for control logic, signal-flow design, sensitivity
studies, reconstruction testing, and planning calibration experiments. It is
not sufficient by itself for fabrication sign-off, clinical conclusions,
safety certification, absolute radiometry, or performance guarantees.
