# # main.cr
#
# This is the entrypoint to use Crycco as a command line tool.
# As you can see by the dependencies, we are using `docopt` to
# parse the command line arguments.
#
# It parses the arguments based on the actual help message. For
# more information you can visit [docopt.org](https://docopt.org/).

require "docopt"
require "./crycco"

# Crycco is not a very complicated tool, really, so the options are
# few and simple.

HELP = <<-HELP
Crycco, a Crystal version of docco/pycco/etc.

Usage:
    crycco SOURCE... [-L <file>][-l <name>][-o <path>][-c <file>][-t <file>]
    crycco -v
    cryco --help

Options:
  -v, --version           output the version number
  -l, --languages <file>  use a custom languages.yml file
  -o, --output <path>     output to a given folder [default: docs/]
  -t, --template <name>   template for layout [default: sidebyside]
  -h, --help              this help message

  Crycco comes with two templates by default: sidebyside and basic.
HELP

options = Docopt.docopt(HELP, ARGV)

# Handle version manually
if options["--version"]
  puts "Crycco #{Crycco::VERSION}"
  exit 0
end

# First we initialize the languages list from the given file or
# whatever is the default.

Crycco.load_languages(options["--languages"].try &.as(String))

# And here, we call `Crycco.process` with the options we got, casted to
# the types it expects. If there is an error, we can just crash with
# an exception and a backtrace. The interesting code is in [crycco.cr](./crycco.cr.html#section-2).

Crycco.process(
  sources: options["SOURCE"].as(Array(String)),
  out_dir: options["--output"].as(String),
  template: options["--template"].as(String),
)
