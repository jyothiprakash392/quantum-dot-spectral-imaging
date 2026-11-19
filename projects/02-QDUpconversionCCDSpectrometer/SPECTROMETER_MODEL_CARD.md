# QD IR-to-Visible CCD Computational Spectrometer — Model Card

## What this model implements

The runnable `QDUpconversionCCDSpectrometer.slx` model implements this chain:

```text
1.2–1.7 µm spectral photons
        ↓
bias-tuned PbS CQD photodiode/sensitizer array
        ↓  electrical bias supplies the anti-Stokes energy
CdSe/ZnS visible QD emitter array
        ↓
silicon CCD quantum efficiency + dark/read noise
        ↓
nonnegative smooth spectral reconstruction
```

The original `VirtualQuantumDotAgent.slx` remains included and unchanged. Its
14-input/40-output finite-barrier and population model supplies the PbS
absorption centers and CdSe/ZnS emission centers used by this new system model.

## Critical distinction from the supplied detector figures

The supplied computational-spectrometer figures describe a bias-tuned **direct
CQD photodetector/ROIC**. They do not show NIR photons being optically converted
to visible light or a CCD. The delivered model follows the user's stated goal
instead: it adds an **electrically powered CQD photodiode-to-QLED upconverter**
before a visible CCD.

Ordinary one-photon QD photoluminescence cannot convert 1.2–1.7 µm photons to
visible photons. The default converter is therefore active. The model never
claims optical-only energy conservation; the unmodelled voltage source supplies
the energy difference.

## Equations

For incident photons per wavelength bin `s`, the configured converter matrix
`H` maps every sensitizer-pixel/bias exposure to visible photons:

```text
h = H s
```

Every response row has a tunable input center and width. The visible QD line
shape matrix `P` creates the total visible spectrum used for inspection:

```text
v = P h
```

After optical throughput, CCD fill factor, and line-integrated CCD quantum
efficiency `g`, the expected CCD signal is

```text
mu_signal = diag(g) H s
mu_total  = mu_signal + mu_dark
```

Noise simulation uses Poisson signal-plus-dark electrons and independent
Gaussian read noise, followed by nonnegative clipping and optional full-well
clipping.

Reconstruction solves

```text
minimize  0.5 ||W(A s - (y-dark))||² + 0.5 alpha² ||diff(s)||²
subject to s >= 0
```

with a fixed-dependency projected-FISTA implementation. No Optimization,
Signal Processing, Image Processing, DSP, or Simscape toolbox is required.

## Default dimensions and meaning

- Input band: 1,200–1,700 nm
- Spectral bins: 36 (14.29 nm grid spacing)
- Converter pixels: 12
- Bias states: 5 over 0–0.68 V
- Measurements: 60 per reconstructed spectrum
- Engineered response FWHM: 30 nm
- Visible grid: 420–720 nm
- Input units: photons per input bin, per converter pixel, per bias exposure
- CCD output units: primary electrons per exposure

The grid spacing is not the physical resolution. Resolution must be established
with calibrated two-line experiments at a stated signal-to-noise ratio.

## Calibration status

The delivered response family and 1% peak conversion photon efficiency are
**synthetic design values**. They are useful for architecture, controls,
algorithm, and SNR studies, but are not quantitative predictions of fabricated
hardware.

For quantitative work, scan a calibrated monochromatic source across the input
band at every bias and measure the CCD electrons. Install that absolute response
and its dark vector with:

```matlab
cfg = qdUpconversionSpectrometerConfig;
cfg = qdApplyMeasuredSpectralCalibration(cfg,lambda_nm,D, ...
    'DarkElectrons',dark,'Label','device/date/temperature/irradiance');
```

`D` must contain CCD electrons per incident photon and must have one row for
every pixel/bias measurement. This end-to-end calibration automatically absorbs
input optics, CQD absorption/transport, upconverter gain, visible relay optics,
CCD QE, and electronic gain.

## Included effects

- published-scope PbS first-exciton centers from the existing material-3 model
- finite-barrier CdSe/ZnS visible PL centers from the existing material-1 model
- pixel-dependent and bias-dependent spectral response
- explicit visible-emission spectra and wavelength-dependent CCD QE
- optical throughput and fill factor
- Poisson signal/dark noise, Gaussian read noise, and full-well clipping
- response rank and condition-number diagnostics
- measured response/dark replacement API
- deterministic local random stream
- nonnegative regularized reconstruction

## Not yet included

- drift versus temperature, dose, age, or bias history
- QLED threshold, gain compression, persistence, or electrical power waveform
- scene motion during the sequential bias sweep
- spatial PSF, pixel crosstalk, fixed-pattern noise, ADC gain/quantization
- a full 2-D or 3-D hyperspectral image cube
- measured responsivity, absolute EQE, or measured conversion efficiency
- detector/package parasitics and thermal dynamics

These omissions are the next calibration and hardware-in-the-loop tasks. The
`quantitativeHardwarePrediction` flag remains false until a measured response
matrix is supplied.

## Architecture references

- Mu et al., “Hyperspectral quantum-dot image sensors via in-pixel
  reconfigurable band-alignment,” *Nature Photonics* (2026):
  https://www.nature.com/articles/s41566-026-01860-z
- Zhou et al., “Solution-processed upconversion photodetectors based on quantum
  dots,” *Nature Electronics* (2020):
  https://www.nature.com/articles/s41928-020-0388-x
