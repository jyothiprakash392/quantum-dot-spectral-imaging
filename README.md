# Quantum Dot Wavelength-Conversion Spectral Imaging

This repository organizes the quantum-dot simulation work around one goal: convert incoming wavelengths into bands a detector can capture, then use calibrated measurements to reconstruct spectral information or an image.

The intended camera architecture uses a wavelength-conversion channel in front of a detector. For a single detector, the channels are measured sequentially: select a QD response, capture a frame, change the selected response, and repeat. The resulting stack of channel measurements can be used for hyperspectral reconstruction. The code here is simulation and architecture work; it does not establish a calibrated, fabricated camera.

## Start here

1. Read [the connected math and code guide](docs/Quantum_Dots_Connected_Math_Guide.docx) for the mathematical flow, methodology, diagrams, result examples, and systematic explanations of the MATLAB files.
2. For a detailed, 12-page IEEE-style report, read the [research paper (Word)](docs/IEEE_Quantum_Dot_Wavelength_Conversion_Paper.docx) or its [PDF](docs/IEEE_Quantum_Dot_Wavelength_Conversion_Paper.pdf). It connects the QD and detector math, explains the two converter branches and selector, includes methodology and Simulink diagrams, reports results with evidence labels, and maps the MATLAB files by package. Results remain clearly identified as simulated, software-validated, literature-comparison, or experimentally calibrated.
3. Choose one of the three packages below. Each is kept self-contained so its MATLAB entry points, model files, source, and results stay together.
4. Use the package README and its start script for that branch.

## How the math connects

Photon wavelength and energy are related by

\[
E_\gamma = \frac{hc}{\lambda}, \qquad E_\gamma\,[\mathrm{eV}] \simeq \frac{1239.84}{\lambda\,[\mathrm{nm}]}.
\]

The input spectrum excites a QD according to its absorption and excitation probabilities. The model then accounts for radiative emission, non-radiative loss, trapping, and the selected wavelength-conversion path. The emitted spectrum is weighted by the optical path and detector response. For channel \(j\), a simplified measurement model is

\[
y_j = \int S(\lambda)\,K_j(\lambda)\,\eta_j(\lambda)\,d\lambda + b_j + n_j,
\]

where \(S\) is the scene spectrum, \(K_j\) is the calibrated QD conversion response for the selected channel, \(\eta_j\) is the detector/readout response, \(b_j\) is background, and \(n_j\) is noise. In a discretized multi-channel scan this becomes

\[
\mathbf y = \mathbf A\mathbf x + \mathbf b + \mathbf n,
\]

where \(\mathbf x\) is the unknown spectrum and each row of \(\mathbf A\) describes one measured QD channel. A calibrated, constrained inverse method estimates \(\mathbf x\) from \(\mathbf y\). For an image, this measurement and reconstruction is repeated per spatial pixel (or image location).

The practical consequence is that hyperspectral reconstruction depends on distinct, stable channel responses and calibration. The voltage-selected model below selects among six fixed-emission films; voltage does not continuously tune one film. The SWIR branch models powered upconversion, while the UV branch models passive downconversion.

## Repository layout

```text
QuantumDotSpectralImaging/
├── README.md
├── docs/
│   ├── LEGACY_MATLAB_FILE_INDEX.md
│   └── Quantum_Dots_Connected_Math_Guide.docx
├── archive/
│   └── QDVoltageTunableDualConverter-legacy-20260908/
├── projects/
│   ├── 01-VirtualQuantumDotAgent/
│   ├── 02-QDUpconversionCCDSpectrometer/
│   └── 03-QDVoltageSelectedDualConverter/
└── results/
    ├── QD_Converter_Documented_Results.xlsx
    └── README.md
```

### Project packages

| Folder | What it contains | Main MATLAB entry points |
|---|---|---|
| [`01-VirtualQuantumDotAgent`](projects/01-VirtualQuantumDotAgent/) | CdSe/ZnS quantum-dot physics/agent model, material references, validation artifacts, and its Simulink model. | `runVirtualQuantumDotDemo`, `openVirtualQuantumDotAgent` |
| [`02-QDUpconversionCCDSpectrometer`](projects/02-QDUpconversionCCDSpectrometer/) | SWIR-to-visible upconversion, CCD spectral sensing/reconstruction, ensemble and hybrid models, and validation/demo evidence. | `runQDUpconversionDemo`, `openQDUpconversionCCDSpectrometer` |
| [`03-QDVoltageSelectedDualConverter`](projects/03-QDVoltageSelectedDualConverter/) | Combined SWIR upconversion and UV downconversion branches, with voltage-selected channels, Simulink models, tests, demos, and reports. | `startQDVoltageSelectedDualConverter` |

The numbered order moves from the original virtual QD model, through the CCD spectrometer branch, to the combined voltage-selected converter package. Shared MATLAB files remain in each package where needed to keep those packages independently runnable.

An earlier integrated package snapshot is preserved under [`archive/`](archive/). It includes 19 MATLAB files that are distinct from the active packages, along with its original models and results. It is kept for reference; the current combined package is the starting point for new work. [`LEGACY_MATLAB_FILE_INDEX.md`](docs/LEGACY_MATLAB_FILE_INDEX.md) explains those additional source files.

## Running a package

Use MATLAB with Simulink installed. Change into the selected package directory before calling its entry point. For the combined package:

```matlab
cd('projects/03-QDVoltageSelectedDualConverter')
startQDVoltageSelectedDualConverter
```

The dual converter also exposes selector and mode controls. For example:

```matlab
setupQDVoltageSelectedDualConverter
setQDConversionMode('down')
setQDSelectorVoltage(1.8)
openQDVoltageSelectedDualConverter
```

See each package's README for branch-specific instructions, parameters, and existing validation/demo commands. MATLAB was not run as part of organizing this repository.

## Results and scientific limits

Existing plots, CSV tables, MAT workspaces, validation summaries, manifests, Simulink diagrams, and the documented results workbook are preserved with their source packages or indexed in [`results/`](results/README.md). They are historical outputs copied from the supplied folders; no new measurements or simulations were generated during repository preparation.

Several model response, conversion-efficiency, detector, and noise curves are synthetic or physics-constrained defaults. Treat simulated and validation results as software/architecture evidence unless a result explicitly points to measured data and its provenance. The calibration and limitations documents in the dual-converter package describe these constraints in more detail.

## Version-control notes

Generated Simulink caches, autosaves, and macOS metadata are excluded. Source, model files, data references, result images/tables, and MAT result files are retained. No license has been added; add one only if you choose the terms for re-use and redistribution.
