import numpy as np
from glob import glob

# machine dependent parameters
ncores_per_node = 40 # orion
ncores_per_node = 80 # hercules
fill_all_nodes = False
last_node_occupancy = 40 # in %
IOlayout_x = 4
IOlayout_y = 4

tables = glob("mask_tables/mask_table.*")

squareish_tables = []
for table in tables:
    # get the number of tiles from file name
    nx, ny = table.split(".")[-1].split("x")
    # filter out decompostion that are out of a ratio 1 < nx/ny < 3
    # these are not square enough
    if (float(nx)/float(ny) < 1.0) or (float(nx)/float(ny) > 3.0):
        pass
    else:
        squareish_tables.append(table)
print(f" keeping {len(squareish_tables)} out of {len(tables)} candidates")

goodsize_tables = []
for table in squareish_tables:
    # check size works with IO layout
    nx, ny = table.split(".")[-1].split("x")
    if (np.mod(int(nx), IOlayout_x) == 0) and (np.mod(int(ny), IOlayout_y) == 0):
        goodsize_tables.append(table)
    else:
        pass

fullnode_tables = []
for table in goodsize_tables:
    # get the number of tiles from file name
    nx, ny = table.split(".")[-1].split("x")
    nelim = table.split(".")[-2]
    npes = int(nx)*int(ny)-int(nelim)
    if fill_all_nodes:
        if (np.mod(npes, ncores_per_node) != 0):
            pass
        else:
            fullnode_tables.append(table)
    else:
        # for machines with large core count per node, it can be hard
        # to fill all cores, condition is to fill at least 95% of the last node
        if (np.mod(npes, ncores_per_node) < last_node_occupancy*ncores_per_node/100):
            pass
        else:
            fullnode_tables.append(table)
print(f" keeping {len(fullnode_tables)} out of {len(squareish_tables)} candidates")

print("you can now copy the following tables, by copy/pasting this:")
for table in fullnode_tables:
    #mask_table.1228.76x56
    _, land, x, y = table.replace(".", " ").replace("x"," ").split()
    tot_pes = int(x)*int(y)-int(land)
    print(f"cp {table} . # {tot_pes} PEs")
