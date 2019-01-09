require 'rubygems'
require 'doc_raptor'
require 'fileutils'
require 'htmlentities'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'
require_relative '../utilities/isbn_finder.rb'

# ---------------------- VARIABLES

local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# paths to key scripts and JSON metadata
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")
imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")
watermark_css = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "css", "generic", "watermark.css")

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def testingValue(file, logkey='')
  # change to DocRaptor 'test' mode when running from staging server
  testing_value = "false"
  if File.file?(file) then testing_value = "true" end
  return testing_value
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# wrapping a method from isbnFinder.rb so we can get output for json_logfile
def getIsbns(file, filename, isbn_stylename, logkey='')
  pisbn, eisbn, allworks = findBookISBNs(file, filename, isbn_stylename)
  return pisbn, eisbn, allworks
rescue => logstring
  return '','',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# Find any custom metadata overrides that users added to the file
def getMetaElement(file, name, logkey='')
  logstring = "none"
  metaelement = File.read(file).match(/(<meta name="#{name}" content=")(.*?)("\/>)/i)
  unless metaelement.nil?
    metaelement = HTMLEntities.new.decode(metaelement[2])
    logstring = metaelement
  end
  return metaelement
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findImprint(file, pisbn, eisbn, logkey='')
  logstring = "Not Found"

  if pisbn.length == 13
    thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
    isbnhash = runQuery(thissql)
    unless isbnhash.nil? or isbnhash.empty? or !isbnhash
      imprint = isbnhash["book"]["IMPRINT_DESC"]
      logstring = "Found imprint in DW: #{imprint}"
    else
      imprint = "Macmillan"
      logstring =  "Unable to connect to DW; using default imprint: #{imprint}"
    end
  elsif eisbn.length == 13
    thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    isbnhash = runQuery(thissql)
    unless isbnhash.nil? or isbnhash.empty? or !isbnhash
      imprint = isbnhash["book"]["IMPRINT_DESC"]
      logstring =  "Found imprint in DW: #{imprint}"
    else
      imprint = "Macmillan"
      logstring =  "Unable to connect to DW; using default imprint: #{imprint}"
    end
  else
    imprint = "Macmillan"
    logstring =  "No imprint found in DW; using default imprint: #{imprint}"
  end

  # if there is custom imprint metadata, use that instead of whatever is in the DW
  metaimprint = getMetaElement(file, "imprint", 'custom_imprint_metaelement')
  unless metaimprint.nil?
    imprint = metaimprint
    logstring = metaimprint
  end

  return imprint
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# determine directory name for assets e.g. css, js, logo images
def getResourceDir(imprint, json, logkey='')
  data_hash = Mcmlln::Tools.readjson(json)
  arr = []
  # loop through each json record to see if imprint name matches formalname
  data_hash['imprints'].each do |p|
    if p['formalname'] == imprint
      arr << p['shortname']
    end
  end
  # in case of multiples, grab just the last entry and return it
  if arr.nil? or arr.empty?
    path = "generic"
  else
    path = arr.pop
  end
  return path
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def makeFolder(path, logkey='')
  unless Dir.exist?(path)
    Mcmlln::Tools.makeDir(path)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkForOldTitlepages(coverdir, logkey='')
  oldtitlepage = ""
  oldepubtitlepage = File.join(coverdir, "epubtitlepage.jpg")
  oldpodtitlepage = File.join(coverdir, "titlepage.jpg")

  if File.file?(oldepubtitlepage)
    logstring = "Found an archived EPUB titlepage"
    oldtitlepage = oldepubtitlepage
  elsif File.file?(oldpodtitlepage)
    logstring = "Found an archived POD titlepage"
    oldtitlepage = oldpodtitlepage
  end
  return oldtitlepage
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkForSubmittedTitlepages(submitted_images, logkey='')
  allimg = File.join(submitted_images, "*")
  etparr = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
  ptparr = Dir[allimg].select { |f| f.include?('titlepage.')}

  newtitlepage = ""

  if etparr.any?
    logstring = "Found a new EPUB titlepage"
    newtitlepage = etparr.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  elsif ptparr.any?
    logstring = "Found a new POD titlepage"
    newtitlepage = ptparr.find { |e| /[\/|\\]titlepage\./ =~ e }
  end
  return newtitlepage
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setFinalTitlepage(oldtitlepage, newtitlepage, logkey='')
  final_cover = oldtitlepage
  if File.file?(newtitlepage)
    final_cover = newtitlepage
  end
  return final_cover
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# Determine whether or not to generate a titlepage.
def detectAutoGeneratedTitlepage(titlepagelog, newtitlepage, oldtitlepage, final_cover, logkey='')
  # set the default switch for generating titlepage to false
  gen = false
  # First check: if an epub titlepage has previously been generated, and no new image has been submitted by the user
  if File.file?(titlepagelog) and !File.file?(newtitlepage)
    gen = true
    Mcmlln::Tools.deleteFile(titlepagelog)
    Mcmlln::Tools.deleteFile(oldtitlepage)
  # Then check: if a titlepage has previously been generated, but there IS a new image submitted by the user
  elsif File.file?(titlepagelog) and File.file?(newtitlepage)
    gen = false
    Mcmlln::Tools.deleteFile(titlepagelog)
    Mcmlln::Tools.deleteFile(oldtitlepage)
  # Finally: if no titlepage has ever been generated, and no new image has been submitted,
  # and there is no existing image archived from a previous run
  elsif !File.file?(titlepagelog) and !File.file?(final_cover)
    gen = true
  end
  return gen
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getEmbedCss(cover_css_file, logkey='')
  embedcss = File.read(cover_css_file).gsub(/(\\)/,"\\0\\0").to_s
  return embedcss
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
	Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def updateHTMLmetainfo(template_html, resource_dir, logkey='')
  pdf_html_contents = File.read(template_html).gsub(/RESOURCEDIR/,"#{resource_dir}")
  return pdf_html_contents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteHtml(path, filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# for DocRaptor
def embedCSSinHTML(pdf_html_contents, embedcss, logkey='')
  pdf_html_contents = pdf_html_contents.gsub(/<\/head>/,"<style>#{embedcss}</style></head>").to_s
  return pdf_html_contents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def generateTitlepage(coverdir, cover_pdf, pdf_html_contents, pdf_html_file, cover_css_file, testing_value, watermark_css, logkey='')
  if Bkmkr::Tools.os == "mac" or Bkmkr::Tools.os == "unix"
    princecmd = "prince"
  elsif Bkmkr::Tools.os == "windows"
    princecmd = File.join(Bkmkr::Paths.resource_dir, "Program Files (x86)", "Prince", "engine", "bin", "prince.exe")
    princecmd = "\"#{princecmd}\""
  end
  if Bkmkr::Tools.pdfprocessor == "prince"
    if testing_value == "false"
      output = `#{princecmd} -s \"#{cover_css_file}\" --javascript --http-user=#{Bkmkr::Keys.http_username} --http-password=#{Bkmkr::Keys.http_password} \"#{pdf_html_file}\" -o \"#{cover_pdf}\"`
    elsif testing_value == "true"
      output = `#{princecmd} -s \"#{cover_css_file}\" -s \"#{watermark_css}\" --javascript --http-user=#{Bkmkr::Keys.http_username} --http-password=#{Bkmkr::Keys.http_password} \"#{pdf_html_file}\" -o \"#{cover_pdf}\"`
    end
    @log_hash['prince_output'] = output
  elsif Bkmkr::Tools.pdfprocessor == "docraptor"
    FileUtils.cd(coverdir)
    File.open(cover_pdf, "w+b") do |f|
      f.write DocRaptor.create(:document_content => pdf_html_contents,
                               :name             => "titlepage.pdf",
                               :document_type    => "pdf",
                               :strict			     => "none",
                               :test             => "#{testing_value}",
    	                         :prince_options	 => {
    	                           :http_user		 => "#{Bkmkr::Keys.http_username}",
    	                           :http_password	 => "#{Bkmkr::Keys.http_password}",
                                   :javascript       => "true"
    							             }
                           		)
    end
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def convertGeneratedTitlepage(cover_pdf, final_cover, logkey='')
  `convert -density 150 -colorspace sRGB "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 -background white -flatten "#{final_cover}"`
  # sleep is to prevent intermittent permission errors when deleting the PDF post-conversion
  sleep 5
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeTitlepageLog(titlepagelog, logkey='')
  File.open(titlepagelog, 'w+') do |f|
    f.puts Time.now
    f.puts "titlepage generated from document section.titlepage"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def rmFile(file, logkey='')
	Mcmlln::Tools.deleteFile(file)
rescue => logstring
ensure
	Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def titlepageTest(final_cover, logkey='')
  if File.file?(final_cover)
    logstring = "pass: I found a titlepage image"
  else
    logstring = "FAIL: no titlepage image was created"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
doctemplatetype = data_hash['doctemplatetype']
if doctemplatetype == 'rsuite'
  isbn_stylename = 'cs-isbnisbn'
  pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "rsuite_assets", "css")
