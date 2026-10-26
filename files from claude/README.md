# Modeling GB precipitation of β-Mg17Al12 in the AZ41 polycrystal

This bundle turns `az41poly_alloy2.cfg` (a single-phase α-Mg random-solid-solution
polycrystal built by Atomsk from `az41poly_param.txt`) into a structure that also
contains β-Mg17Al12 nano-precipitates nucleated on the grain boundaries, oriented
by the Burgers OR reported in Fu et al., *Mater. Sci. Eng. A* 858 (2022) 144151
(the uploaded PDF). It follows the microstructure that paper describes for the
laser-remelted layer: equiaxed α-grains + dispersed **block-shaped**, **GB/interior
continuous** (not lamellar/discontinuous) β-Mg17Al12 precipitates, in the
Burgers OR (0001)α ∥ (011)β, [11-20]α ∥ [-1‑11]β, at ~10 vol% (Section 3.1).

## Files

| File | Purpose |
|---|---|
| `cif_utils.py` | Minimal CIF reader; expands the Mg17Al12 Wyckoff sites (from `1576218-Mg17Al12.cif`) by all 48 symmetry operators into a 58‑atom conventional cell (Mg34Al24 → Mg17Al12, a = 10.5438 Å, I‑43m). |
| `cfg_utils.py` | Reader/writer for the Atomsk "extended CFG" polycrystal format used by `az41poly_alloy2.cfg`. |
| `orientation.py` | Reads grain positions + rotation angles from `az41poly_param.txt`; builds the Burgers-OR rotation matrix from cubic β vectors to hcp α vectors. |
| `insert_precipitates.py` | **Main driver.** Detects GB atoms, chooses nucleation sites, builds Burgers‑OR‑aligned block precipitates, removes overlapping matrix atoms, conserves overall composition, writes the merged structure. |
| `write_lammps_data.py` | Converts the merged CFG into a LAMMPS `atomic`-style data file. |
| `relax_precipitates.in` | LAMMPS script: energy minimization + anneal (300↔500 K) to let the geometrically-built interfaces relax, plus CNA/centrosymmetry dumps for QC. |
| `az41poly_with_precipitates.cfg` | Example output already generated from your uploaded files (19 precipitates, ~10 vol%). |
| `az41poly_with_precipitates.lammps.data` | Same structure, LAMMPS format. |

## Step-by-step logic

### 1. Read the crystallography of both phases
- **α-Mg matrix**: hcp, per-grain orientation = 3 rotation angles in
  `az41poly_param.txt` (`node x y z angX angY angZ`), applied as
  `R_grain = Rz(angZ)·Ry(angY)·Rx(angX)` to the base hcp cell Atomsk used
  to build the grain. *(If your Atomsk version composes the angles in a
  different order, only the absolute lab-frame orientation of each
  precipitate shifts — nothing else in the pipeline depends on this.)*
- **β-Mg17Al12**: parsed directly from the CIF (space group I‑43m,
  a = 10.5438 Å — matches the 10.69 Å reported in the paper reasonably
  well for a first-principles/neutron-diffraction cell vs. the paper's
  own XRD value).

### 2. Encode the Burgers OR as a rotation matrix
The paper reports (Section 3.1, Fig. 2):
```
(0001)_α  ∥  (011)_β        (plane normals parallel)
[11-20]_α ∥  [-1-11]_β       (in-plane directions parallel)
```
`orientation.burgers_rotation()` builds two orthonormal frames — one
from the β cubic directions (011) and [‑1‑11], one from the hcp
directions [0001] and [11‑20] — and returns the rotation `R_OR` that
maps one onto the other. For any grain, the precipitate's lab-frame
orientation is simply `R_lab = R_grain @ R_OR`. This is verified in the
script's `__main__` block (mapped vectors match the target directions
to numerical precision).

### 3. Find grain-boundary sites
Using the `grainID` auxiliary field already present in the CFG (no need
to re-derive grain boundaries from disorder/CNA), a periodic KD‑tree
neighbor search flags every atom that has a first-neighbor-shell
(<3.6 Å) atom belonging to a *different* grain. ~18% of atoms qualify,
consistent with a fine, ~7 nm-grain polycrystal having a large GB
fraction.

