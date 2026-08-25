require "./spec_helper"

Crycco.load_languages("#{__DIR__}/../src/languages.yml")

# Specs for pure markdown documents (like a README.md) being part of a
# documentation set: parsed verbatim, rendered as prose instead of the
# side-by-side layout, and passed through untouched in other modes.

SPEC_MD_OUT = "/tmp/opencode/crycco-spec-md-out"

def md_fixture_path(name : String) : String
  (Path[__DIR__] / "fixtures" / name).expand.to_s
end

describe "Pure markdown documents" do
  after_each do
    FileUtils.rm_rf(SPEC_MD_OUT)
  end

  it "should keep the whole file as one verbatim docs section" do
    document = Crycco::Document.new Path[md_fixture_path("prose.md")]

    document.sections.size.should eq(1)
    document.sections[0].docs.should eq(File.read(md_fixture_path("prose.md")))
    document.sections[0].code.should eq("")
  end

  it "should not strip indentation from nested lists and code blocks" do
    document = Crycco::Document.new Path[md_fixture_path("prose.md")]
    docs = document.sections[0].docs

    # These lines must survive with their exact leading whitespace
    docs.should contain("  * nested item\n")
    docs.should contain("    indented code\n")
  end

  it "should use the first header as the section anchor" do
    document = Crycco::Document.new Path[md_fixture_path("prose.md")]
    document.sections[0].anchor.should eq("prose-fixture")
  end

  it "should render prose, not the side-by-side layout" do
    collection = Crycco::Collection.new(
      sources: [md_fixture_path("prose.md")],
      out_dir: SPEC_MD_OUT,
      template: "sidebyside",
      mode: "docs"
    )
    collection.save

    html = File.read(Path[SPEC_MD_OUT] / "prose.md.html")
    html.should contain(%(<article class="prose"))
    html.should contain("markdown-page")
    html.should_not contain(%(class="grid"))
    # The content itself is there, as markdown-rendered HTML
    html.should contain("<h1")
    html.should contain("nested item")
  end

  it "should highlight fenced code blocks inside the markdown" do
    collection = Crycco::Collection.new(
      sources: [md_fixture_path("prose.md")],
      out_dir: SPEC_MD_OUT,
      template: "sidebyside",
      mode: "docs"
    )
    collection.save

    html = File.read(Path[SPEC_MD_OUT] / "prose.md.html")
    # The crystal block went through the syntax highlighter
    html.should contain("<span")
    html.should contain(">puts</span>")
  end

  it "should pass through verbatim in code, markdown and literate modes" do
    original = File.read(md_fixture_path("prose.md"))

    ["code", "markdown", "literate"].each do |mode|
      FileUtils.rm_rf(SPEC_MD_OUT)
      collection = Crycco::Collection.new(
        sources: [md_fixture_path("prose.md")],
        out_dir: SPEC_MD_OUT,
        template: "sidebyside",
        mode: mode
      )
      collection.save

      out_file = Path[SPEC_MD_OUT] / "prose.md"
      File.exists?(out_file).should be_true
      File.read(out_file).should eq(original)
    end
  end

  it "should resolve smart references from the markdown" do
    one = Path[md_fixture_path("prose.md")]
    Crycco.all_files = [one, Path[md_fixture_path("1.cr")]]
    Crycco.base_dir = Path[one.dirname]

    document = Crycco::Document.new one
    document.sections[0].docs = "See [[1.cr]] for the code."

    document.sections[0].docs_html.should contain(%(href="1.cr.html"))
  ensure
    Crycco.all_files = [] of Path
    Crycco.base_dir = Path["."]
  end
end
