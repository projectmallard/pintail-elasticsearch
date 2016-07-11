<?xml version='1.0' encoding='UTF-8'?><!-- -*- indent-tabs-mode: nil -*- -->
<!--
This program is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
details.

You should have received a copy of the GNU Lesser General Public License
along with this program; see the file COPYING.LGPL.  If not, write to the
Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
02111-1307, USA.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:mal="http://projectmallard.org/1.0/"
                xmlns:str="http://exslt.org/strings"
                xmlns:exsl="http://exslt.org/common"
                xmlns:pintail="http://pintail.io/"
                xmlns="http://www.w3.org/1999/xhtml"
                extension-element-prefixes="exsl"
                exclude-result-prefixes="mal str exsl pintail"
                version="1.0">

<xsl:param name="pintail.elasticsearch.host"/>
<xsl:param name="pintail.elasticsearch.epoch"/>
<xsl:param name="pintail.elasticsearch.index"/>
<xsl:param name="pintail.search.domains"/>

<xsl:template name="pintail.elasticsearch.css">
<xsl:text>
div.search {
  text-align: right;
}
div.search input {
  margin: 10px;
  padding: 4px;
  text-align: left;
  border-radius: 4px;
  border: solid 1px </xsl:text><xsl:value-of select="$color.gray"/><xsl:text>;
}
div.search input:focus {
  border: solid 1px </xsl:text><xsl:value-of select="$color.blue"/><xsl:text>;
  box-shadow: 0 0 2px </xsl:text><xsl:value-of select="$color.blue"/><xsl:text>;
}
#es_search_domain {
  margin: 0 0 10px 0;
  padding: 4px 2px;
}
#es_search label {
  margin: 0 4px;
  color: </xsl:text><xsl:value-of select="$color.fg.gray"/><xsl:text>;
}
#es_search_field {
  margin: 0 0 10px 0;
  padding: 4px 8px;
  font-size: 1.2em;
  width: 75%;
  text-align: left;
  border-radius: 4px;
  border: solid 1px </xsl:text><xsl:value-of select="$color.gray"/><xsl:text>;
}
#es_search_field:focus {
  border: solid 1px </xsl:text><xsl:value-of select="$color.blue"/><xsl:text>;
  box-shadow: 0 0 2px </xsl:text><xsl:value-of select="$color.blue"/><xsl:text>;
}
</xsl:text>
</xsl:template>

<xsl:template name="pintail.elasticsearch.searchform">
  <div class="search">
    <form action="{$pintail.site.root}search{$pintail.extension.link}">
      <xsl:variable name="d">
        <xsl:choose>
          <xsl:when test="contains($pintail.search.domains, ' ')">
            <xsl:value-of select="substring-before($pintail.search.domains, ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$pintail.search.domains"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <input type="hidden" name="d" value="{$d}"/>
      <input type="text" name="q"/>
    </form>
  </div>
</xsl:template>

<xsl:template mode="mal2html.block.mode" match="pintail:searchpage">
  <div id="es_search">
    <div id="es_search_domains"></div>
    <div><input id="es_search_field" type="text"/></div>
    <div id="es_search_results" class="links-divs"/>
  </div>
  <script>
(function() {
var es_host = '<xsl:value-of select="$pintail.elasticsearch.host"/>';
var es_epoch = '<xsl:value-of select="$pintail.elasticsearch.epoch"/>';
var es_index = '<xsl:value-of select="$pintail.elasticsearch.index"/>';
var es_in_domain = false;
var es_domain = '/';
<![CDATA[
var req = null;

var searchbox = document.getElementById('es_search_field');
var searchres = document.getElementById('es_search_results');
var searchtimeout = null;
var searchfunc = function () {
  searchtimeout = null;
  if (req != null) {
    req.abort()
    req = null;
  }
  req = new XMLHttpRequest();
  req.onload = function () {
    var data = JSON.parse(this.responseText);
    var hits = data.hits.hits;
    searchres.innerHTML = '';
    for (var i = 0; i < hits.length; i++) {
      var div = document.createElement('div');
      searchres.appendChild(div);
      div.className = 'linkdiv';
      var lnk = document.createElement('a');
      div.appendChild(lnk);
      lnk.className = 'linkdiv';
      lnk.setAttribute('href', hits[i]._source.path);

      spn = document.createElement('span');
      lnk.appendChild(spn);
      spn.className = 'title';
      spn.textContent = hits[i]._source.title;

      spn = document.createElement('span');
      lnk.appendChild(spn);
      spn.className = 'desc';
      spn.textContent = hits[i]._source.desc;
    }
  };
  req.open('POST',
    'http://' + es_host + '/' + es_index + '/_search'
  );
  req.send(JSON.stringify({
    query: {
      filtered : {
        filter: {
          bool: {
            must: [
              {term: {domain: es_in_domain ? document.getElementById('es_search_domain').value : es_domain}},
              {term: {epoch: es_epoch}}
            ]
          }
        },
        query: { bool: {
          should: [
            {match: {title: {query: searchbox.value, boost: 3}}},
            {match: {desc: {query: searchbox.value, boost: 2}}},
            {match: {keywords: {query: searchbox.value, boost: 2}}},
            {match: {content: {query: searchbox.value, 'boost': 1}}}
          ]
        }}
      }
    }
  }));
};
searchbox.oninput = function () {
  if (searchtimeout != null) {
    window.clearTimeout(searchtimeout);
    searchtimeout = null;
  }
  searchtimeout = window.setTimeout(searchfunc, 500);
};

var qs = window.location.search.substring(1).split('&');
var d = null;
var q = null;
for (var i = 0; i < qs.length; i++) {
  var p = qs[i].split('=');
  if (p[0] == 'q') {
    q = p[1];
  }
  else if (p[0] == 'd') {
    d = p[1];
  }
}
if (d != null) {
  es_domain = decodeURIComponent(d);
  if (es_domain != '/') {
    es_in_domain = true;
    var dboxd = document.getElementById('es_search_domains');
    var lbl = document.createElement('label');
    lbl.setAttribute('for', 'es_search_domain');
    lbl.textContent = 'Search in: ';
    dboxd.appendChild(lbl);

    var dbox = document.createElement('select');
    dbox.onchange = function () { searchbox.oninput(); };
    dbox.setAttribute('id', 'es_search_domain');
    dboxd.appendChild(dbox);

    var opt1 = document.createElement('option');
    opt1.setAttribute('value', es_domain);
    opt1.textContent = es_domain;
    dbox.appendChild(opt1);

    req = new XMLHttpRequest();
    req.onload = function () {
      var data = JSON.parse(this.responseText);
      if (data.found)
        opt1.textContent = data.fields.title[0];
    };
    req.open('get',
      'http://' + es_host + '/' + es_index + '/page/' +
      encodeURIComponent(encodeURIComponent(es_domain)) +
      'index@' + es_epoch + '?fields=title'
    );
    req.send();


    var opt2 = document.createElement('option');
    opt2.setAttribute('value', '/');
    opt2.textContent = 'Entire Site';
    dbox.appendChild(opt2);
  }
}
if (q != null) {
  searchbox.value = decodeURIComponent(q.replace(/\+/g, ' '));
  searchbox.oninput();
}

})();
]]></script>
</xsl:template>

</xsl:stylesheet>
