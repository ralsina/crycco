require "docopt"
require "./crycco"

HELP = <<-HELP
Crycco, a Crystal version of docco/pycco/etc.

Usage:
    crycco -V
    crycco SOURCE... [-L <file>][-l <name>][-o <path>][-c <file>][-t <file>]

Options:
  -V, --version           output the version number
  -l, --languages <file>  use a custom languages.yml file
  -o, --output <path>     output to a given folder [default: "docs"]
  -t, --template <name>   template for layout (sidebyside, basic or a filename)
  -h, --help              this help message
HELP

options = Docopt.docopt(HELP, ARGV)

if options["--version"]
  puts "Crycco #{Crycco::VERSION}"
  exit 0
end

Crycco.process(
  sources: options["SOURCE"].as(Array(String)),
  out_dir: options.fetch("--output", "docs").as(String),
  template: options.fetch("--template", "sidebyside").as(String),
)
