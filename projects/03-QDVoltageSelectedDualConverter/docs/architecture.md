# Architecture

## Combined model

```mermaid
flowchart LR
  SWIR[SWIR spectrum<br/>1200-1700 nm] --> UP[Powered PbS/CdSe<br/>upconverter]
  UP --> VIS[Visible emission + CCD]
  VIS --> SWIRREC[SWIR reconstruction]

  UV[UV spectrum<br/>280-420 nm] --> FILMS[Six fixed QD films]
  V[0.3-2.8 V] --> ADC[12-bit ADC]
  ADC --> DEC[Window decoder<br/>20 mV hysteresis]
  DEC --> GATE[One-hot solid-state gate]
  GATE --> FILMS
  FILMS --> HYBRID[Si CCD + InGaAs detector]
  FILMS --> UVREC[UV reconstruction]

  UP --> MODE{Mode 0 or 1}
  FILMS --> MODE
  MODE --> OUT[Selected VIS/NIR output]
```

Mode `0` selects powered SWIR upconversion. Mode `1` selects passive UV
downconversion. The combined output grid spans 420-1800 nm, and a photon-
conserving interpolation matrix maps the visible upconversion grid onto it.

## Independent branches

`QDUVDownconverter.slx` calls only `initQDUVDownconverter`; it no longer
initializes or depends on the SWIR branch. `QDSWIRUpconversionSpectrometer.slx`
similarly calls only its own initializer. `QDVoltageSelectedDualConverter.slx`
composes both independent branches.

Every model contains a self-bootstrap callback. A model opened directly from
`models/` locates the package root, runs setup, and then invokes the correct
branch initializer.

Fresh diagrams are generated in `results/figures/`:

- `qd-voltage-selected-dual-converter-diagram.png`
- `uv-downconverter-diagram.png`
- `swir-upconversion-spectrometer-diagram.png`
