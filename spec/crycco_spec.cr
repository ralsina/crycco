require "./spec_helper"

Crycco.load_languages("#{__DIR__}/../languages.yml")

describe Crycco do
  describe "parse" do
    it "should split code from comments" do
      doc = Crycco::Document.new "#{__DIR__}/fixtures/1.cr"
      doc.sections.size.should eq(2)
    end
    it "should remove comment markers from doc" do
      doc = Crycco::Document.new "#{__DIR__}/fixtures/1.cr"
      doc.sections[0].docs.should eq("This is a comment\nMore comment\n")
    end
    it "should break sections in HR" do
      doc = Crycco::Document.new "#{__DIR__}/fixtures/2.cr"
      doc.sections.size.should eq(3)
    end
    it "should split code from comments in literate style" do
      doc = Crycco::Document.new "#{__DIR__}/fixtures/1.cr.md"
      doc.sections.size.should eq(2)
    end
  end

  describe "Section" do
    it "should convert docs to html" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"]
      section.docs = "This is a comment\nMore comment\n"
      section.docs_html.should eq("<p>This is a comment\nMore comment</p>\n")
    end
    it "should convert code to html" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"]
      section.code = "code\ncode\n"
      section.code_html.strip.should eq("<pre class=\"code\"><code class=\"crystal\">code\ncode\n</code></pre>")
    end
  end
end
