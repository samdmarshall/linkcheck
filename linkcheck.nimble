version = "0.1"
author = "Samantha Demi"
description = "website link checker"
license = "BSD 3-Clause"

bin = @["linkcheck"]
srcDir = "src/"

task clean, "clean up from build":
  rmFile("linkcheck")
  withDir("src/"):
    rmDir("nimcache/")

