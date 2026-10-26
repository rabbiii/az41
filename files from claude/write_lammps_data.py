"""
Convert the extended-CFG polycrystal(+precipitate) file into a LAMMPS
'atomic' style data file (atom_style atomic; charge-free metallic MD).
Element -> LAMMPS type mapping is written to a companion comment so you
can match it to your potential's element ordering (e.g. for pair_style
meam or eam/alloy 'pair_coeff * * pot.eam.alloy Mg Al Zn').
"""
import numpy as np
from cfg_utils import read_extended_cfg

def write_lammps_data(cfg_path, out_path, elem_order=("Mg", "Al", "Zn")):
    d = read_extended_cfg(cfg_path)
    box = d["box"]; cart = d["cart"]; elems = d["elems"]
    Lx, Ly, Lz = np.diag(box)
    type_of = {e: i + 1 for i, e in enumerate(elem_order)}
    types = np.array([type_of[e] for e in elems])

    with open(out_path, "w") as f:
        f.write("LAMMPS data file: AZ41 polycrystal + GB Mg17Al12 precipitates\n\n")
        f.write(f"{len(cart)} atoms\n")
        f.write(f"{len(elem_order)} atom types\n\n")
        f.write(f"0.0 {Lx:.6f} xlo xhi\n")
        f.write(f"0.0 {Ly:.6f} ylo yhi\n")
        f.write(f"0.0 {Lz:.6f} zlo zhi\n\n")
        f.write("Masses\n\n")
        mass = {"Mg": 24.3050, "Al": 26.9815, "Zn": 65.3800}
        for e in elem_order:
            f.write(f"{type_of[e]} {mass[e]}   # {e}\n")
        f.write("\nAtoms  # atomic\n\n")
        for i, (t, x) in enumerate(zip(types, cart), 1):
            f.write(f"{i} {t} {x[0]:.6f} {x[1]:.6f} {x[2]:.6f}\n")
    print(f"Wrote {out_path}: {len(cart)} atoms, "
          f"type map {type_of}")

if __name__ == "__main__":
    write_lammps_data(
        "az41poly_with_precipitates.cfg",
        "az41poly_with_precipitates.lammps.data")
