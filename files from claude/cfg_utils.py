"""
Reader/writer for the Atomsk 'extended CFG' polycrystal format used in
az41poly_alloy2.cfg: mass/species lines appear only when the species
changes between consecutive atoms; atom lines are
    fx fy fz type grainID
in fractional coordinates.
"""
import numpy as np

def read_extended_cfg(path):
    box = np.zeros((3, 3))
    natoms = None
    header_done = False
    species = None
    elems, frac, grains = [], [], []

    with open(path) as f:
        lines = f.read().splitlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("Number of particles"):
            natoms = int(line.split("=")[1])
        elif line.startswith("H0("):
            key = line.split("=")[0].strip()
            val = float(line.split("=")[1])
            r = int(key[3]) - 1
            c = int(key[5]) - 1
            box[r, c] = val
        elif line.startswith("entry_count") or line.startswith(
                "auxiliary") or line.startswith(".NO_VELOCITY.") \
                or line.startswith("A ="):
            pass
        elif line == "":
            pass
        else:
            toks = line.split()
            if len(toks) == 1:
                try:
                    float(toks[0])
                    # mass line - ignore, next line is species symbol
                except ValueError:
                    species = toks[0]  # element symbol line
            elif len(toks) == 5:
                fx, fy, fz, typ, gid = toks
                elems.append(species)
                frac.append((float(fx), float(fy), float(fz)))
                grains.append(int(gid))
        i += 1

    frac = np.array(frac)
    grains = np.array(grains)
    elems = np.array(elems)
    assert natoms == len(frac), f"{natoms} header vs {len(frac)} parsed"
    cart = frac @ box  # box assumed orthogonal / row-vector convention
    return dict(box=box, elems=elems, frac=frac, cart=cart, grains=grains)


def write_extended_cfg(path, box, elems, cart, grains, comment="polycrystal + precipitates"):
    frac = cart @ np.linalg.inv(box)
    order = np.argsort(elems, kind="stable")
    elems = elems[order]; frac = frac[order]; grains = grains[order]

    mass = {"Mg": 24.3050, "Al": 26.9815, "Zn": 65.3800}
    with open(path, "w") as f:
        f.write(f"Number of particles = {len(elems)}\n")
        f.write(f"# {comment}\n")
        f.write("A = 1.000000000 Angstrom (basic length-scale)\n")
        for r in range(3):
            for c in range(3):
                f.write(f"H0({r+1},{c+1}) = {box[r,c]:16.8f}\n")
        f.write(".NO_VELOCITY.\n")
        f.write("entry_count =   5\n")
        f.write("auxiliary[0] = type\n")
        f.write("auxiliary[1] = grainID\n")
        cur = None
        for e, x, gid in zip(elems, frac, grains):
            if e != cur:
                f.write(f"{mass[e]:9.4f}\n{e}\n")
                cur = e
            f.write(f"{x[0]:.8f}    {x[1]:.8f}    {x[2]:.8f}  1  {gid}\n")


if __name__ == "__main__":
    d = read_extended_cfg("/mnt/user-data/uploads/az41poly_alloy2.cfg")
    print("box diag:", np.diag(d["box"]))
    print("n atoms:", len(d["elems"]))
    from collections import Counter
    print(Counter(d["elems"]))
    print("grain ids:", sorted(set(d["grains"]))[:5], "...")
