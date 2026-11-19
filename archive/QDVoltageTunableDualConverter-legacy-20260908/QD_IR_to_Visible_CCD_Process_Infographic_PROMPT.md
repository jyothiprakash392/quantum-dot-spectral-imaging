# Generation prompt

Use case: scientific-educational

Asset type: publication-quality start-to-finish workflow infographic

Primary request: Explain the complete operating process of a quantum-dot
IR-to-visible CCD computational spectrometer, from incoming light to
reconstructed/computed output.

Scene/backdrop: clean white-to-very-light-blue technical canvas, subtle
nanocrystal lattice texture only in the background.

Style/medium: crisp vector-like scientific infographic, modern journal
graphical-abstract quality, readable typography, precise arrows, flat 2D
technical illustrations with restrained depth.

Composition/framing: 16:9 landscape. One continuous left-to-right numbered
pipeline with seven large stages. Use large icons and short labels. Include a
slim verification/calibration ribbon along the bottom.

Text (verbatim):

- Title: “QD IR-TO-VISIBLE CCD COMPUTATIONAL SPECTROMETER”
- Stage 1 heading: “1  INCOMING SWIR LIGHT”
- Stage 1 detail: “Unknown spectrum s(λ) • 1200–1700 nm”
- Stage 2 heading: “2  PbS CQD SENSITIZER ARRAY”
- Stage 2 detail: “12 pixels absorb different SWIR bands”
- Stage 3 heading: “3  BIAS-TUNED RESPONSE”
- Stage 3 detail: “5 voltages • 0–0.68 V • D(λ,V)”
- Stage 4 heading: “4  POWERED UPCONVERSION”
- Stage 4 detail: “Photocarriers drive a CdSe/ZnS QLED”
- Stage 4 callout: “Electrical bias supplies the missing energy”
- Stage 5 heading: “5  VISIBLE EMISSION”
- Stage 5 detail: “Quantum-dot light • 562–669 nm”
- Stage 6 heading: “6  SILICON CCD”
- Stage 6 detail: “60 encoded measurements + detector noise”
- Stage 7 heading: “7  COMPUTATION”
- Stage 7 equation: “ŷ = Aŝ + b”
- Stage 7 detail: “Nonnegative regularized reconstruction”
- Output label: “RECONSTRUCTED SPECTRUM”
- Output detail: “peaks • materials • confidence”
- Bottom ribbon: “VERIFIED SOFTWARE: 85/85 checks • response rank 36/36 • demo correlation 0.9983”
- Bottom warning: “CALIBRATION REQUIRED: synthetic response and efficiency are not hardware accuracy”

Required visual content:

- Stage 1: a broad SWIR beam with a small spectral curve containing three peaks.
- Stage 2: a layered PbS colloidal quantum-dot pixel array, with different
  dots/pixels highlighted.
- Stage 3: five clean voltage steps and five distinct spectral response curves.
- Stage 4: show a photodiode-to-electrical-carriers-to-QLED energy pathway with
  a battery/bias symbol; make clear this is active, not passive fluorescence.
- Stage 5: visible green-to-red photons emitted from CdSe/ZnS dots.
- Stage 6: monochrome silicon CCD pixel grid receiving the visible light, with
  small labels for shot, dark, and read noise.
- Stage 7: matrix/inverse-computation icon feeding an output graph where the
  reconstructed blue spectrum closely overlaps the black input spectrum.
- Strong arrows must unambiguously connect stages 1 through 7.

Color palette: navy headings, SWIR in violet/magenta, PbS sensitizer in teal,
electrical stage in amber, visible photons green-to-red, CCD in cool blue,
computation/result in cyan and deep blue, warning in restrained red.

Constraints: scientifically correct; preserve all numbers, symbols, wavelength
ranges, material names, and equations exactly; distinguish SWIR input from
visible output; clearly show that external electrical bias enables the energy
increase; readable at presentation scale; no logos; no watermark; no fake
citations; no extra claims; no decorative characters.

Avoid: photorealistic laboratory scene, dark background, tiny dense paragraphs,
passive one-photon SWIR-to-visible fluorescence, illegible equations, spelling
errors, 3D clutter.

Generation mode: built-in ImageGen.
