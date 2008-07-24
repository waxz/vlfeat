#!/usr/bin/python
#
#  webdoc.py
#  vlfeat
#

# AUTORIGHTS

import sys, os, re, subprocess, signal, htmlentitydefs, shutil
from wikidoc import wikidoc
from optparse import OptionParser
from HTMLParser import HTMLParser
from xml.parsers.expat import ExpatError
from xml.dom import minidom 
import random

usage = """usage: %prog [options] WEB.XML <docdir>

"""

template = """

"""

verb = 0
srcdir = ""
outdir = ""

parser = OptionParser(usage=usage)
parser.add_option(
    "-v", "--verbose", 
    dest    = "verb",
    default = False,
    action  = "store_true",
    help    = "print debug informations")      
parser.add_option(
    "-o", "--outdir", 
    dest    = "outdir",
    default = "",
    action  = "store",
    help    = "directory containing the produced HTML files")

# --------------------------------------------------------------------
def xmkdir(newdir):
# --------------------------------------------------------------------
    """works the way a good mkdir should :)
        - already exists, silently complete
        - regular file in the way, raise an exception
        - parent directory(ies) does not exist, make them as well
    """
    if os.path.isdir(newdir):
        pass
    elif os.path.isfile(newdir):
        raise OSError("a file with the same name as the desired " \
                      "dir, '%s', already exists." % newdir)
    else:
        head, tail = os.path.split(newdir)
        if head and not os.path.isdir(head):
            xmkdir(head)
        if tail:
            os.mkdir(newdir)

# --------------------------------------------------------------------
def readText(fileName):
# --------------------------------------------------------------------
  """
  TEXT = readText(NAME) returns the content of file NAME.
  """
  text = ""
  try:
    file = open(fileName, 'r')
    text = file.read()
    file.close()
  except IOError:
    print "Warning! Could not open text file '%s'" % fileName
  return text
  
# --------------------------------------------------------------------
def writeText(fileName, text):
# --------------------------------------------------------------------
  """
  writeText(NAME, TEXT) writes TEXT to the file NAME.
  """
  try:
    xmkdir(os.path.dirname(fileName))
    file = open(fileName, 'w')
    file.write(text)
    file.close()
  except IOError:
    print "Warning! Could not write text file '%s'" % fileName

# --------------------------------------------------------------------
def iterateChildNodesByTag(node, tag):
# --------------------------------------------------------------------
  """
  This generator searches the childern of NODE for 
  XML elements matching TAG.
  """
  n = node.firstChild
  while n:
    if n.nodeType == n.ELEMENT_NODE and n.nodeName == tag:
      yield n
    n = n.nextSibling

# --------------------------------------------------------------------
def iterateChildNodes(node):
# --------------------------------------------------------------------
  """
  This generator searches the childern of NODE.
  """
  n = node.firstChild
  while n:
    if n.nodeType == n.ELEMENT_NODE:
      yield n
    n = n.nextSibling
    
# --------------------------------------------------------------------
def getAttribute(element, attr, default=None):
# --------------------------------------------------------------------
  if element.hasAttribute(attr):
    return element.getAttribute(attr)
  else:
    return default

# --------------------------------------------------------------------
# This is easy to solve with a simple tiny wrapper:
# --------------------------------------------------------------------
class MakeStatic:
    def __init__(self, method):
        self.__call__ = method
  
# --------------------------------------------------------------------
class Thing:
# --------------------------------------------------------------------
  """
  Represents a file of the website.
  
  - id:        unique ID string for the file  
  - parent:    parent file
  - children:  array of children files
  - depth:     nesting depth
  - dirName:   name of the associated sub-directory
  - baseName:  name of the associated data file

  """
  directory = {}

  def genUniqueID():
    "Generate an ID not already present in the directory of files"
    while 1:
      id = "%010d" % random.random * 1e10
      if id not in Thing.directory: break
    return id

  def dumpDirectory():
    "Dump the content of the file directory to standard output"
    for (id, file) in Thing.directory.iteritems():
      print file

  genUniqueID = MakeStatic(genUniqueID)
  dumpDirectory = MakeStatic(dumpDirectory)

  def __init__(self, id=None):
    self.id = id
    Thing.directory [self.id] = self

  def __str__(self):
    return "id:%s" % self.id


# --------------------------------------------------------------------
class HtmlElement(Thing):
# --------------------------------------------------------------------
  """
  A class instance represents an element ID which has a validity 
  throughout the website.
  """

  def __init__(self, page, htmlId, id=None):
    Thing.__init__(self, id)
    self.htmlId = htmlId
    self.page   = page
    
  def __str__(self):
    return "%s htmlId:%s" % (Thing.__str__(self), self.htmlId)

  def getPathFromRoot(self):
    return self.page.getPathFromRoot() + "#" + self.htmlId

  def getPathFrom(self, basedir):
    return self.page.getPathFrom(basedir) + "#" + self.htmlId


