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
</xsl:text>
</xsl:template>

<xsl:template name="pintail.elasticsearch.searchform">
  <div class="search">
    <form action="{$pintail.site.root}search{$pintail.extension.link}">
      <input type="hidden" name="epoch" value="{$pintail.elasticsearch.epoch}"/>
      <input type="text" name="terms"/>
    </form>
  </div>
</xsl:template>

<xsl:template mode="mal2html.block.mode" match="pintail:searchpage">
  <p>This is the search page.</p>
  <input id="es_search_field" type="text"/>
  <div id="es_search_results" class="links-divs"/>
  <script>
(function() {
var es_host = '<xsl:value-of select="$pintail.elasticsearch.host"/>';
var es_epoch = '<xsl:value-of select="$pintail.elasticsearch.epoch"/>';
var es_index = '<xsl:value-of select="$pintail.elasticsearch.index"/>';
<![CDATA[
var req = null;

var domain = '/';

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
              {term: {domain: domain}},
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
for (var i = 0; i < qs.length; i++) {
  var p = qs[i].split('=');
  if (p[0] == 'terms') {
    searchbox.value = p[1];
    searchbox.oninput();
    break;
  }
}

})();
]]></script>
</xsl:template>

</xsl:stylesheet>
