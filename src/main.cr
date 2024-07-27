require "docopt"
require "./crycco"

HELP = <<-HELP
Crycco, a Crystal version of docco/pycco/etc.

Usage:
    crycco -V
    crycco SOURCE... [-L <file>][-l <name>][-o <path>][-c <file>][-t <file>]

Options:
  -V, --version           output the version number
  -L, --languages <file>  use a custom languages.yml file
  -l, --layout <name>     choose a layout (parallel, linear or classic) [default: "parallel"]
  -o, --output <path>     output to a given folder [default: "docs"]
  -c, --css <file>        use a custom css file
  -t, --template <file>   use a custom .jst template
  -h, --help              this help message
HELP

options = Docopt.docopt(HELP, ARGV)

Crycco.process(
  options["SOURCE"].as(Array(String)),
  options.fetch("-o", "docs").as(String),
)
