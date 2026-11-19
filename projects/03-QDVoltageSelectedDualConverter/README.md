# QD Voltage-Selected Dual Converter

`QDVoltageSelectedDualConverter` is a clean MATLAB/Simulink package for two
quantum-dot wavelength-conversion paths:

- mode `0`: powered SWIR-to-visible upconversion and CCD reconstruction;
- mode `1`: passive UV-to-visible/NIR downconversion with voltage-selected
  fixed QD films and hybrid silicon/InGaAs detection.

The selector is fully electronic. A 12-bit ADC, voltage-window decoder,
20 mV comparator hysteresis, and one-hot gate command select one of six
fixed-emission films. The command voltage does **not** continuously tune one
film, and no rotor or other mechanical selector is modeled.

## Start here

In MATLAB, change into this folder and run:

```matlab
startQDVoltageSelectedDualConverter
```

This adds only the supported package folders, builds missing models, initializes
both branches, and opens the combined model. To rebuild and open all models:

```matlab
openAllQDModels(true)
```

The three generated models are:

- `models/QDVoltageSelectedDualConverter.slx`
- `models/QDUVDownconverter.slx`
- `models/QDSWIRUpconversionSpectrometer.slx`

## Voltage and mode control

```matlab
setupQDVoltageSelectedDualConverter;
setQDConversionMode('down');   % or 1
setQDSelectorVoltage(1.8);     % selects the 905 nm fixed-emission channel
openQDVoltageSelectedDualConverter;
```

Supported selector setpoints are:

| Command (V) | Nominal output peak (nm) |
|---:|---:|
| 0.3 | 470 |
| 0.8 | 535 |
| 1.3 | 625 |
| 1.8 | 905 |
| 2.3 | 1275 |
| 2.8 | 1410 |

Use `setQDUVSpectrum` and `setQDSWIRSpectrum` to supply custom photon-count
vectors without rebuilding a model.

## Validate and reproduce

```matlab
setupQDVoltageSelectedDualConverter;
summary = runAllQDConverterTests;   % expected: 24 passed, 0 failed
demos = runAllQDConverterDemos;     % regenerates figures, tables, and diagrams
```

Generated evidence is kept under `results/`; Simulink caches and temporary
build files are redirected outside the package. The source tree therefore
stays free of `.slxc`, `slprj`, hidden build folders, and demo `.mat` dumps.

## Requirements

- MATLAB and Simulink; validated with MATLAB R2026a.
- No rotor, motor-control hardware, or mechanical model.
- No additional toolbox is intentionally called by the package algorithms.

## Important limitation

The included film, detector, efficiency, response, and noise curves are
physics-constrained **synthetic defaults**, not measured hardware calibration.
Use them for architecture exploration and software verification. Calibrate the
response before making quantitative device or fabrication claims.

See [architecture](docs/architecture.md),
[physics and limitations](docs/physics-and-limitations.md),
[calibration](docs/calibration.md), and [migration](docs/migration.md).
