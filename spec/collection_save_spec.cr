require "./spec_helper"

Crycco.load_languages("#{__DIR__}/../src/languages.yml")

# Specs for rendering whole collections to disk in all output modes,
# and for the HTML templates. See issue #7.

SPEC_OUT = "/tmp/opencode/crycco-spec-out"

def fixture_path(name : String) : String
  (Path[__DIR__] / "fixtures" / name).expand.to_s
end

def render_collection(mode : String, template : String = "sidebyside")
  # The paths must be absolute because Collection expands and normalizes
  # them and uses the common prefix as the base directory.
  collection = Crycco::Collection.new(
    sources: [fixture_path("1.cr"), fixture_path("2.cr"),
              fixture_path("enclosing.c"), fixture_path("empty.cr")],
    out_dir: SPEC_OUT,
    template: template,
    mode: mode
  )
  collection.save
  collection
end

describe "Collection.save" do
  after_each do
    FileUtils.rm_rf(SPEC_OUT)
  end

  it "should render HTML docs for every source in docs mode" do
    render_collection("docs")
    outdir = Path[SPEC_OUT]
    File.exists?(outdir / "1.cr.html").should be_true
    File.exists?(outdir / "2.cr.html").should be_true
    File.exists?(outdir / "enclosing.c.html").should be_true
    File.exists?(outdir / "empty.cr.html").should be_true
  end

  it "should include title, docs, highlighted code and links in the HTML" do
    render_collection("docs")
    html = File.read(Path[SPEC_OUT] / "1.cr.html")

    html.should contain("<title>1.cr</title>")
    html.should contain("This is a comment")
    # Code went through the syntax highlighter
    html.should contain("<span")
    # The footer identifies the layout
    html.should contain("sidebyside")
    # Sidebar links to the other documents, self link is not a link
    html.should contain(%(href="2.cr.html"))
    html.should contain("<span>1.cr</span>")
    # Comments became markdown paragraphs
    html.should contain("<p>")
  end

  it "should use the basic template when asked" do
    render_collection("docs", template: "basic")
    html = File.read(Path[SPEC_OUT] / "1.cr.html")

    html.should contain("basic")
    html.should_not contain(%(class="grid"))
    html.should contain("This is a comment")
  end

  it "should keep enclosing comments as docs in the rendered HTML" do
    render_collection("docs")
    html = File.read(Path[SPEC_OUT] / "enclosing.c.html")
    html.should contain("comment")
    html.should contain("more comment")
    # The code is syntax highlighted, so tokens are wrapped in spans
    html.should contain(">foo</span>")
    html.should contain(">bar</span>")
  end

  it "should render an empty document without sections" do
    render_collection("docs")
    html = File.read(Path[SPEC_OUT] / "empty.cr.html")
    html.should contain("<title>empty.cr</title>")
  end

  it "should generate source files in code mode" do
    render_collection("code")
    outdir = Path[SPEC_OUT]
    File.exists?(outdir / "1.cr").should be_true
    File.exists?(outdir / "enclosing.c").should be_true

    source = File.read(outdir / "1.cr")
    source.should contain("# This is a comment")
    source.should contain("code")
    # No HTML in source mode
    source.should_not contain("<")
  end

  it "should generate markdown with fenced code blocks in markdown mode" do
    render_collection("markdown")
    md_path = Path[SPEC_OUT] / "1.md"
    File.exists?(md_path).should be_true

    markdown = File.read(md_path)
    markdown.should contain("This is a comment")
    markdown.should contain("```crystal")
    markdown.should contain("code")
  end

  it "should generate literate markdown with indented code in literate mode" do
    render_collection("literate")
    md_path = Path[SPEC_OUT] / "1.cr.md"
    File.exists?(md_path).should be_true

    literate = File.read(md_path)
    literate.should contain("This is a comment")
    literate.should contain("    code")
  end

  it "should round-trip a literate source to code mode without the .md suffix" do
    collection = Crycco::Collection.new(
      sources: [fixture_path("1.cr.md")],
      out_dir: SPEC_OUT,
      template: "sidebyside",
      mode: "code"
    )
    collection.save
    out_path = Path[SPEC_OUT] / "1.cr"
    File.exists?(out_path).should be_true

    source = File.read(out_path)
    # The markdown docs got their comment markers back
    source.should contain("# This is a comment")
    source.should contain("code")
  end
end
