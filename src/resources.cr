require "crustache"

module Crycco
  CSS = <<-CSS
/*--------------------- Layout and Typography ----------------------------*/
p {
  margin: 0 0 15px 0;
}
h1, h2, h3, h4, h5, h6 {
  margin: 40px 0 15px 0;
}
h2, h3, h4, h5, h6 {
    margin-top: 0;
  }
div.docs {
  float: left;
  max-width: 40vw;
  min-width: 40vw;
  min-height: 5px;
  padding: 10px 25px 1px 50px;
  vertical-align: top;
  text-align: left;
}
.docs pre {
    margin: 15px 0 15px;
    padding-left: 15px;
    overflow-y: scroll;
}
.docs p tt, .docs p code {
    padding: 0 0.2em;
}
.octowrap {
  position: relative;
}
.octothorpe {
  font: 12px Arial;
  text-decoration: none;
  color: #454545;
  position: absolute;
  top: 3px; left: -20px;
  padding: 1px 2px;
  opacity: 0;
  -webkit-transition: opacity 0.2s linear;
}
div.docs:hover .octothorpe {
  opacity: 1;
}
div.code {
  margin-left: 40vw;
  padding: 14px 15px 16px 50px;
  vertical-align: top;
}
div.clearall {
    clear: both;
}
CSS

  TEMPLATE = Crustache.parse(<<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="content-type" content="text/html;charset=utf-8">
  <title>{{ title }}</title>
  <link rel="stylesheet" href="{{ stylesheet }}">
    <!-- Pico CSS -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css" />
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.colors.min.css" />
 <!-- highlightks -->
  <link id="hljscss" rel="stylesheet"
    href="https://unpkg.com/@highlightjs/cdn-assets@11.9.0/styles/night-owl.min.css" />
  <script src="https://unpkg.com/@highlightjs/cdn-assets@11.9.0/highlight.min.js"></script>
  <script src="https://unpkg.com/@highlightjs/cdn-assets@11.9.0/languages/crystal.min.js"></script>

  </head>
<body>
<div id='container'>
  <div class='section'>
    <div class='docs'><h1>{{ title }}</h1></div>
  </div>
  <div class='clearall'>
  {{#sections}}
  <div class='section' id='section-{{ num }}'>
    <div class='docs'>
      <div class='octowrap'>
        <a class='octothorpe' href='#section-{{ num }}'>#</a>
      </div>
      {{{ docs_html }}}
    </div>
    <div class='code'>
      {{{ code_html }}}
    </div>
  </div>
  <div class='clearall'></div>
  {{/sections}}
</div>
<script>
hljs.highlightAll();
</script>
</body>
HTML
  )

  # Create the template that we will use to generate the Pycco HTML page.
  def self.render_with_template(args)
    Crustache.render(TEMPLATE, args)
  end
end