# --------------------------------------------------------------------
class File(Thing):
# --------------------------------------------------------------------
  """
  Represents a page or other file of the website

  - href:   Static hyperref (provided from the XML file) or None
  - title:  Title of the page
  """
  
  SITE = 0
  PAGE = 1
  STYLESHEET = 2
  SCRIPT = 3

  def __init__(self, type, parent=None, id=None):
    Thing.__init__(self, id)
    self.parent    = parent
    self.children  = []
    self.depth     = 0
    self.fileType  = type
    self.dirName   = None
    self.baseName  = None
    self.data      = None
    self.href      = None  
    self.title     = 'untitled'
    self.hide      = False
    if parent: 
      parent.addChild(self)
      self.depth = parent.depth + 1
    
  def __str__(self):
    return "%s type:%d path:%s" % (Thing.__str__(self), self.fileType, 
                                   self.getPathFromRoot())

  def addChild(self, file):
    self.children.append(file)
    file.parent = self

  def getPathFromRoot(self, dironly=False):
    path = ""
    if self.href: return self.href
    if self.parent: path = self.parent.getPathFromRoot(dironly=True)
    if self.dirName: path += self.dirName + "/"
    if not dironly and self.baseName: path += self.baseName
    return path

  def getPathFrom(self, basedir, dironly=False):
    path = self.getPathFromRoot(dironly)
    c = 0
    while c < len(path) and c < len(basedir) and path[c] == basedir[c]:
      c = c + 1
    return re.sub(r'\w*/','../',basedir[c:]) + path[c:]


# --------------------------------------------------------------------
def iterateFiles(parentPage):
# --------------------------------------------------------------------
  """
  iterateFiles(parentPage) generates a depth first visit of the tree
  of pages rooted at parentPage.
  """
  for p in parentPage.children:
    yield p
    for q in iterateFiles(p): yield q

# --------------------------------------------------------------------
def findStyles(file):
# --------------------------------------------------------------------
  styles = []
  if file.parent: styles = findStyles(file.parent)
  for x in file.children:
    if x.fileType == File.STYLESHEET:
      styles.append(x)
  return styles

# --------------------------------------------------------------------
class WebSite:
# --------------------------------------------------------------------
  """
  WebSite represent the whole website. A website is mainly a
  hierarchical collection of pages.
  """
  
  def __init__(self):
    self.root       = File(File.SITE)
    self.template   = ""
    self.src        = ""
  
  def genFullName(self, name):
    """
    site.genFullName(NAME) generates the path to the file NAME,
    assumed relative to the XML file defining the website.
    """
    if name == None: return None
    if (os.path.isabs(name)):
      return name
    else:
      return os.path.join(os.path.dirname(self.src), name)
        
  def load(self, fileName):
    """
    Parse the XML document fileName.
    """
    self.src = fileName
    if verb:
      print "webdoc: parsing `%s'" % self.src
    doc = minidom.parse(self.src).documentElement
    self.xLoadPages(doc, self.root)

  def xLoadPages(self, doc, parent):
    for e in iterateChildNodes(doc):
      file = None

      if   e.tagName == 'stylesheet': fileType = File.STYLESHEET
      elif e.tagName == 'page':       fileType = File.PAGE

      if e.tagName == 'stylesheet' or \
         e.tagName == 'page':
        theId     = getAttribute(e, 'id')
        file      = File(fileType, parent, theId)
        file.src  = self.genFullName(getAttribute(e, 'src'))
        file.href = getAttribute(e, 'href')
        file.title= getAttribute(e, 'title')
        file.hide = getAttribute(e, 'hide') == 'yes'
        if file.src: file.baseName = os.path.basename(file.src)

      if e.tagName == 'template':
        self.template = self.genFullName(e.getAttribute('src'))

      # load children
      if e.tagName == 'page':
        self.xLoadPages(e, file)
        if len(file.children) > 0:
          dirName = os.path.splitext(file.baseName)[0]
          if not dirName == 'index':
            file.dirName = dirName
          else:
            file.dirName = ''

      # extract refs
      if e.tagName == 'page' and file.src:
        file.data = readText(file.src)
        extractor = RefExtractor()
        extractor.feed(file.data)
        for i in extractor.ids:
          HtmlElement(file, i, i)
          
      # handle include 
      if e.tagName == 'include':
        if verb:
          src = self.genFullName(getAttribute(e, 'src'))
          print "webdoc: including `%s'\n" % src
          site = WebSite()
          try:
            site.load(src)
          except IOError, e:
            print "Could not access file %s (%s)" % (filename, e)
          except ExpatError, e:
            print "Error parsing file %s (%s)" % (filename, e)
          for x in iterateFiles(site.root):
            x.depth = x.depth + parent.depth + 1
          for x in site.root.children:
            parent.addChild(x)

  def genHtmlIndex(self, parentPage):
    html = ""
    if len(parentPage.children) == 0: return html
    parentIndent = " " * parentPage.depth
    html += parentIndent + "<ul>\n"
    for page in parentPage.children:
      if not (page.fileType == File.SITE or page.fileType == File.PAGE): continue
      if page.hide: continue
      indent = " " * page.depth
      html += indent + "<li>\n"
      html += indent + "<a href='%s'>%s</a>\n" % (page.id,page.title) 
      html += self.genHtmlIndex(page)
      html += indent + "</li>\n"
    html += parentIndent + "</ul>\n"
    return html
        
  def genSite(self):
    for thing in iterateFiles(self.root):

      if isinstance (thing, File) and thing.fileType == File.STYLESHEET:
        fileName = thing.getPathFromRoot()
        print "webdoc: writing stylesheet %s from %s" % (fileName, thing.src)
        writeText(os.path.join(outdir, fileName), readText(thing.src))
      
      if isinstance (thing, File) and thing.fileType == File.PAGE:
        page = thing
        if thing.data:
          dirName = page.getPathFromRoot(True)
          fileName = page.getPathFromRoot()

          text = readText(os.path.join(srcdir, self.template))

          rootpath = self.root.getPathFrom(thing.getPathFromRoot(True), True)

          # stylesheets block
          block = ""
          for x in findStyles(page):
            block += '<link rel="stylesheet" href="%s" type="text/css"/>\n' % \
                x.getPathFrom(dirName)
                       
          text = re.sub("%stylesheet;", block, text)
          text = re.sub("%pagetitle;", "VLFeat - %s" % page.title, text)
          text = re.sub("%title;", "<h1>VLFeat</h1>", text)
          text = re.sub("%subtitle;", "<h2>%s</h2>" % page.title, text)
          text = re.sub("%index;", self.genHtmlIndex(self.root), text)
          text = re.sub("%content;", page.data, text)
          text = re.sub("%root;", rootpath, text)
          
          generator = PageGenerator(site, dirName)
          generator.feed(text)
          text = generator.output()

          writeText(os.path.join(outdir, fileName), text)
          print "webdoc: wrote page %s" % (fileName)
        
  def debug(self):
    print "=== Index ==="
    print self.genHtmlIndex(self.root)
    print "=== IDs ==="
    Thing.dumpDirectory()


