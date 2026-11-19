# Migration from the legacy mixed package

The previous folder combined the converter with a separate virtual-QD agent,
research validation suites, stale diagrams, generated MAT files, and rotor-era
compatibility names. The canonical release intentionally makes a clean break.

| Previous name | Canonical name |
|---|---|
| `QDVoltageTunableDualConverter/` | `QDVoltageSelectedDualConverter/` |
| `QDDualConversionSystem.slx` | `QDVoltageSelectedDualConverter.slx` |
| `QDVoltageTunableDownconverter.slx` | `QDUVDownconverter.slx` |
| `QDUpconversionCCDSpectrometer.slx` | `QDSWIRUpconversionSpectrometer.slx` |
| `initQDVoltageTunableDualConverter` | `initQDVoltageSelectedDualConverter` |
| `initQDUpconversionSpectrometer` | `initQDSWIRUpconversionSpectrometer` |
| `buildQDDualConversionSystem` | `buildQDVoltageSelectedDualConverter` |
| `buildQDVoltageTunableDownconverter` | `buildQDUVDownconverter` |
| `buildQDUpconversionCCDSpectrometer` | `buildQDSWIRUpconversionSpectrometer` |

The removed `setQDRotorVoltage`, `qdRotorVoltage_V`,
`qdDownResponseAtRotor`, `detentVoltage_V`, `nearest_detent`, and
`adjacent_crossfade` aliases are not provided on the new MATLAB path. Use
`setQDSelectorVoltage` and `selector.channelVoltage_V`.

Generated evidence now has one purpose per name and lives under `results/`.
The original mixed package is retained as the verified recoverable archive
`work/archive/QDVoltageTunableDualConverter-legacy-20260908.zip`; it is not
added by setup and cannot shadow new functions.
