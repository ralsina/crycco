require "./spec_helper"

sample1 = %(
    # This is a comment
    # More comment

    code
    code

    # More comments)

sample2 = %(
    # This is a comment
    # ---
    # More comment
    code
    code

    # More comments)

describe Crycco do
  describe "parse" do
    it "should split code from comments" do
      sections = Crycco.parse sample1, Crycco::LANGUAGES["cr"]
      sections.size.should eq(2)
    end
    it "should remove comment markers from doc" do
      sections = Crycco.parse sample1, Crycco::LANGUAGES["cr"]
      sections[0].docs.should eq("This is a comment\nMore comment\n")
    end
    it "should break sections in HR" do
      sections = Crycco.parse sample2, Crycco::LANGUAGES["cr"]
      sections.size.should eq(3)
    end
  end

  describe "Section" do
    it "should convert docs to html" do
      section = Crycco::Section.new
      section.docs = "This is a comment\nMore comment\n"
      section.docs_html.should eq("<p>This is a comment\nMore comment</p>\n")
    end
    it "should convert code to html" do
      section = Crycco::Section.new
      section.code = "code\ncode\n"
      section.code_html(Crycco::LANGUAGES["cr"]).should eq("<pre><code class=\"crystal\">code\ncode\n</code></pre>")
    end
  end
end
