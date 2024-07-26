module Crycco
  CSS = <<-CSS
/*--------------------- Layout and Typography ----------------------------*/
body {
  font-family: 'Palatino Linotype', 'Book Antiqua', Palatino, FreeSerif, serif;
  font-size: 16px;
  line-height: 24px;
  color: #252519;
  margin: 0; padding: 0;
  background: #f5f5ff;
}
a {
  color: #261a3b;
}
  a:visited {
    color: #261a3b;
  }
p {
  margin: 0 0 15px 0;
}
h1, h2, h3, h4, h5, h6 {
  margin: 40px 0 15px 0;
}
h2, h3, h4, h5, h6 {
    margin-top: 0;
  }
#container {
  background: white;
 }
#container, div.section {
  position: relative;
}
#background {
  position: absolute;
  top: 0; left: 580px; right: 0; bottom: 0;
  background: #f5f5ff;
  border-left: 1px solid #e5e5ee;
  z-index: 0;
}
#jump_to, #jump_page {
  background: white;
  -webkit-box-shadow: 0 0 25px #777; -moz-box-shadow: 0 0 25px #777;
  -webkit-border-bottom-left-radius: 5px; -moz-border-radius-bottomleft: 5px;
  font: 10px Arial;
  text-transform: uppercase;
  cursor: pointer;
  text-align: right;
}
#jump_to, #jump_wrapper {
  position: fixed;
  right: 0; top: 0;
  padding: 5px 10px;
}
  #jump_wrapper {
    padding: 0;
    display: none;
  }
    #jump_to:hover #jump_wrapper {
      display: block;
    }
    #jump_page {
      padding: 5px 0 3px;
      margin: 0 0 25px 25px;
    }
      #jump_page .source {
        display: block;
        padding: 5px 10px;
        text-decoration: none;
        border-top: 1px solid #eee;
      }
        #jump_page .source:hover {
          background: #f5f5ff;
        }
        #jump_page .source:first-child {
        }
div.docs {
  float: left;
  max-width: 500px;
  min-width: 500px;
  min-height: 5px;
  padding: 10px 25px 1px 50px;
  vertical-align: top;
  text-align: left;
}
  .docs pre {
    margin: 15px 0 15px;
    padding-left: 15px;
  }
  .docs p tt, .docs p code {
    background: #f8f8ff;
    border: 1px solid #dedede;
    font-size: 12px;
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
  margin-left: 580px;
  padding: 14px 15px 16px 50px;
  vertical-align: top;
}
  .code pre, .docs p code {
    font-size: 12px;
  }
    pre, tt, code {
      line-height: 18px;
      font-family: Monaco, Consolas, "Lucida Console", monospace;
      margin: 0; padding: 0;
    }
div.clearall {
    clear: both;
}

CSS

  html = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="content-type" content="text/html;charset=utf-8">
  <title>{{ title }}</title>
  <link rel="stylesheet" href="{{ stylesheet }}">
</head>
<body>
<div id='container'>
  <div id="background"></div>
  {{#sources?}}
  <div id="jump_to">
    Jump To &hellip;
    <div id="jump_wrapper">
      <div id="jump_page">
        {{#sources}}
          <a class="source" href="{{ url }}">{{ basename }}</a>
        {{/sources}}
      </div>
    </div>
  </div>
  {{/sources?}}
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
</body>
HTML

  def self.template(source)
    # FIXME: implement template
    # return lambda context: pystache.render(source, context)
    "FOO"
  end

  # Create the template that we will use to generate the Pycco HTML page.
  def self.render_with_template(args)
    "FOO"
  end
end
