#!/usr/bin/env python3
# grglflx27.txt line 1076: tab character corrupting identifier "ItemID" -> "Item\tID"
path = 'progs/extracted/Grglflx/grglflx27.txt'
data = open(path, 'rb').read()
data = data.replace(b'Item\tID', b'ItemID')
open(path, 'wb').write(data)
