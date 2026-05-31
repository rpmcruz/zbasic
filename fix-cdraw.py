#!/usr/bin/env python3
# CDraw45.txt line 704: missing opening quote before first ON...GOTO target
# Was:  ON ItemID GOTO New","Open","X",...
# Now:  ON ItemID GOTO "New","Open","X",...
# CDraw45.txt line 912: orphaned expression fragment (source corruption), removed
# CDraw45.txt line 929: orphaned tail fragment "Y0)/EXP(Xend*ExpXFactor!):" (source corruption), removed
path = 'progs/extracted/CDraw/CDraw45.txt'
data = open(path, 'rb').read()
data = data.replace(b'GOTO New",', b'GOTO "New",')
data = data.replace(b'CurveK&(Function,X-1))*Hunit\r', b'')
data = data.replace(b'Exp:\rY0)/EXP(Xend*ExpXFactor!):\r', b'Exp:\r')
# CDraw45.txt line 1079: stray '"' after gosub target (source corruption), removed
data = data.replace(b'gosub Setup_Help_Window"\r', b'gosub Setup_Help_Window\r')
# CDraw45.txt lines 1305/1312: \xf8\xc1 decoded as "XXX.Enabled=False" and \xf8\xc2 as "XXX.Enabled=True"
# These are MENU disable/enable calls: MENU(MHndl&(MenuType),0) and MENU(MHndl&(MenuType),1)
data = data.replace(b'XXX.Enabled=False(MenuType),0)', b'MENU(MHndl&(MenuType),0)')
data = data.replace(b'XXX.Enabled=True(MenuType),0)', b'MENU(MHndl&(MenuType),1)')
open(path, 'wb').write(data)