else
  isbn_stylename = 'spanISBNisbn'
  pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "css")
end

# run method: testingValue
testing_value = testingValue(testing_value_file, 'testing_value_test')
@log_hash['running_on_testing_server'] = testing_value

# determine ISBNs
pisbn, eisbn, allworks = getIsbns(Bkmkr::Paths.outputtmp_html, Bkmkr::Project.filename, isbn_stylename, 'get_isbns')

# get imprint for logo placement
imprint = findImprint(Bkmkr::Paths.outputtmp_html, pisbn, eisbn, 'find_imprint')

# getting resource_dir based on imprint, for logo
resource_dir = getResourceDir(imprint, imprint_json, 'get_resource_dir')
@log_hash['resource_dir'] = resource_dir

# Authentication data is required to use docraptor and
# to post images and other assets to the ftp for inclusion
# via docraptor. This auth data should be housed in
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
# ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
# ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
# ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"
submitted_images = Bkmkr::Paths.submitted_images
template_html = File.join(Bkmkr::Paths.project_tmp_dir, "titlepage.html")
gettitlepagejs = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "scripts", "generic", "get_titlepage.js")

# paths that depend on the ISBN; must follow the isbn_finder
coverdir = File.join(Bkmkr::Paths.done_dir, pisbn, "images")
cover_pdf = File.join(coverdir, "titlepage.pdf")
final_dir = File.join(Bkmkr::Paths.done_dir, pisbn)
final_dir_images = File.join(Bkmkr::Paths.done_dir, pisbn, "images")
logdir = File.join(Bkmkr::Paths.done_dir, pisbn, "logs")
titlepagelog = File.join(logdir, "titlepage.txt")
arch_podtp = File.join(Bkmkr::Paths.done_dir, pisbn, "images", "titlepage.jpg")
arch_epubtp = File.join(Bkmkr::Paths.done_dir, pisbn, "images", "epubtitlepage.jpg")

