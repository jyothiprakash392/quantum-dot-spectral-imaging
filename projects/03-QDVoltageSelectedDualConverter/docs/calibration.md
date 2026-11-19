# Calibration guide

The delivered defaults are synthetic. Quantitative hardware use requires the
complete optical chain to be measured at the same temperature, bias, exposure,
geometry, and detector settings used in operation.

## SWIR branch

Measure one detector-response column for each known input wavelength. Arrange
the columns as electrons per incident photon, with one row per pixel/bias
measurement. Apply it with:

```matlab
config = qdUpconversionSpectrometerConfig;
config = qdApplyMeasuredSpectralCalibration( ...
    config, measuredWavelength_nm, measuredResponse, ...
    'DarkElectrons', measuredDark, ...
    'Label', 'device serial and calibration date');
```

Store the returned configuration in `qdSpectrometerConfig` before rebuilding
the response. Record wavelength calibration, dark frames, read-noise estimate,
full-well limit, exposure, electrical bias, and measurement uncertainty.

## UV branch

For each of the six selector voltages, measure:

1. ADC code and the selected one-hot gate;
2. film absorption versus UV wavelength;
3. emitted spectrum and total photon yield;
4. silicon/InGaAs throughput and quantum efficiency;
5. dark current, read noise, and full-well behavior;
6. the UV filter-array response at every reconstruction bias.

Replace the corresponding fields returned by `qdDownconversionConfig`, then
rebuild with `qdBuildDownconversionResponse`. Keep calibration units as photon
counts per wavelength bin and electrons per incident photon; do not mix these
with continuous spectral-density units without integrating over bin width.

## Acceptance checks

After calibration, rerun `runAllQDConverterTests` and add device-specific tests
for response rank, conditioning, saturation, repeatability, wavelength error,
reconstruction error, and uncertainty bounds.
