from setuptools import setup

import sys

if sys.version_info[0] != 3:
    sys.stderr.write("pintail-elasticsearch requires python 3\n")
    sys.exit(1)

setup(
    name='pintail-elasticsearch',
    version='0.3',
    description='Use Elasticsearch on Pintail sites.',
    packages=['pintail', 'pintail.elasticsearch'],
    namespace_packages=['pintail'],
    package_data={
        'pintail.elasticsearch': ['pintail-elasticsearch.xsl', 'pintail-elasticsearch.page']
    },
    install_requires=['pintail>=0.3', 'elasticsearch'],
    author='Shaun McCance',
    author_email='shaunm@gnome.org',
    license='GPLv2+',
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Environment :: Console',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3 :: Only',
        'Topic :: Documentation',
        'Topic :: Software Development :: Documentation',
        'Topic :: Text Processing :: Markup',
        'Topic :: Text Processing :: Markup :: XML',
        'License :: OSI Approved :: GNU General Public License v2 or later (GPLv2+)'
    ],
)
