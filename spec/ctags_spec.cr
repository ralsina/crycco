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

# Creates a unique temporary directory (Crystal has no Dir.mkdtemp)
def temp_dir(prefix : String) : Path
  path = Path[File.tempname(prefix, ".dir")]
  Dir.mkdir(path)
  path
end

# Puts a fake executable named `name` first on PATH for the duration of
# the block. Used to exercise the tag generation code paths without
# depending on real ctags tools. See issue #4.
def with_fake_tool(name : String, script_body : String, &)
  bin_dir = temp_dir("crycco-fakebin")
  script = Path[bin_dir] / name
  File.write(script, script_body)
  File.chmod(script.to_s, File::Permissions.new(0o755))
  original_path = ENV["PATH"]
  ENV["PATH"] = "#{bin_dir}:#{original_path}"
  yield
ensure
  ENV["PATH"] = original_path if original_path
  FileUtils.rm_rf(bin_dir.to_s)
end

# Creates a scratch directory with files whose names are hostile to
# shell-based command construction, and removes it afterwards. If shell
# injection ever happens, the injected `touch PWNED` would create a
# marker in the current directory, which is also cleaned up.
def with_hostile_files(&)
  workdir = temp_dir("crycco-hostile")
  yield workdir
ensure
  FileUtils.rm_rf(workdir.to_s)
  File.delete("PWNED") if File.exists?("PWNED")
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

  describe "generate_tags" do
    it "should pass hostile filenames as single arguments without a shell" do
      with_hostile_files do |workdir|
        space_file = workdir / "space name.cr"
        inject_file = workdir / "evil$(touch PWNED).cr"
        File.write(space_file, "class FakeSymbol\nend\n")
        File.write(inject_file, "class FakeSymbol\nend\n")

        tags_path = File.tempname("crycco", ".tags")
        args_path = File.tempname("crycco", ".args")
        fake_tool = <<-'SCRIPT'
          #!/bin/sh
          printf '%s\n' "$@" > ARGS_PATH
          printf 'FakeSymbol\t%s\t/^class FakeSymbol$/;"\tline:1\tkind:c\n' 'SYMBOL_FILE'
          SCRIPT
          .gsub("ARGS_PATH", args_path)
          .gsub("SYMBOL_FILE", space_file.to_s)

        with_fake_tool("crystal-ctags", fake_tool) do
          manager = Crycco::CtagsManager.new([space_file, inject_file], tags_path)
          manager.generate_tags.should be_true
        end

        # Each filename arrived as exactly one argument, un-mangled
        File.read(args_path).lines.should eq(
          [space_file.to_s, inject_file.to_s])

        # The command substitution in the filename was NOT executed
        File.exists?("PWNED").should be_false

        # The tool's stdout became the tags file and is usable
        File.read(tags_path).should contain("FakeSymbol")
        manager = Crycco::CtagsManager.new([space_file, inject_file], tags_path)
        manager.resolve_symbol("FakeSymbol", space_file).should eq({space_file, 1})
      end
    end

    it "should pass -f and filenames safely to universal ctags" do
      with_hostile_files do |workdir|
        yml_file = workdir / "weird config.yml"
        File.write(yml_file, "# config\n")

        tags_path = File.tempname("crycco", ".tags")
        fake_tool = <<-'SCRIPT'
          #!/bin/sh
          # Invoked as: ctags -f TAGSFILE FILE...
          printf 'OtherSymbol\t%s\t/^def other$/;"\tline:2\tkind:f\n' "$3" > "$2"
          SCRIPT

        with_fake_tool("ctags", fake_tool) do
          manager = Crycco::CtagsManager.new([yml_file], tags_path)
          manager.generate_tags.should be_true
        end

        File.read(tags_path).should contain("OtherSymbol")
        manager = Crycco::CtagsManager.new([yml_file], tags_path)
        manager.resolve_symbol("OtherSymbol", yml_file).should eq({yml_file, 2})
      end
    end

    it "should return false when the tool is not available" do
      with_hostile_files do |workdir|
        source = workdir / "missing_tool.cr"
        File.write(source, "class Nothing\nend\n")

        empty_bin = temp_dir("crycco-emptybin")
        begin
          original_path = ENV["PATH"]
          ENV["PATH"] = empty_bin.to_s
          manager = Crycco::CtagsManager.new([source], File.tempname("crycco", ".tags"))
          manager.generate_tags.should be_false
        ensure
          ENV["PATH"] = original_path
          FileUtils.rm_rf(empty_bin.to_s)
        end
      end
    end
  end

  # Issue #3 (duplicate section anchors) is covered in crycco_spec.cr
  # by the anchor uniqueness specs.
end
