"""
Crystallography helpers: grain orientation matrices from the Atomsk
node file, and the Burgers orientation relationship between alpha-Mg
(hcp) and beta-Mg17Al12 (bcc-derived, I-43m) reported in the paper:

    (0001)_alpha // (011)_beta      [plane normals parallel]
    [11-20]_alpha // [-1-11]_beta   [in-plane directions parallel]

Assumption (state clearly to the user): the six numbers per 'node' line
in az41poly_param.txt are  x y z  followed by three Euler-type rotation
angles in degrees, applied to the base hcp cell as
    R_grain = Rz(angZ) . Ry(angY) . Rx(angX)
This matches Atomsk's --polycrystal convention where each grain's unit
cell is rotated by successive rotations about X, then Y, then Z of the
simulation box axes before the Voronoi tessellation is built. If your
Atomsk version uses a different order, only the absolute orientation of
each precipitate changes -- the rest of the pipeline (GB targeting,
composition, block shape) is unaffected.
"""
import numpy as np


def Rx(t):
    t = np.radians(t)
    c, s = np.cos(t), np.sin(t)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def Ry(t):
    t = np.radians(t)
    c, s = np.cos(t), np.sin(t)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def Rz(t):
    t = np.radians(t)
    c, s = np.cos(t), np.sin(t)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def read_nodes(path):
    nodes = {}
    gid = 0
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("node"):
                gid += 1
                vals = [float(x) for x in line.split()[1:]]
                pos = np.array(vals[:3])
                ang = vals[3:6]
                R = Rz(ang[2]) @ Ry(ang[1]) @ Rx(ang[0])
                nodes[gid] = dict(pos=pos, R=R, angles=ang)
    return nodes


def _orthonormal_frame(v1, v2):
    """Right-handed orthonormal basis with e1 || v1, e2 in span(v1,v2)."""
    e1 = v1 / np.linalg.norm(v1)
    v2p = v2 - np.dot(v2, e1) * e1
    e2 = v2p / np.linalg.norm(v2p)
    e3 = np.cross(e1, e2)
    return np.column_stack([e1, e2, e3])


def burgers_rotation():
    """
    Rotation matrix R_OR such that, in the *local hcp crystal frame*
    of a grain (c-axis = z, a1 = x, per the usual hcp setup used by
    Atomsk lattice generators):

        R_OR @ [0,1,1]/beta-normal   -> [0,0,1]              (c-axis)
        R_OR @ [-1,-1,1]/beta-dir    -> [11-20] direction

    i.e. R_OR maps beta-phase cubic coordinates into the alpha grain's
    local crystal frame so that the Burgers OR holds. Compose with the
    grain's own R_grain (from read_nodes) to get the precipitate's
    orientation in the simulation-box (lab) frame.
    """
    # beta (cubic) frame built from the two OR directions
    n_beta = np.array([0., 1., 1.])       # (011) plane normal
    d_beta = np.array([-1., -1., 1.])     # [-1-11] direction
    E = _orthonormal_frame(n_beta, d_beta)

    # alpha (hcp) target frame: c-axis and [11-20] direction
    c_hex = np.array([0., 0., 1.])
    a_hex = np.array([np.cos(np.radians(60)), np.sin(np.radians(60)), 0.])
    F = _orthonormal_frame(c_hex, a_hex)

    return F @ E.T


if __name__ == "__main__":
    nodes = read_nodes("/mnt/user-data/uploads/az41poly_param.txt")
    print("grain 1:", nodes[1])
    R_or = burgers_rotation()
    print("R_OR =\n", R_or)
    # sanity check: R_OR should be a proper rotation (det=+1, orthogonal)
    print("det:", np.linalg.det(R_or), " R.R^T ~ I:",
          np.allclose(R_or @ R_or.T, np.eye(3)))
    # verify OR mapping
    n_beta = np.array([0., 1., 1.]) / np.sqrt(2)
    d_beta = np.array([-1., -1., 1.]) / np.sqrt(3)
    print("maps (011)_beta ->", R_or @ n_beta, " (target ~ [0,0,1])")
    print("maps [-1-11]_beta ->", R_or @ d_beta, " (target ~ [cos60,sin60,0])")