# create the final archive dirs if they don't exist yet
makeFolder(final_dir, 'create_final_dir')
makeFolder(final_dir_images, 'create_final_dir_images')

# create the logging dir if it doesn't exist yet
makeFolder(logdir, 'create_logdir')

# find any archived titlepage images
oldtitlepage = checkForOldTitlepages(coverdir, 'check_for_old_titlepages')

# find any new user-submitted titlepage images
newtitlepage = checkForSubmittedTitlepages(submitted_images, 'check_for_submitted_titlepages')

# if an epub-specific titlepage file has been submitted, use that;
# otherwise use the new POD coverpage if it exists;
# and if neither exists, we'll create the epubtitlepage, and set it to the final archival path.
# (POD titlepage images should only be submitted manually by the user, never created programatically.)

final_cover = setFinalTitlepage(oldtitlepage, newtitlepage, 'set_final_cover_var')

# Determine whether or not to generate a titlepage.
gen = detectAutoGeneratedTitlepage(titlepagelog, newtitlepage, oldtitlepage, final_cover, 'determine_titlepage_generation')
@log_hash['gen_value_(generate_titlepage_bool)'] = gen

# now that we've got the logic out of the way,
# set a default value for the final titlepage,
# if no images were found above

if final_cover.empty? or final_cover.nil?
  final_cover = arch_epubtp
end

# CSS that will format the final titlepage PDF
cover_css_file = File.join(pdf_css_dir, "generic", "titlepage.css")

embedcss = getEmbedCss(cover_css_file, 'get_embed_css')

# prepare the HTML from which to generate the titlepage PDF
localRunNode(gettitlepagejs, "#{Bkmkr::Paths.outputtmp_html} #{template_html} #{doctemplatetype}", 'get_titlepage_js')

pdf_html_contents = updateHTMLmetainfo(template_html, resource_dir, 'update_html_metainfo')

# write updated html back to file for prince conversion
overwriteHtml(template_html, pdf_html_contents, 'write_updated_template_html_to_file')

# prepare raw html with embedcss for Docraptor conversion
pdf_html_contents = embedCSSinHTML(pdf_html_contents, embedcss, 'embed_css_in_html')

# Docraptor setup
DocRaptor.api_key "#{Bkmkr::Keys.docraptor_key}"

# Create the titlepage PDF
unless gen == false
  @log_hash['titlepage_status'] =  "Generating titlepage."
  generateTitlepage(coverdir, cover_pdf, pdf_html_contents, template_html, cover_css_file, testing_value, watermark_css, 'generate_titlepage')

  # convert the PDF to jpg
  convertGeneratedTitlepage(cover_pdf, final_cover, 'convert_generated_titlepage_to_jpg')

  # write the titlepage gen log, from which we determine whether titlepages have been created in the past
  writeTitlepageLog(titlepagelog, 'write_titlepage_logfile')

  # delete the now-useless PDF file
  rmFile(cover_pdf, 'rm_cover_pdf')
else
  @log_hash['titlepage_status'] = "Not generating a titlepage."
end

# titlepage-maker test
titlepageTest(final_cover, 'titlepage_test')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
