# crycco

Crycco is a crystal remix of [Docco](http://jashkenas.github.com/docco/)
a small, nice, literate programming tool.

But the best way to understand it is to see it working. Here is the
[Crycco documentation](https://ralsina.me/crycco/) which is ... the
Crycco source code processed by Crycco 🤣

## Installation

* Clone the repo
* `shards build`
* Take the `bin/crycco` binary and put it in your path

You don't need any other files or anything.

## Usage

```docopt
$ bin/crycco --help
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
```

## Smart File and Symbol References

Crycco supports intelligent file and symbol references in documentation comments using double square brackets syntax:

### Basic Syntax
- `[[filename]]` → Links to `filename.html` (file reference)
- `[[SymbolName]]` → Links to symbol definition at line number (symbol reference)
- `[[filename|custom text]]` → Links with custom display text
- `[[path/to/file]]` → Relative path references

### Smart File Matching
When you reference a file without extension, Crycco intelligently matches against all files being processed:

```crystal
# Exact filename match
[[main.cr]] → main.cr.html

# Basename match without extension
[[src/main]] → src/main.cr.html

# Unique matches in same directory are prioritized
[[collection]] → src/collection.cr.html (if unique)
```

### Symbol Resolution with Ctags
When a reference doesn't match any files, Crycco can resolve it as a symbol using ctags:

```crystal
# Links to class definition
[[MyClass]] → src/myclass.cr.html#line-15

# Links to method definition
[[process_data]] → src/processor.cr.html#line-42

# Links to function in current file (priority)
[[helper_function]] → current_file.html#line-8
```

### Automatic Symbol Resolution
Crycco automatically detects and uses ctags tools for symbol resolution when available. No special flags needed!

```bash
# Just run crycco normally - symbol resolution works automatically
crycco src/**/*.cr src/**/*.py

# Use existing ctags file if you have one
crycco --ctags existing_tags src/*.cr
```

#### How It Works
When you run Crycco, it automatically:

1. **Detects available tools**:
   - **crystal-ctags** for `.cr` files
   - **universal ctags** for other languages (.py, .js, .ts, .rb, .go, etc.)

2. **Generates ctags** if tools are found
3. **Gracefully degrades** if tools are missing (shows helpful warnings)

#### Installation (Optional)
For the best experience, install the appropriate ctags tools:

```bash
# For Crystal files
crystal install crystal-ctags

# For other files (Ubuntu/Debian)
sudo apt-get install universal-ctags

# For other files (macOS)
brew install universal-ctags
```

**Note**: Crycco works perfectly without ctags - you just won't get symbol resolution.

### Resolution Priority
1. **File references** (exact and basename matches)
2. **Symbols in current file** (highest priority)
3. **Unique symbols across all files**
4. **Unresolved references** left unchanged

### Error Handling
- **Ambiguous references**: Left unchanged (no automatic resolution)
- **Missing files/symbols**: Left unchanged with warnings
- **External files**: Require explicit paths

### Example
```crystal
# File: src/main.cr
# This file handles CLI arguments. See [[Collection]] for details.
# The [[process_args]] method validates input parameters.
# Check [[README|project documentation]] for more information.
```

### Line Number Anchors
Symbol links create line-number anchors in the generated HTML, enabling precise navigation to symbol definitions:
- `[[ClassName]]` → `src/classname.cr.html#line-25`
- Links jump directly to the line where the symbol is defined
- Works with classes, methods, functions, and other language constructs

This makes cross-referencing between files and symbols much easier while maintaining link validity when code is reorganized.

## Configuration

Crycco supports configuration through a `.crycco.yml` file and environment variables, providing flexible ways to set default options without typing them on the command line every time.

### Configuration File

Create a `.crycco.yml` file in your project directory to set default options:

```yaml
# .crycco.yml
output: docs/              # --output <path>
template: sidebyside       # --template <name>
theme: default-dark        # --theme <theme>
mode: docs                # --mode <mode>
languages: custom-langs.yml  # --languages <file>
```

The configuration file is automatically picked up from the current directory or parent directories.

### Environment Variables

You can also configure Crycco using environment variables with the `CRYCCO_` prefix:

```bash
export CRYCCO_OUTPUT="documentation/"
export CRYCCO_TEMPLATE="basic"
export CRYCCO_THEME="default-dark"
export CRYCCO_MODE="docs"
export CRYCCO_LANGUAGES="custom-langs.yml"
```

### Precedence

Crycco follows this precedence order (highest to lowest):
1. **Command line arguments** (always override everything)
2. **Environment variables** (override config file)
3. **Configuration file** (provides defaults)
4. **Built-in defaults** (used when nothing else is specified)

### Examples

```bash
# Use only config file settings
crycco src/*.cr

# Override just the output directory, keep other config file settings
crycco --output special-docs/ src/*.cr

# Use environment variables for CI/CD
export CRYCCO_OUTPUT="docs/"
export CRYCCO_TEMPLATE="basic"
crycco src/*.cr
```

## Shell Completions

Crycco provides intelligent shell completions for Bash, Fish, and ZSH to make typing commands faster and more convenient.

### Installation

**Bash:**
```bash
crycco --completions bash > ~/.local/share/bash-completion/completions/crycco
source ~/.bashrc
```

**Fish:**
```bash
crycco --completions fish > ~/.config/fish/completions/crycco.fish
```

**ZSH:**
```bash
crycco --completions zsh > ~/.zsh/completions/_crycco
# Add to ~/.zshrc: fpath=($HOME/.zsh/completions $fpath)
```

### Features

- Tab-complete all options (`--theme`, `--template`, `--mode`, etc.)
- File completion for source files and directories
- Built-in option descriptions

---

It can also be used as a library but not documenting it here just in case
I want to change it soon. I will be integrating it with
[Nicolino](https://nicolino.ralsina.me) which should give me clarity on how
to use it.

## Development

It's a tiny program, you can understand it in 15 minutes. Go to
<https://crycco.ralsina.me/> and read the source code.

## Contributing

1. Fork it (<https://github.com/ralsina/crycco/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
