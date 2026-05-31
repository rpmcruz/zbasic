#!/usr/bin/env python3
base = 'progs/extracted/Supermarket/Supermarket. Folder 1_30_94/'

# PG PRO.INCL line 636: "LOCAL" prefix on a decorator comment line (source corruption)
# The 5 bytes "LOCAL" were decoded from a binary token that precedes the ' comment char
path = base + 'PG PRO.INCL'
data = open(path, 'rb').read()
data = data.replace(b"LOCAL'\xb7\xb7\xcf", b"'\xb7\xb7\xcf")
open(path, 'wb').write(data)
