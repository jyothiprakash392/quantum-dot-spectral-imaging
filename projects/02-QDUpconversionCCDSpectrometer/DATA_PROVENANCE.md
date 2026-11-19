# Data provenance and reuse notes

## General statement

This project contains no newly collected experimental measurements. Its
reference values are equations, table values, figure-source-workbook values, or
rounded article values transcribed from the cited literature. Generated MAT,
CSV, TXT, JSON, and PNG artifacts are derived from those values and the software.

Citation establishes scientific provenance but does not automatically establish
permission to redistribute copyrighted source tables. Before public deposition,
the authors must check each article and supporting-information license, replace
restricted transcriptions with a retrieval script or documented manual procedure
when necessary, and retain only data whose redistribution is permitted.

## Source map

| Local artifact/function | Origin | Local transformation | Publication interpretation |
|---|---|---|---|
| `qdCdSeEmpiricalReferences.m`, `CdSe_REAL_REFERENCE_CURVES.csv` | Yu 2003, Jasieniak 2009, de Mello Donega/Koole 2009 sizing equations | equation evaluation and energy/wavelength conversion | comparison among published equations; not independent raw observations |
| `qdEmpiricalMaterialReference.m`, ID 2 | Almeida 2023 InP volume relation | conversion from tetrahedral volume to equal-volume sphere radius | source-equation regression |
| `qdEmpiricalMaterialReference.m`, ID 3 | Moreels 2009 PbS sizing relation | equation evaluation from PbS core diameter | source-equation regression |
| `qdEmpiricalMaterialReference.m`, ID 4 | Brennan 2017 supporting table | linear interpolation in cube edge; PL/absorption separation retained | baseline calibration table |
| Mondal values in calibration/hybrid tests | Mondal 2019 article/supporting data | fixed development/evaluation split; residual correction | within-source adapter evaluation and external comparison to Brennan baseline |
| `qdCsPbBr3ReferenceData.m`, `CsPbBr3_Abbas2025_reference.csv` | Abbas 2025 source workbook, range `Fig3!A4:D37` | rate closure from PLQY and total lifetime | internal grouped evaluation conditional on PL peak energy |
| `qdPbSCdSReferenceData.m`, `PbSCdS_Stylianou2026_reference.csv` | Stylianou 2026 article Tables 1 and 2 | outer diameter calculation and whole-reported-series cross-validation | provisional Auger calibration; table values are rounded as published |
| Thick-shell PbS/CdS limitation rows in tests | Krishnamurthy 2021 | comparison with omitted quasi-type-II behavior | external out-of-scope limitation check |

## Primary identifiers

- https://doi.org/10.1021/cm034081k
- https://doi.org/10.1021/jp906827m
- https://doi.org/10.1021/jp811329r
- https://doi.org/10.1021/acs.nanolett.3c02630
- https://doi.org/10.1021/acsphotonics.8b00615
- https://doi.org/10.1021/nn900863a
- https://doi.org/10.1021/jp406774p
- https://doi.org/10.1021/acs.nanolett.6c00158
- https://doi.org/10.1021/acsnano.0c05907
- https://doi.org/10.1021/jacs.7b05683
- https://doi.org/10.1039/C9SC01339C
- https://doi.org/10.1021/acs.jpcc.4c06265
- https://doi.org/10.1038/s41467-025-60848-5

## Data-quality cautions

- Do not add PL and trap-emission counts: trap emission is a subset of total
  emission.
- The Abbas workbook labels the kinetic predictor as PL peak energy, not
  absorption band gap, and does not supply an edge length for every row.
- Stylianou Auger lifetimes used here are rounded article-table values.
- The three CdSe references are empirical relationships; their disagreement is
  source/model spread rather than repeated-measurement uncertainty.
- Cross-source comparisons combine possible model error with batch, ligand,
  geometry, and measurement-protocol differences.
