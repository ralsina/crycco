# # main.cr
#
# This is the entrypoint to use Crycco as a command line tool.
# As you can see by the dependencies, we are using `docopt` to
# parse the command line arguments.
#
# It parses the arguments based on the actual help message. For
# more information you can visit [docopt.org](https://docopt.org/).

require "docopt"
require "./collection"

# Crycco is not a very complicated tool, really, so the options are
# few and simple.

HELP = <<-HELP
Crycco, a Crystal version of docco/pycco/etc.

Usage:
    crycco FILE... [-l <name>][-o <path>][-t <file>][--mode <mode>][--theme <theme>]
    crycco -v
    cryco --help

Options:
  -v, --version           output the version number
  -l, --languages <file>  use a custom languages.yml file
  -o, --output <path>     output to a given folder [default: docs/]
  -t, --template <name>   template for doc layout [default: sidebyside]
  --mode <mode>           what to output [default: docs]
  --theme <theme>         theme for the output [default: default-dark]
  -h, --help              this help message

The available modes are:

* docs (default)
  Generates HTML documentation.
* code
  Generates source code with comments
* markdown
  Generates markdown files with the code in fenced code blocks
* literate
  Generates markdown files with the code in indented blocks

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

# We create a `Collection` object with the given options
# casted to the right types.
# This will create `Document` objects for each source file
# which are responsible for parsing the source and saving
# the generated output. You can see the `Collection` class
# in [collection.cr](collection.cr.html) and the `Document`
# class in [crycco.cr](crycco.cr.html#document).

Crycco::Collection.new(
  sources: options["FILE"].as(Array(String)),
  out_dir: options["--output"].as(String),
  template: options["--template"].as(String),
  mode: options["--mode"].as(String),
  theme: options["--theme"].as(String),
).save
