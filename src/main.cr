# # main.cr
#
# This is the entrypoint to use Crycco as a command line tool.
# As you can see by the dependencies, we are using `docopt` to
# parse the command line arguments.
#
# It parses the arguments based on the actual help message. For
# more information you can visit [docopt.org](https://docopt.org/).

require "docopt-config"
require "./collection"
require "sixteen"

# Crycco is not a very complicated tool, really, so the options are
# few and simple.

HELP = <<-HELP
Crycco, a Crystal version of docco/pycco/etc.

Usage:
    crycco FILE... [-l <name>][-o <path>][-t <file>][--mode <mode>][--theme <theme>]
    crycco --version
    crycco --help
    crycco --completions <shell>

Options:
  -v, --version           output the version number
  -l, --languages <file>  use a custom languages.yml file
  -o, --output <path>     output to a given folder [default: docs/]
  -t, --template <name>   template for doc layout [default: sidebyside]
  --mode <mode>           what to output [default: docs]
  --theme <theme>         theme for the output [default: default-dark]
  --completions <shell>   generate shell completions (bash, fish, zsh)
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

options = Docopt.docopt_config(HELP,
  config_file_path: ".crycco.yml",
  env_prefix: "CRYCCO"
)

# Handle version manually
if options["--version"]
  puts "Crycco #{Crycco::VERSION}"
  exit 0
end

# Handle shell completions
if shell = options["--completions"]?
  shell = shell.as(String)

  # Get dynamic theme list using Sixteen
  themes = Sixteen::DataFiles.files.map do |file|
    File.basename(file.path, ".yaml")
  end.sort!

  # Create completion options (including self-completion for --completions)
  # Note: custom_completions expects Hash(String, String), not Hash(String, Array)
  # Option completions use option names directly ("--theme"), arguments use "commandname_optionname"
  completions = {
    "crycco_completions" => "bash fish zsh",
    "--theme"            => themes.join(" "),
    "--template"         => "sidebyside basic",
    "-t"                 => "sidebyside basic",
    "--mode"             => "docs code markdown literate",
    "-m"                 => "docs code markdown literate",
    "--languages"        => "*.yml *.yaml",
    "-l"                 => "*.yml *.yaml",
    "--output"           => "*", # Directories
    "-o"                 => "*", # Directories
    "FILE"               => "*.cr *.py *.js *.ts *.rb *.go *.java *.c *.cpp *.h *.hpp *.rs *.php *.swift *.kt *.scala *.clj *.hs *.ml *.sh *.bash *.zsh *.fish *.ps1 *.bat *.cmd */",
  }

  case shell.downcase
  when "bash"
    puts Docopt.bash_completion("crycco", HELP, completions)
  when "fish"
    puts Docopt.fish_completion("crycco", HELP, completions)
  when "zsh"
    puts Docopt.zsh_completion("crycco", HELP, completions)
  else
    STDERR.puts "Error: Unsupported shell '#{shell}'. Supported shells: bash, fish, zsh"
    exit 1
  end
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
