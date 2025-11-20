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
```

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
