# Publication-readiness audit — version 1.5.1

## Audit outcome

The scientific narrative, public API terminology, bounded-ensemble behavior,
zero-weight behavior, validation labels, and reproducibility instructions were
audited and corrected. The code and manuscript core are suitable for author and
journal review after the nontechnical blockers below are resolved. No technical
audit can guarantee acceptance or the absence of every possible error.

## Corrected issues

| Issue | Correction |
|---|---|
| Detector quantum efficiency was followed by fields named as photon counts | Canonical outputs now use `signalPhotoelectronCountExpected`, `darkCountExpected`, and `totalDetectorCountExpected`; the model states the one-primary-photoelectron assumption |
| Broad bounded lognormal distributions could use an unconditioned rule merely because quadrature nodes were inside the bounds | The unbounded rule is used only when excluded probability is <= 1e-12; otherwise the distribution is explicitly conditioned |
| Zero-number-fraction histogram bins could affect flags, common-grid extent, and minimum confidence | Zero-weight bins are removed before member simulations and aggregation |
| Missing finite photon budget was reported as if the optically thin approximation were valid | Depletion indicator and validity now return `NaN`, with an explicit “not assessed” status |
| External CsPbBr3 literature comparison was called an independent holdout | It is now labeled an external cross-source/protocol comparison |
| Three PbS/CdS synthesis series were called independent | They are now called three reported series; the evaluation remains whole-series cross-validation |
| The historical summary said ensemble and detector effects were absent after those features had been added | Limitations now describe the effects that remain absent: optical depth, transfer, detector gain/dead time/saturation, and event timing |
| “Agent” wording could imply an embedded autonomous AI system | Publication framing uses “physics-constrained digital twin” and “agent-ready numerical API” |

## Evidence labels that must be preserved

- 73/73 means software and mathematical checks passed; it is not an accuracy
  percentage.
- ID 2 and ID 3 optical zero-error results reproduce source equations; they are
  not experimental prediction errors.
- ID 5's 0.371 meV result is a fit residual against equations used in fitting.
- The seven-point ID-4 69.587 meV value is an external cross-source/protocol
  comparison, not a pre-registered experimental holdout.
- The ID-4 optical adapter and kinetics use fixed within-source evaluation sets.
- ID-4 kinetic errors are conditional on measured PL energy and exclude
  size-to-PL uncertainty.
- The ID-3 Auger score is provisional because it uses 13 rounded rows from
  three reported series.
- `modelConfidence` is heuristic and is not a confidence level.

## Submission blockers requiring author action

1. Add the final author list, affiliations, ORCID identifiers, corresponding
   author, and author-contribution statement.
2. Add funding, acknowledgments, conflicts of interest, and ethics statements
   required by the target journal.
3. Choose and add a software license. None is inferred by this audit.
4. Confirm copyright/licensing permission before publicly redistributing CSV
   files that reproduce or transcribe published tables. A DOI citation does not
   itself grant redistribution rights.
5. Choose the journal and apply its manuscript template, reference style,
   graphical abstract, word limit, and data/code availability requirements.
6. Obtain domain-expert coauthor review, especially for effective-mass scope,
   perovskite phase/temperature interpretation, and detector assumptions.
7. If claims of predictive experimental performance are desired, add a new,
   prospectively held-out experimental batch. The current package does not
   contain such a universal validation set.

## Recommended claim

“The software is numerically verified and literature-calibrated within declared
observable-specific envelopes. Reported errors are calibration residuals,
internal frozen evaluations, or external cross-source comparisons as labeled;
they are not universal confidence intervals.”

## Claims to avoid

- “The model is 100% accurate” or “73/73 proves 100% accuracy.”
- “The model applies to all quantum dots.”
- “Deep learning guarantees the best accuracy.”
- “The predicted wavelength is a direct wavelength converter from lambda1.”
- “Detected photoelectrons are emitted photons.”
- “The pump-depletion indicator is optical depth.”
- “The CsPbBr3 kinetics are independently validated end to end from size.”
