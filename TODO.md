# TODO

## Things that may need doing

* ✅ Support the literate variants of the languages
* ✅ Support generating code out of literate files
* ✅ Add a page index
* ✅ Add a sidebar
* Autolinks to other pages?
* Other layouts?
* Support other outputs
  * ✅ source code
  * ✅ literate version
  * ✅ markdown
  * nocomments
* Support custom title? Extract title from doc? Use filename?
* Enclosing comments (need them for templates!)
* ✅ Use tartrazine for syntax highlighting
* ✅ Use base16 for themes
* ✅ Fix regression: code blocks in docs are not highlighted because
  highlighjs is gone. Need to use tartrazine for that.
* ✅ Make the basic layout look good
* Fix padding for inline code
* Update tooling, automate releases

## Things I am *not* doing for now

* Allow light/dark switch?

  The problem: because I hardcoded a number of colors, switching via
  Pico doesn't work well. I could switch to using CSS variables, but
  it's boring, so maybe later.
