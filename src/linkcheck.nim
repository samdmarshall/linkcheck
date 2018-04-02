# =======
# Imports
# =======

import uri
import tables
import strtabs
import xmltree
import parseopt
import strutils
import htmlparser
import httpclient


# =====
# State
# =====

type
  Options = object
    help: bool
    version: bool
    recurse: bool
    no_external: bool

# =======
# Globals
# =======

var LookupTable = newTable[string, HttpCode]()

# =========
# Functions
# =========

proc parseCodeForLink(code: HttpCode, address: Uri, original: Uri) =
  if is3xx(code):
    echo "warning: " & $original & " -> " & $address & " encountered a 3xx response, you may want to check this is the correct link."
  if is4xx(code):
    echo "error: " & $original & " -> " & $address & " encountered a 4xx response, this link is broken."
  if is5xx(code):
    echo "warning: " & $original & " -> " & $address & " encountered a 5xx response, you may want to check this is the correct link."

proc checkLinksOnPage(address: Uri, base: Uri, original: Uri, recurse: bool, no_external: bool) = 
  if LookupTable.hasKey($address):
    parseCodeForLink(LookupTable[$address], address, original) 
  else:
    let is_valid_scheme = (address.scheme == "https" or 
                           address.scheme == "http")
    let is_external_page = (address.hostname != base.hostname)
    var request_type = 
      if is_external_page:
        HttpHead
      else:
        HttpGet
    if is_valid_scheme and (not is_external_page or (is_external_page and not no_external)):
      echo "info: Checking " & $address 
      var client = newHttpClient()
      client.headers = newHttpHeaders({"Accept": "text/html"})
      let response = client.request($address, request_type)
      LookupTable[$address] = response.code
      parseCodeForLink(response.code, address, original)
      if not is_external_page and response.headers["content-type"] == "text/html":
        let page_content = parseHtml(response.body)
        for tag in page_content.findAll("a"):
          var link = parseUri(tag.attrs["href"])
          if not link.isAbsolute():
            link.scheme = base.scheme
            link.username = base.username
            link.password = base.password
            link.hostname = base.hostname
            link.port = base.port
          let is_same_page_link = (link.scheme == address.scheme and 
                                   link.username == address.username and
                                   link.password == address.password and
                                   link.hostname == address.hostname and
                                   link.port == address.port and
                                   link.path == address.path)
          if recurse and not is_same_page_link and not tag.attrs["href"].startsWith("#"):
            checkLinksOnPage(link, base, address, recurse, no_external)


# ===========
# Entry Point
# ===========

var options = Options(help: false, version: false, recurse: true, no_external: false)
var location = initUri()

for kind, key, value in getopt():
  case kind
  of cmdArgument:
    location = parseUri(key)
  of cmdLongOption, cmdShortOption:
    case key
    of "h", "help", "?":
      options.help = true
    of "v", "version":
      options.version = true
    of "s", "single-page":
      options.recurse = false
    of "l", "no-external":
      options.no_external = true
    else:
      discard
  of cmdEnd:
    break

if options.help:
  quit(QuitSuccess)

if options.version:
  quit(QuitSuccess)

checkLinksOnPage(location, location, location, options.recurse, options.no_external)