# --------------------------------------------------------------------    
class RefExtractor(HTMLParser):
# --------------------------------------------------------------------
  def __init__(self):
    HTMLParser.__init__(self)
    self.ids = []

  def handle_starttag(self, tag, attrs):
    for (k,i) in attrs:
      if k == 'id':
        self.ids.append(i)
        
# --------------------------------------------------------------------    
class PageGenerator(HTMLParser):
# --------------------------------------------------------------------
  def __init__(self, site, basedir):
    HTMLParser.__init__(self)
    self.pieces = []
    self.site = site
    self.basedir = basedir
    
  def handle_starttag(self, tag, attrs):
    for n in range(len(attrs)):
      (k,i) = attrs[n]
      if k == 'href':
        if i in Thing.directory:
          path = ""
          thing = Thing.directory [i]
          path = thing.getPathFrom(self.basedir)
          attrs[n] = (k, path)
    strattrs = "".join([' %s="%s"' % (key, value) for 
      key, value in attrs])
    self.pieces.append("<%(tag)s%(strattrs)s>" % locals())

  def handle_endtag(self, tag):
    self.pieces.append("</%(tag)s>" % locals())
    
  def handle_charref(self, ref):         
    self.pieces.append("&#%(ref)s;" % locals())
    
  def handle_entityref(self, ref):       
    self.pieces.append("&%(ref)s" % locals())
    if htmlentitydefs.entitydefs.has_key(ref):
        self.pieces.append(";")

  def handle_data(self, text):           
    self.pieces.append(text)

  def handle_comment(self, text):        
    self.pieces.append("<!--%(text)s-->" % locals())

  def handle_pi(self, text):             
    self.pieces.append("<?%(text)s>" % locals())

  def handle_decl(self, text):
    self.pieces.append("<!%(text)s>" % locals())

  def output(self):              
    """Return processed HTML as a single string"""
    return "".join(self.pieces)

# --------------------------------------------------------------------    
if __name__ == '__main__':
# --------------------------------------------------------------------

  #
  # Parse comand line options
  #
  (options, args) = parser.parse_args()
  filename = args[0]
  
  verb = options.verb
  xmldoc = args[0]
  outdir = options.outdir

  if verb:
    print "webdoc: website document: `%s'" % xmldoc
    print "webdoc: output path: `%s'" % outdir

  site = WebSite()
  site.load(xmldoc)
  site.debug()
  site.genSite()
  
  
  
    
    


