# pintail - Build static sites from collections of Mallard documents
# Copyright (c) 2016 Shaun McCance <shaunm@gnome.org>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; see the file COPYING.LGPL.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02111-1307, USA.

import codecs
import datetime
import os
import urllib
import uuid

import pintail.search
import pintail.site

import elasticsearch

class ElasticSearchPage(pintail.site.MallardPage):
    def __init__(self, directory):
        pintail.site.MallardPage.__init__(self, directory, 'pintail-elasticsearch.page')

    @property
    def source_path(self):
        return self.stage_path

    @property
    def searchable(self):
        return False

    def stage_page(self):
        pintail.site.Site._makedirs(self.directory.stage_path)
        from pkg_resources import resource_string
        xsl = resource_string(__name__, 'pintail-elasticsearch.page')
        fd = open(self.stage_path, 'w', encoding='utf-8')
        fd.write(codecs.decode(xsl, 'utf-8'))
        fd.close()

    @classmethod
    def get_pages_dir(cls, directory):
        if directory.path == '/':
            return [cls(directory)]
        else:
            return []


class ElasticSearchProvider(pintail.search.SearchProvider,
                            pintail.site.ToolsProvider,
                            pintail.site.XslProvider):
    analyzers = {
        'ar': 'arabic',
        'bg': 'bulgarian',
        'ca': 'catalan',
        'ckb': 'sorani',
        'cs': 'czech',
        'da': 'danish',
        'de': 'german',
        'el': 'greek',
        'en': 'english',
        'es': 'spanish',
        'eu': 'basque',
        'fa': 'persian',
        'fi': 'finnish',
        'fr': 'french',
        'ga': 'irish',
        'gl': 'galician',
        'hi': 'hindi',
        'hu': 'hungarian',
        'hy': 'armenian',
        'id': 'indonesian',
        'it': 'italian',
        'ja': 'cjk',
        'ko': 'cjk',
        'lt': 'lithuanian',
        'lv': 'latvian',
        'nb': 'norwegian',
        'nl': 'dutch',
        'nn': 'norwegian',
        'no': 'norwegian',
        'pt': 'portuguese',
        'pt-br': 'brazilian',
        'ro': 'romanian',
        'ru': 'russian',
        'sv': 'swedish',
        'th': 'thai',
        'tr': 'turkish',
        'zh': 'cjk',
    }

    def __init__(self, site):
        pintail.search.SearchProvider.__init__(self, site)
        self.epoch = site.config.get('search_epoch')
        if self.epoch is None:
            self.epoch = (datetime.datetime.now().strftime('%Y-%m-%d') +
                          '-' + str(uuid.uuid1()))
        elhost = self.site.config.get('search_elastic_host')
        self.elastic = elasticsearch.Elasticsearch([elhost])
        self._indexes = []

    @classmethod
    def get_xsl(cls, site):
        return [os.path.join(site.tools_path, 'pintail-elasticsearch-params.xsl'),
                os.path.join(site.tools_path, 'pintail-elasticsearch.xsl')]

    @classmethod
    def build_tools(cls, site):
        xsl = os.path.join(site.tools_path, 'pintail-elasticsearch-params.xsl')
        fd = open(xsl, 'w')
        fd.write('<xsl:stylesheet' +
                 ' xmlns:xsl="http://www.w3.org/1999/XSL/Transform"' +
                 ' version="1.0">\n')
        fd.write('<xsl:param name="pintail.elasticsearch.host" select="\'%s\'"/>\n' %
                 site.config.get('search_elastic_host'))
        fd.write('<xsl:param name="pintail.elasticsearch.epoch" select="\'%s\'"/>\n' %
                 site.search_provider.epoch)
        fd.write('</xsl:stylesheet>\n')

        from pkg_resources import resource_string
        xsl = resource_string(__name__, 'pintail-elasticsearch.xsl')
        fd = open(os.path.join(site.tools_path, 'pintail-elasticsearch.xsl'),
                  'w', encoding='utf-8')
        fd.write(codecs.decode(xsl, 'utf-8'))
        fd.close()

    def get_analyzer(self, lang):
        # FIXME: if POSIX code, convert to BCP47
        if lang.lower() in ElasticSearchProvider.analyzers:
            return ElasticSearchProvider.analyzers[lang.lower()]
        if '-' in lang:
            return ElasticSearchProvider.get_analyzer(lang[:lang.rindex('-')])
        return 'english'

    def create_index(self, lang):
        if lang in self._indexes:
            return
        self._indexes.append(lang)

        if self.elastic.indices.exists('pintail@' + lang):
            # FIXME: update index settings?
            pass
        else:
            analyzer = self.get_analyzer(lang)
            self.elastic.indices.create(
                index=('pintail@' + lang),
                body={
                    'mappings': {
                        'page': {
                            'properties': {
                                'path': {'type': 'string', 'index': 'not_analyzed'},
                                'lang': {'type': 'string', 'index': 'not_analyzed'},
                                'domain': {'type': 'string', 'index': 'not_analyzed'},
                                'epoch': {'type': 'string', 'index': 'not_analyzed'},
                                'title': {'type': 'string', 'analyzer': analyzer},
                                'desc': {'type': 'string', 'analyzer': analyzer},
                                'keywords': {'type': 'string', 'analyzer': analyzer},
                                'content': {'type': 'string', 'analyzer': analyzer}
                            }
                        }
                    }
                })

    def index_page(self, page):
        self.site.log('INDEX', page.site_id)

        lang = 'en'
        self.create_index(lang)

        title = page.get_title()
        desc = page.get_desc()
        keywords = page.get_keywords()
        content = page.get_content()

        elid = urllib.parse.quote(page.site_id, safe='') + '@' + self.epoch
        elindex = 'pintail@' + lang

        domains = []
        for domain in page.directory.get_search_domains():
            if isinstance(domain, list):
                if domain[0] == page.page_id:
                    domains.append(domain[1])
            else:
                domains.append(domain)

        self.elastic.index(index=elindex, doc_type='page', id=elid, body={
            'path': page.site_id,
            'lang': lang,
            'domain': domains,
            'epoch': self.epoch,
            'title': title,
            'desc': desc,
            'keywords': keywords,
            'content': content
        })
