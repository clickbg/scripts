#!/usr/bin/env python
# Quite often when installing third party software on Solaris you first need to check that the system meets a minimum required patch level.
# I was in this situation recently and found myself manually grepping each patch id out of a showrev -p output which quickly made me feel like a complete monkey.
# I wrote this script to save myself a little time. Before running it you need two input files:
# patches.lst - The patches required by the software, one per line like this:
# 118816-13
# 120901-03
# 121334-04
# 119255-42
# 119318-01
# showrev.lst - The patches presently on the system. Produced by running `showrev -p > showrev.lst` on the target solaris system, looks like this:
# Patch: 119575-02 Obsoletes: 119268-01 Requires:  Incompatibles:  Packages: SUNWcsu
# Patch: 120045-01 Obsoletes:  Requires:  Incompatibles:  Packages: SUNWcsu
# Patch: 120063-01 Obsoletes:  Requires:  Incompatibles:  Packages: SUNWcsu, SUNWloc
# Patch: 120817-01 Obsoletes:  Requires:  Incompatibles:  Packages: SUNWcsu, SUNWesu, SUNWxcu4
# Read in required patch, split into version and revision
for patch in open("patches.lst"):
        patch = patch.rstrip()
        patchversion = patch[0:6]
        patchrevision = patch[7:9]
        # For each patch version search for the highest revision present on the system
        highest_present = 0
        for line in open("showrev.lst"):
                if patchversion in line:
                        cutstart = line.find(patchversion)
                        cutend = cutstart + 9
                        patchpresent = line[cutstart:cutend]
                        patchpresent_revision = patchpresent[7:9]
                        if int(patchpresent_revision) > int(highest_present):
                                highest_present = patchpresent_revision
        # When finished searching print out the result
        else:
                if int(highest_present) == int(patchrevision):
                        print patch + " Exact patch present"
                elif int(highest_present) > int(patchrevision):
                        print patch + " Newer patch present"
                elif int(highest_present) < int(patchrevision):
                        print patch + " Patch MISSING"
