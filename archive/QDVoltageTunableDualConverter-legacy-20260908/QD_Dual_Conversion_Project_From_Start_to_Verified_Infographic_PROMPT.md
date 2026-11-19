# Image-generation prompt

Mode: built-in ImageGen

Use case: scientific-educational

Asset type: publication-quality project-history workflow infographic

Primary request: Create one complete start-to-finish infographic explaining
everything built for the quantum-dot Simulink project, from the original idea
through the voltage-selected UV-to-NIR extension and final verification.

Scene/backdrop: clean white to very-light-blue technical canvas with subtle
nanocrystal lattice motifs only in unused background areas.

Style/medium: crisp vector-like scientific infographic, journal
graphical-abstract quality, modern engineering diagram, readable typography,
precise arrows, flat 2D technical illustrations with restrained depth.

Composition/framing: 16:9 landscape. Two parallel left-to-right pipelines.
Top pipeline is the original powered up-conversion system. Bottom pipeline is
the later passive down-conversion extension. Both merge into a final dual-mode
Simulink system at the right. A narrow verification ribbon spans the bottom.
Use strong hierarchy and generous whitespace.

## Text

- Main title: `QUANTUM-DOT DUAL CONVERSION SYSTEM`
- Subtitle: `FROM ORIGINAL IDEA TO VERIFIED SIMULINK MODEL`
- Top section: `PHASE 1 — ORIGINAL SWIR UPCONVERSION`
- Top stages: `SWIR INPUT`, `1200–1700 nm`, `PbS CQD PHOTODIODE`,
  `bias-tuned absorption`, `POWERED QD UPCONVERTER`,
  `electrical bias supplies energy`, `VISIBLE QD EMISSION`, `563–667 nm`,
  `SILICON CCD`, `SWIR RECONSTRUCTION`
- Bottom section: `PHASE 2 — VOLTAGE-SELECTED UV DOWNCONVERSION`
- Bottom stages: `UV INPUT`, `280–420 nm`, `COMPUTATIONAL FILTER ARRAY`,
  `12 pixels × 5 bias states = 60 measurements`, `VOLTAGE SLIDER`,
  `electronic decoder selects a fixed QD channel`, `PASSIVE VIS/NIR EMISSION`,
  `DICHROIC DETECTOR`, `Si CCD + InGaAs`, `UV RECONSTRUCTION`
- Voltage mapping: `0.3 V → 470 nm`, `0.8 V → 535 nm`,
  `1.3 V → 625 nm`, `1.8 V → 905 nm`, `2.3 V → 1275 nm`,
  `2.8 V → 1410 nm`
- Merge section: `PHASE 3 — ATTACHED DUAL-MODE SYSTEM`, `MODE SWITCH`,
  `0: SWIR UP  •  1: UV DOWN`, `SIMULINK + COMPUTATION`
- Important callout: `VOLTAGE SELECTS FILMS`,
  `NOT one film sweeping UV to NIR`
- Verification: `VERIFIED: 13/13 NEW TESTS + 12/12 INHERITED TESTS`,
  `RANK 36/36  •  CONDITION ≤ 5.29  •  CORRELATION ≥ 0.999  •  NO DEFAULT SATURATION`
- Warning: `SYNTHETIC DEFAULTS — MEASURED HARDWARE CALIBRATION REQUIRED`

## Required visual content

- Top path: magenta SWIR spectral curve/beam enters a layered PbS CQD
  photodiode; amber battery/bias symbol; visible green-to-red photons emerge;
  blue silicon CCD pixel grid; computation matrix reconstructs an overlapping
  SWIR spectrum.
- Bottom path: violet UV beam with three spectral peaks enters a 12-by-5
  encoded filter-array visualization; a voltage slider feeds an ADC/window
  decoder and electronic gate bank that chooses among six clearly separated
  fixed QD film tiles, with no moving parts; output photons range from
  blue through visible red to deep NIR; a dichroic optic splits the light into
  a silicon CCD arm and an InGaAs arm; computation reconstructs an overlapping
  UV spectrum.
- The six film tiles must appear as distinct materials/bands. Do not draw one
  dot continuously changing color.
- Top and bottom paths merge only at the final dual-mode control/system.
- Use unambiguous arrows and clearly separated stages.
- Show simplified Simulink-style blocks inside the final system without
  copying any company branding.

Color palette: navy headings; SWIR violet/magenta; UV deep violet; electrical
energy amber; visible photons blue/green/red; NIR photons dark red; silicon
detector cool blue; InGaAs detector teal; computation cyan/deep blue;
validation green; warning restrained red.

Constraints: scientifically accurate; preserve all wavelength ranges,
voltages, test counts, equations/numbers, and detector names exactly; make the
difference between powered upconversion and passive downconversion visually
obvious; readable at presentation scale; no logos; no watermark; no citations;
no decorative people; no 3D clutter.

Avoid: dark background, tiny paragraphs, passive SWIR-to-visible fluorescence,
a single QD film sweeping from 470 to 1410 nm, silicon CCD detecting 1275 or
1410 nm directly, rotary controls, moving mechanical selectors, ambiguous
arrows, misspelled technical terms, or invented performance claims.
