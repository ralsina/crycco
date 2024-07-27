require "./spec_helper"

sample1 = %(
    # This is a comment
    # More comment

    code
    code

    # More comments)

describe Crycco do
  it "should split code from comments" do
    sections = Crycco.parse sample1, Crycco::LANGUAGES[".cr"]
    sections.size.should eq(2)
  end

  it "should remove comment markers from doc" do
    sections = Crycco.parse sample1, Crycco::LANGUAGES[".cr"]
    Crycco.highlight(sections, Crycco::LANGUAGES[".cr"], outdir: "tmp")
    sections[0]["docs_text"].should eq("This is a comment\nMore comment")
  end

  it "should wrap code in pre tags" do
    sections = Crycco.parse sample1, Crycco::LANGUAGES[".cr"]
    Crycco.highlight(sections, Crycco::LANGUAGES[".cr"], outdir: "tmp")
    sections[0]["code_html"].should start_with("<pre><code class=\"language-crystal")
  end

  it "should replace heading with markdown headings" do
    result = Crycco.preprocess("=== foo === ")
    result.should eq %(### <span id="foo" href="foo"> foo </span>)
  end
end
