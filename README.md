# crycco

Crycco is a crystal remix of [Docco](http://jashkenas.github.com/docco/)
a small, nice, literate programming tool.

But the best way to understand it is to see it working. Here is the [Crycco documentation](https://ralsina.me/crycco/) which is ... the Crycco source code processed by Crycco 🤣

## Installation

* Clone the repo
* `shards build`
* Take the `bin/crycco` binary and put it in your path

You don't need any other files or anything.

## Usage

```
$ bin/crycco --help
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
```

It can also be used as a library but not documenting it here just in case
I want to change it soon. I will be integrating it with 
[Nicolino](https://nicolino.ralsina.me) which should give me clarity on how
to use it.

## Development

It's a tiny program, you can understand it in 15 minutes. Go to https://crycco.ralsina.me/ and read the source code.

## Contributing

1. Fork it (<https://github.com/ralsina/crycco/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
