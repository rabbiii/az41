"""
Minimal CIF reader/expander - good enough for simple inorganic CIFs
(single Wyckoff-site table + explicit symmetry-operator list), which is
exactly the format of the COD Mg17Al12 file used in this project.
Not a general-purpose CIF parser.
"""
import re
import numpy as np

def read_cif_structure(path):
    with open(path) as f:
        text = f.read()

    # --- cell parameters ---
    def getval(tag):
        m = re.search(tag + r"\s+([\-0-9.]+)", text)
        return float(m.group(1))

    a = getval(r"_cell_length_a")
    b = getval(r"_cell_length_b")
    c = getval(r"_cell_length_c")
    alpha = getval(r"_cell_angle_alpha")
    beta = getval(r"_cell_angle_beta")
    gamma = getval(r"_cell_angle_gamma")

    # --- symmetry operators ---
    sym_block = re.search(
        r"_symmetry_equiv_pos_as_xyz\s*(.*?)\nloop_", text, re.S
    ).group(1)
    ops = re.findall(r"\d+\s+'([^']+)'", sym_block)

    def make_op(op_str):
        # op_str like "-z+1/2, -y+1/2, x+1/2"
        parts = [p.strip() for p in op_str.split(',')]
        def op(xyz):
            x, y, z = xyz
            out = []
            for p in parts:
                out.append(eval(p, {}, {'x': x, 'y': y, 'z': z}))
            return np.array(out)
        return op
    sym_ops = [make_op(o) for o in ops]

    # --- atom site table ---
    site_block = re.search(
        r"_atom_site_B_iso_or_equiv\s*\n(.*?)(?:\nloop_|\Z)", text, re.S
    ).group(1)
    sites = []
    for line in site_block.strip().splitlines():
        toks = line.split()
        if len(toks) < 7:
            continue
        label, species = toks[0], toks[1]
        elem = re.match(r"[A-Za-z]+", species).group(0)
        def clean(v):
            return float(re.sub(r"\(\d+\)", "", v))
        x, y, z = clean(toks[4]), clean(toks[5]), clean(toks[6])
        sites.append((elem, np.array([x, y, z])))

    # --- expand by symmetry, dedupe ---
    atoms = []
    for elem, frac in sites:
        for op in sym_ops:
            p = op(frac) % 1.0
            p[np.isclose(p, 1.0)] = 0.0
            atoms.append((elem, p))

    uniq = []
    for elem, p in atoms:
        dup = False
        for e2, p2 in uniq:
            if e2 == elem and np.all(np.abs(((p - p2 + 0.5) % 1.0) - 0.5) < 1e-3):
                dup = True
                break
        if not dup:
            uniq.append((elem, p))

    lattice = dict(a=a, b=b, c=c, alpha=alpha, beta=beta, gamma=gamma)
    return lattice, uniq


if __name__ == "__main__":
    lat, atoms = read_cif_structure(
        "/mnt/user-data/uploads/1576218-Mg17Al12.cif")
    print("lattice:", lat)
    print("n atoms in cell:", len(atoms))
    from collections import Counter
    print(Counter(e for e, p in atoms))
