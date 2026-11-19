# Legacy MATLAB file index

The main [Quantum Dots Connected Math Guide](Quantum_Dots_Connected_Math_Guide.docx) explains the 105 distinct MATLAB source files in the three current packages. The archived snapshot contains 19 additional, distinct MATLAB files; the other MATLAB files in that snapshot duplicate code already present in the current packages.

These legacy files are retained for provenance and comparison. They are grouped under [`archive/QDVoltageTunableDualConverter-legacy-20260908/`](../archive/QDVoltageTunableDualConverter-legacy-20260908/), not the active package path.

| File | Purpose |
|---|---|
| `buildQDDualConversionSystem.m` | Builds the combined Simulink model that routes between powered SWIR upconversion and passive UV downconversion. |
| `buildQDVoltageTunableDownconverter.m` | Builds the focused UV-to-visible/NIR downconverter Simulink model. |
| `initQDVoltageTunableDualConverter.m` | Initializes shared settings and workspace inputs for both conversion branches. |
| `openQDDualConversionSystem.m` | Initializes and opens the combined up/down Simulink model. |
| `openQDVoltageTunableDownconverter.m` | Initializes and opens the focused downconverter model. |
| `qdBuildDownconversionResponse.m` | Builds the voltage-selected film, emission, and detector response operators. |
| `qdDecodeSelectorVoltage.m` | Decodes the command voltage into a selected fixed-emission channel and electronic gate state. |
| `qdDownconversionConfig.m` | Defines the UV input grid, six fixed-emission films, selector, detectors, and reconstruction settings. |
| `qdDownconversionReconstructionSFunction.m` | Simulink block that reconstructs the incident UV spectrum from detector measurements. |
| `qdDownconversionSFunction.m` | Simulink block that models the selected passive QD film bank and emitted signal. |
| `qdElectronicSelectorDecoderSFunction.m` | Simulink ADC/window-decoder block for voltage-to-channel selection. |
| `qdSpectralTelemetrySFunction.m` | Computes emission peak, centroid, and photon totals for model telemetry. |
| `runQDDownconversionDemo.m` | Sweeps selector channels and writes downconversion spectra and summary results. |
| `runQDDownconversionTests.m` | Checks downconversion physics, reconstruction, selector behavior, and model artifacts. |
| `runQDElectronicSelectorDemo.m` | Demonstrates selector voltage sweeps, channel changes, hysteresis, and one-hot gate behavior. |
| `setQDConversionMode.m` | Selects the combined model's upconversion or downconversion branch. |
| `setQDSelectorVoltage.m` | Sets and validates the electronic selector voltage and returns the selected film response. |
| `setQDRotorVoltage.m` | Compatibility alias for `setQDSelectorVoltage`; the function name is historical and does not imply a modeled rotor. |
| `simulateQDDownconversion.m` | Runs the passive conversion, split detector, noise/full-well model, and optional UV reconstruction. |

