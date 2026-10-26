"""
Main driver: insert Mg17Al12 (beta) precipitates, Burgers-OR-aligned to
the host grain, nucleated preferentially on grain boundaries of the
az41poly_alloy2.cfg polycrystal.

IMPORTANT SCALE NOTE (read this before trusting the numbers):
  Box  = 201 x 201 x 201 A  (~20 x 20 x 20 nm)
  Grains (20, Voronoi) -> average grain diameter ~7.4 nm
  Paper's beta precipitates: block-shaped, ~22.8 nm average diameter
A literal 22.8 nm precipitate does not fit inside a 7-nm grain (or even
comfortably inside the whole box). For an atomistic model you must use
a *scaled-down* precipitate size (a few nm), while keeping everything
else physically faithful to the paper: block (cuboid) morphology,
Burgers OR, nucleation strictly on/near GBs, and a total precipitate
volume fraction matched to the ~10% reported by TEM. This script does
that; the target size is a parameter (PRECIP_EDGE below) you can raise
if you enlarge the box instead.
"""
import numpy as np
from scipy.spatial import cKDTree

from cfg_utils import read_extended_cfg, write_extended_cfg
from cif_utils import read_cif_structure
from orientation import read_nodes, burgers_rotation

# ---------------------------------------------------------------- config
CFG_PATH   = "/mnt/user-data/uploads/az41poly_alloy2.cfg"
NODE_PATH  = "/mnt/user-data/uploads/az41poly_param.txt"
CIF_PATH   = "/mnt/user-data/uploads/1576218-Mg17Al12.cif"
OUT_PATH   = "/home/claude/work/precip_pipeline/az41poly_with_precipitates.cfg"

GB_CUTOFF     = 3.6      # A, ~1st-NN shell in hcp Mg -> defines "at a GB"
PRECIP_EDGE   = 35.0     # A (3.5 nm) cube edge of each precipitate (scaled down, see note above)
BUFFER        = 2.5      # A, matrix atoms this close to a kept precip. face are also removed
TARGET_VF     = 0.10     # target precipitate volume fraction (paper: ~10%)
MIN_SEPARATION_FACTOR = 1.6   # keep precipitate centers >= this*EDGE apart
RNG_SEED = 7

# ------------------------------------------------------------ load data
print("Reading polycrystal ...")
poly = read_extended_cfg(CFG_PATH)
box = poly["box"]; Lx, Ly, Lz = np.diag(box)
cart, elems, grains = poly["cart"], poly["elems"], poly["grains"]
print(f"  {len(elems)} atoms, box {Lx:.1f} x {Ly:.1f} x {Lz:.1f} A, "
      f"{grains.max()} grains")

print("Reading grain nodes/orientations ...")
nodes = read_nodes(NODE_PATH)

print("Reading and expanding Mg17Al12 unit cell ...")
lat, cell_atoms = read_cif_structure(CIF_PATH)
a_beta = lat["a"]
cell_elems = np.array([e for e, p in cell_atoms])
cell_frac  = np.array([p for e, p in cell_atoms])
cell_cart0 = cell_frac * a_beta   # cubic cell -> simple scaling

R_OR = burgers_rotation()

# ------------------------------------------------------- GB atom finder
print("Finding grain-boundary atoms (KDTree, periodic) ...")
tree = cKDTree(cart, boxsize=[Lx, Ly, Lz])
pairs = tree.query_pairs(r=GB_CUTOFF, output_type="ndarray")
diff_grain = grains[pairs[:, 0]] != grains[pairs[:, 1]]
gb_atom_idx = np.unique(pairs[diff_grain].ravel())
print(f"  {len(gb_atom_idx)} atoms ({100*len(gb_atom_idx)/len(elems):.1f}%) "
      f"flagged as grain-boundary atoms")

# ------------------------------------------------- pick nucleation sites
print("Selecting precipitate nucleation sites on GBs ...")
rng = np.random.default_rng(RNG_SEED)
gb_pos = cart[gb_atom_idx]
gb_grain = grains[gb_atom_idx]

cell_vol = Lx * Ly * Lz
precip_vol = PRECIP_EDGE ** 3
n_target = max(1, int(round(TARGET_VF * cell_vol / precip_vol)))
print(f"  aiming for {n_target} precipitates "
      f"(edge {PRECIP_EDGE/10:.1f} nm) for ~{TARGET_VF*100:.0f}% volume fraction")

candidates = rng.permutation(len(gb_pos))
chosen = []
min_sep = MIN_SEPARATION_FACTOR * PRECIP_EDGE
box_vec = np.array([Lx, Ly, Lz])

def min_image_dist(p, q):
    d = (p - q + box_vec / 2) % box_vec - box_vec / 2
    return np.linalg.norm(d)

for idx in candidates:
    p = gb_pos[idx]
    if all(min_image_dist(p, c["pos"]) > min_sep for c in chosen):
        chosen.append(dict(pos=p, grain=int(gb_grain[idx])))
    if len(chosen) >= n_target:
        break
print(f"  placed {len(chosen)} precipitate nuclei")

