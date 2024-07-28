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
    crycco FILE... [-L <file>][-l <name>][-o <path>][-c <file>]
                     [-t <file>] [--doc|--code]
    crycco -v
    cryco --help

Options:
  -v, --version           output the version number
  -l, --languages <file>  use a custom languages.yml file
  -o, --output <path>     output to a given folder [default: docs/]
  -t, --template <name>   template for doc layout [default: sidebyside]
  --code                  output source code instead of HTML [default: false]
  -h, --help              this help message

Crycco comes with two templates for HTML documents which you can 
use in the -t option when generating docs:

sidebyside (default)
  Shows the docs and code in two columns, matching docs to the code
  they are about.
basic
  Single columns, docs then code, then docs then code.

If you use the --code option, the output will be machine-readable
source code instead of HTML.

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
  sources: options["FILE"].as(Array(String)),
  out_dir: options["--output"].as(String),
  template: options["--template"].as(String),
  as_source: options["--code"] != "false",
)
