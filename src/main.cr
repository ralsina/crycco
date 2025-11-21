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
    crycco FILE... [-l <name>][-o <path>][-t <file>][--mode <mode>][--theme <theme>][--ctags <file>]
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
  --ctags <file>          use existing ctags file for symbol resolution
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

# # Shell Completions
#
# Shell completions are a user-friendly feature that allows you to type
# Crycco commands more quickly by pressing Tab to complete options and file names.
# Instead of remembering all the available flags like `--template`, `--theme`,
# or `--output`, you can just type the first few letters and press Tab.
#
# For example, instead of typing:
#   `crycco --template sidebyside --theme phd src/*.cr`
#
# You can type:
#   `crycco --tem[TAB] --th[TAB] phd src/*.cr`
#
# And the shell will automatically complete the options for you.
#
# To enable shell completions, you generate them once and install them in your
# shell's completion directory:
#
# **Bash:** `crycco --completions bash > ~/.local/share/bash-completion/completions/crycco`
# **Fish:** `crycco --completions fish > ~/.config/fish/completions/crycco.fish`
# **ZSH:** `crycco --completions zsh > ~/.zsh/completions/_crycco`
#
# This makes Crycco much more pleasant to use regularly and helps you discover
# available options without constantly consulting the help text.
#
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

# Setup ctags manager with automatic detection
source_files = options["FILE"].as(Array(String)).map { |file_path| Path[file_path] }

if options["--ctags"]?
  # Use existing ctags file
  ctags_path = options["--ctags"].as(String)
  ctags_manager = Crycco::CtagsManager.instance(source_files, ctags_path)
  Crycco.ctags_manager = ctags_manager
else
  # Auto-generate ctags if tools are available
  auto_generate_ctags_if_available(source_files)
end

# Auto-generate ctags if tools are available, otherwise warn
# ameba:disable Metrics/CyclomaticComplexity
def auto_generate_ctags_if_available(source_files : Array(Path))
  # Check if we have any Crystal files (requires crystal-ctags)
  crystal_files = source_files.select { |file| file.extension == ".cr" }
  other_files = source_files.reject { |file| file.extension == ".cr" }

  # Check for required tools
  has_crystal_ctags = system("which crystal-ctags > /dev/null 2>&1")
  has_universal_ctags = system("which ctags > /dev/null 2>&1")

  # Validate tool availability
  if crystal_files.empty? && other_files.empty?
    return # No files to process
  end

  # Check if we have tools for the files we need to process
  needs_crystal_ctags = !crystal_files.empty?
  needs_universal_ctags = !other_files.empty?

  if needs_crystal_ctags && !has_crystal_ctags && needs_universal_ctags && !has_universal_ctags
    STDERR.puts "Warning: Neither crystal-ctags nor universal ctags found. Symbol resolution disabled."
    STDERR.puts "         Install crystal-ctags for Crystal files and/or universal ctags for other languages."
    return
  elsif needs_crystal_ctags && !has_crystal_ctags
    STDERR.puts "Warning: crystal-ctags not found. Crystal symbol resolution disabled."
    STDERR.puts "         Install with: crystal install crystal-ctags"
    crystal_files = [] of Path # Skip Crystal files
  elsif needs_universal_ctags && !has_universal_ctags
    STDERR.puts "Warning: universal ctags not found. Non-Crystal symbol resolution disabled."
    STDERR.puts "         Install with: apt-get install universal-ctags (Ubuntu) or brew install universal-ctags (macOS)"
    other_files = [] of Path # Skip non-Crystal files
  end

  # If we have no tools for any files, return
  if crystal_files.empty? && other_files.empty?
    return
  end

  # Create temporary ctags file
  temp_ctags = File.tempfile("crycco_ctags", ".tags")
  ctags_path = temp_ctags.path

  begin
    # Initialize CtagsManager with temporary file
    ctags_manager = Crycco::CtagsManager.instance(source_files, ctags_path)
    Crycco.ctags_manager = ctags_manager

    # Generate ctags
    if ctags_manager.generate_tags
      puts "🏷️  Auto-generated ctags for symbol resolution"
      puts "   Crystal files: #{crystal_files.size}" unless crystal_files.empty?
      puts "   Other files: #{other_files.size}" unless other_files.empty?
    else
      STDERR.puts "Warning: Failed to auto-generate ctags"
    end
  rescue ex
    STDERR.puts "Error generating ctags: #{ex.message}"
  ensure
    # temp_ctags will be cleaned up automatically when garbage collected
    # but we want to keep it until Crycco finishes processing
    at_exit { File.delete(ctags_path) if File.exists?(ctags_path) }
  end
end

# We create a `Collection` object with the given options
# casted to the right types.
# This will create `Document` objects for each source file
# which are responsible for parsing the source and saving
# the generated output. You can see the `Collection` class
# in [[collection.cr]] and the `Document`
# class in [[crycco.cr#document]].

Crycco::Collection.new(
  sources: options["FILE"].as(Array(String)),
  out_dir: options["--output"].as(String),
  template: options["--template"].as(String),
  mode: options["--mode"].as(String),
  theme: options["--theme"].as(String),
).save