# --------------------------------------------------- build one precipitate
def build_precipitate(center, R_lab, edge):
    """Tile the beta unit cell, rotate to lab frame, crop to a cube of
    side `edge` expressed in the PRECIPITATE's own crystal axes
    (-> genuinely block/facet shaped, matching the paper's description),
    then translate to `center`."""
    half = edge / 2 + a_beta  # pad so the crop is not starved at corners after rotation
    n_rep = int(np.ceil(half / a_beta)) + 1
    ii = np.arange(-n_rep, n_rep + 1)
    shifts = np.array(np.meshgrid(ii, ii, ii)).reshape(3, -1).T * a_beta
    all_cart = (cell_cart0[None, :, :] + shifts[:, None, :]).reshape(-1, 3)
    all_elem = np.tile(cell_elems, len(shifts))

    # crop to a cube in the precipitate's own (unrotated) frame first
    m = np.all(np.abs(all_cart) <= edge / 2, axis=1)
    local = all_cart[m]
    elem = all_elem[m]

    lab = local @ R_lab.T + center
    return lab, elem

# --------------------------------------------------------- assemble output
print("Inserting precipitates and cleaning up overlaps ...")
keep_matrix = np.ones(len(elems), dtype=bool)
new_cart_blocks, new_elem_blocks, new_grain_blocks = [], [], []

for k, c in enumerate(chosen, 1):
    R_grain = nodes[c["grain"]]["R"]
    R_lab = R_grain @ R_OR
    lab, elem = build_precipitate(c["pos"], R_lab, PRECIP_EDGE)

    # remove matrix atoms whose position (relative to center, expressed
    # in the precipitate's own crystal axes) lies inside the (padded) cube
    rel = (cart - c["pos"]) @ R_lab                # -> local precip frame
    inside = np.all(np.abs(rel) <= PRECIP_EDGE / 2 + BUFFER, axis=1)
    keep_matrix &= ~inside

    new_cart_blocks.append(lab)
    new_elem_blocks.append(elem)
    new_grain_blocks.append(np.full(len(elem), 100 + k))  # tag precip. "grains" 101,102,...
    print(f"  precipitate {k}: host grain {c['grain']}, "
          f"{len(elem)} atoms, removed {inside.sum()} matrix atoms")

precip_cart = np.concatenate(new_cart_blocks)
precip_elem = np.concatenate(new_elem_blocks)
precip_grain = np.concatenate(new_grain_blocks)

out_cart = np.concatenate([cart[keep_matrix], precip_cart])
out_elem = np.concatenate([elems[keep_matrix], precip_elem])
out_grain = np.concatenate([grains[keep_matrix], precip_grain])

# wrap into box (precipitate atoms near a periodic edge may fall outside)
out_frac = (out_cart @ np.linalg.inv(box)) % 1.0
out_cart = out_frac @ box

# final safety pass: drop any leftover too-close pairs (prefer precipitate atoms)
is_precip = np.zeros(len(out_elem), dtype=bool)
is_precip[len(cart[keep_matrix]):] = True
tree2 = cKDTree(out_cart, boxsize=[Lx, Ly, Lz])
pairs2 = tree2.query_pairs(r=1.6, output_type="ndarray")
drop = np.zeros(len(out_elem), dtype=bool)
for i, j in pairs2:
    if is_precip[i] and not is_precip[j]:
        drop[j] = True
    elif is_precip[j] and not is_precip[i]:
        drop[i] = True
    elif not is_precip[i] and not is_precip[j]:
        drop[j] = True
keep_final = ~drop
print(f"  final overlap cleanup removed {drop.sum()} atoms")

out_cart, out_elem, out_grain = (out_cart[keep_final], out_elem[keep_final],
                                  out_grain[keep_final])

from collections import Counter
print("Final composition (before conservation fix):", Counter(out_elem))

# ---------------------------------------------------- composition conservation
# Inserting Mg17Al12 (41% Al) adds Al atoms that were not "paid for" by
# depleting the surrounding alpha matrix, i.e. it silently enriches the
# nominal AZ41 composition (3.8 wt% Al). Physically, GB precipitation
# happens BY local solute depletion (this is the same constitutional-
# supercooling argument used in the paper). To keep the bulk composition
# at AZ41 we convert the excess Al atoms back to Mg, preferentially in
# the matrix shell close to each precipitate (mimicking a depletion
# zone) rather than uniformly at random.
al_before = int((poly["elems"] == "Al").sum())
al_now = int((out_elem == "Al").sum())
excess_al = al_now - al_before
print(f"Excess Al atoms introduced by precipitates: {excess_al}")

if excess_al > 0:
    is_precip_final = np.zeros(len(out_elem), dtype=bool)
    is_precip_final[-len(precip_cart):] = True  # approx: precip atoms are the tail block
    # matrix Al atoms, ranked by distance to nearest precipitate center
    matrix_al_idx = np.where((out_elem == "Al") & (~is_precip_final))[0]
    centers = np.array([c["pos"] for c in chosen])
    dists = np.min(
        np.linalg.norm(
            (out_cart[matrix_al_idx, None, :] - centers[None, :, :]
             + box_vec / 2) % box_vec - box_vec / 2, axis=2),
        axis=1)
    order = np.argsort(dists)  # closest to a precipitate first
    n_convert = min(excess_al, len(order))
    convert_idx = matrix_al_idx[order[:n_convert]]
    out_elem = out_elem.copy()
    out_elem[convert_idx] = "Mg"
    print(f"Converted {n_convert} nearby matrix Al atoms -> Mg to conserve "
          f"bulk AZ41 composition (depletion-zone approximation)")

print("Final composition (after conservation fix):", Counter(out_elem))
vf = precip_vol * len(chosen) / cell_vol
print(f"Nominal precipitate volume fraction: {vf*100:.1f}%")

write_extended_cfg(OUT_PATH, box, out_elem, out_cart, out_grain,
                    comment="AZ41 polycrystal with GB-nucleated, "
                            "Burgers-OR beta-Mg17Al12 precipitates")
print("Wrote", OUT_PATH)
