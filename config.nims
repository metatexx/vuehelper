# the extension name
var extensionName = "vuehelper"

# include the configuration template
include "cfgtpl.nims"

# our tests
task tests, "runs a simple test":
  setCommand "nop"
  exec phpExe & """ test1.php"""