### 4. Place precipitate nuclei and build them
Nucleation sites are drawn from the GB atom list (not uniformly through
the volume), spaced apart, until the target volume fraction is reached.
For each site, the β unit cell is tiled, rotated by that grain's
`R_lab`, and **cropped to a cube in the precipitate's own crystal
axes** — this reproduces the paper's "block-shaped" morphology (facets
on low-index β planes) rather than a spherical blob. Host α atoms
inside (+ a small buffer around) that same rotated cube are deleted, the
two atom sets are merged, and a final periodic overlap pass removes any
leftover atoms closer than 1.6 Å (precipitate atoms always win).

### 5. ⚠️ Length-scale reality check
Your box is 201×201×201 Å (~20 nm) with 20 Voronoi grains → **average
grain size ≈ 7.4 nm**. The paper's β precipitates are ~22.8 nm — bigger
than a grain here. A literal experimental-scale precipitate cannot be
atomistically embedded in this cell. The script therefore uses a
**scaled-down precipitate edge (`PRECIP_EDGE`, default 3.5 nm)**, while
preserving everything else that's physically meaningful at this scale:
Burgers OR, exclusively-GB nucleation, block morphology, and the
reported ~10% volume fraction. If you need literal micron/nm-scale
precipitate sizes and gradient grain sizes (4.6 µm → 60 nm) as in the
real remelted layer, that is a job for a larger-scale method (phase-field
or CPFE), not atomistic MD — mention this if that's actually your goal
and I can help set that up too.

### 6. Composition bookkeeping
Naively inserting Mg17Al12 (41 at% Al) atoms without removing an
equivalent amount of Al from the matrix silently enriches the whole
cell beyond AZ41's 3.8 wt% Al. The script computes the Al excess and
converts that many matrix Al atoms **nearest to each precipitate**
back to Mg — approximating the solute-depletion zone that must exist
around a real precipitate (and is the same "constitutional
supercooling" argument the paper uses for grain refinement, Section
4.1, Eq. 3–4). Note: with 19 precipitates at 10 vol%, the matrix does
not contain enough nearby Al to fully offset the excess (see the
script's printed diagnostics) — you can reduce `TARGET_VF` or
`PRECIP_EDGE`, or accept the residual, slightly Al-enriched, matrix.

### 7. Relax and validate with LAMMPS
`write_lammps_data.py` converts the merged structure. `relax_precipitates.in`:
1. energy-minimizes the (geometrically imperfect) interfaces,
2. anneals 300→500→300 K under NPT to let the α/β interfaces and any
   residual strain relax realistically,
3. dumps centrosymmetry/CNA so you can confirm in OVITO or similar that
   (a) the precipitates retain a recognizable bcc-derived structure,
   (b) the α grains stay hcp, (c) GB/interface atoms show up as
   "other" — the same heterogeneous picture as Fig. 2/8 in the paper.

**You must supply a Mg–Al(–Zn) interatomic potential** capable of
describing both α-Mg and the Mg17Al12 intermetallic (plain EAM usually
cannot reproduce the intermetallic correctly — look for an MEAM
potential, e.g. on the NIST Interatomic Potentials Repository,
https://www.ctcms.nist.gov/potentials/). Edit the `pair_style` /
`pair_coeff` lines in `relax_precipitates.in` accordingly.

## Re-running / tuning
Edit the constants at the top of `insert_precipitates.py`:
- `PRECIP_EDGE` — precipitate cube size (Å)
- `TARGET_VF` — target volume fraction (paper: ~0.10)
- `GB_CUTOFF` — neighbor cutoff defining a "GB atom"
- `MIN_SEPARATION_FACTOR` — minimum spacing between precipitate centers

Then just run:
```bash
python3 insert_precipitates.py
python3 write_lammps_data.py
lmp -in relax_precipitates.in     # after installing your potential
```

## What this does *not* capture from the paper
- The **depth-graded** grain size (4.6 µm bottom → 60 nm surface) — your
  input file is a single, roughly uniform ~7 nm grain size, i.e. it
  represents a single depth "slice" (closest to the paper's UFG/NG
  region), not the whole gradient layer.
- **Kinetic nucleation** (why precipitates form at GBs rather than just
  "being placed there") — this pipeline is a *geometric construction*
  matching the reported end-state microstructure, not a nucleation
  simulation. If you want genuine kinetics, the physically correct (but
  much more expensive) route is a hybrid MD/Monte-Carlo anneal — e.g.
  LAMMPS `fix atom/swap` biased toward GB regions, or semi-grand-
  canonical MC, run during a slow cool from a supersaturated solid
  solution — I'm happy to draft that version too if this geometric
  approach isn't sufficient for what you need.
