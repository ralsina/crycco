require "./spec_helper"

Crycco.load_languages("#{__DIR__}/../src/languages.yml")

# Specs for the ctags-based symbol resolution. The tags file is generated
# at runtime with absolute fixture paths so the specs don't depend on
# external tools. See issue #7.

def fixture_tags_path(name : String) : String
  (Path[__DIR__] / "fixtures" / name).expand.to_s
end

def write_tags_file(path : String) : String
  one = fixture_tags_path("1.cr")
  two = fixture_tags_path("2.cr")
  empty = fixture_tags_path("empty.cr")
  lines = [
    # Current-file symbol
    "Frobnicator\t#{one}\t/^class Frobnicator$/;\"\tline:3\tkind:c",
    # Unique symbol in another file
    "UniqueHelper\t#{two}\t/^def unique_helper$/;\"\tline:5\tkind:f",
    # Ambiguous: same name in two files, neither of them the current one
    "Ambiguous\t#{two}\t/^class Ambiguous$/;\"\tline:7\tkind:c",
    "Ambiguous\t#{empty}\t/^def ambiguous$/;\"\tline:9\tkind:f",
  ]
  File.write(path, lines.join("\n"))
  path
end

def setup_ctags_context
  one = Path[fixture_tags_path("1.cr")]
  Crycco.all_files = [one]
  Crycco.base_dir = Path[one.dirname]
  tags = write_tags_file(File.tempname("crycco", ".tags"))
  Crycco.ctags_manager = Crycco::CtagsManager.new([one], tags)
  one
end

describe Crycco::CtagsManager do
  after_each do
    Crycco.ctags_manager = nil
    Crycco::CtagsManager.reset
    Crycco.all_files = [] of Path
    Crycco.base_dir = Path["."]
  end

  it "should resolve a symbol defined in the current file" do
    one = Path[fixture_tags_path("1.cr")]
    two = Path[fixture_tags_path("2.cr")]
    tags = write_tags_file(File.tempname("crycco", ".tags"))
    manager = Crycco::CtagsManager.new([one, two], tags)

    manager.resolve_symbol("Frobnicator", one).should eq({one, 3})
  end

  it "should resolve a unique symbol defined in another file" do
    one = Path[fixture_tags_path("1.cr")]
    two = Path[fixture_tags_path("2.cr")]
    tags = write_tags_file(File.tempname("crycco", ".tags"))
    manager = Crycco::CtagsManager.new([one, two], tags)

    manager.resolve_symbol("UniqueHelper", one).should eq({two, 5})
  end

  it "should not resolve ambiguous symbols" do
    one = Path[fixture_tags_path("1.cr")]
    two = Path[fixture_tags_path("2.cr")]
    tags = write_tags_file(File.tempname("crycco", ".tags"))
    manager = Crycco::CtagsManager.new([one, two], tags)

    manager.resolve_symbol("Ambiguous", one).should be_nil
  end

  it "should not resolve unknown symbols" do
    one = Path[fixture_tags_path("1.cr")]
    tags = write_tags_file(File.tempname("crycco", ".tags"))
    manager = Crycco::CtagsManager.new([one], tags)

    manager.resolve_symbol("NoSuchSymbol", one).should be_nil
  end

  it "should degrade gracefully when the tags file does not exist" do
    one = Path[fixture_tags_path("1.cr")]
    missing = File.tempname("crycco", ".tags")
    manager = Crycco::CtagsManager.new([one], missing)

    manager.resolve_symbol("Frobnicator", one).should be_nil
  end

  it "should turn symbol references into line links via Sections" do
    one = setup_ctags_context

    section = Crycco::Section.new Crycco::LANGUAGES[".cr"], one
    section.docs = "See [[Frobnicator]] for details."

    result = section.process_file_references(section.docs)
    result.should contain("[Frobnicator](1.cr.html#line-3)")
  end

  it "should leave unknown symbol references unchanged" do
    one = setup_ctags_context

    section = Crycco::Section.new Crycco::LANGUAGES[".cr"], one
    section.docs = "See [[NoSuchSymbol]] for details."

    result = section.process_file_references(section.docs)
    result.should contain("[[NoSuchSymbol]]")
  end

  # Regression specs for open bugs. They assert the *expected* behavior
  # so the fix for each issue turns them regular (remove the `pending`).

  # Issue #2: symbol links use absolute file line numbers, but the
  # generated anchors restart per section, so the targets don't exist.
  pending "symbol link targets should exist in the rendered HTML (issue #2)" do
    one = setup_ctags_context

    section = Crycco::Section.new Crycco::LANGUAGES[".cr"], one
    section.docs = "See [[Frobnicator]] for details."
    match_data = section.process_file_references(section.docs)
      .match(/\]\((.*?)\)/)

    match_data.should_not be_nil
    link_target = match_data ? match_data[1] : ""
    anchor = link_target.split("#")[1]?
    anchor.should_not be_nil
    section.code_html.should contain(%(id="#{anchor}"))
  end

  # Issue #3: sections without headers all share the "section" fallback
  # anchor, producing duplicated ids in the generated HTML.
  pending "section anchors should be unique (issue #3)" do
    document = Crycco::Document.new Path[fixture_tags_path("2.cr")]
    anchors = document.sections.map &.anchor
    anchors.size.should eq(anchors.uniq.size)
  end
end
