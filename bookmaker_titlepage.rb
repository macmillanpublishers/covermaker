require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../utilities/oraclequery.rb'
require_relative '../utilities/isbn_finder.rb'

# ---------------------- METHODS

# find any tagged isbn in an html file
def findAnyISBN(file)
  isbn_basestring = File.read(file).match(/spanISBNisbn">\s*978(\D?\d?){10}<\/span>/)
  unless isbn_basestring.nil?
    isbn_basestring = isbn_basestring.to_s.gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  return isbn
end

# find a tagged isbn in an html file that matches a provided book type
def findSpecificISBN(file, string, type)
  allisbns = File.read(file).scan(/(<span class="spanISBNisbn">\s*97[89]((\D?\d){10})<\/span>\s*\(?.*?\)?\s*<\/p>)/)
  pisbn = []
  allisbns.each do |k|
    testisbn = ""
    testisbn = k.to_s.match(/#{string}/)
    case type
    when "include"
      unless testisbn.nil?
        pisbn.push(k)
      end
    when "exclude"
      if testisbn.nil?
        pisbn.push(k)
      end
    end
  end
  isbn_basestring = pisbn.shift
  unless isbn_basestring.nil?
    isbn_basestring = isbn_basestring.to_s.gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  return isbn
end

def findImprint(pisbn, eisbn)
  if pisbn.length == 13
    thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
    isbnhash = runQuery(thissql)
    unless isbnhash.nil? or isbnhash.empty? or !isbnhash
      imprint = isbnhash["book"]["IMPRINT_DESC"]
      puts "Found imprint in DW: #{imprint}"
    else
      imprint = "Macmillan"
      puts "Unable to connect to DW; using default imprint: #{imprint}"
    end
  elsif eisbn.length == 13
    thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    isbnhash = runQuery(thissql)
    unless isbnhash.nil? or isbnhash.empty? or !isbnhash
      imprint = isbnhash["book"]["IMPRINT_DESC"]
      puts "Found imprint in DW: #{imprint}"
    else
      imprint = "Macmillan"
      puts "Unable to connect to DW; using default imprint: #{imprint}"
    end
  else
    imprint = "Macmillan"
    puts "No imprint found in DW; using default imprint: #{imprint}"
  end
  return imprint
end

# determine directory name for assets e.g. css, js, logo images
def getResourceDir(imprint, json)
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
end

# ---------------------- PROCESSES

puts "RUNNING TITLEPAGEMAKER"

# paths to key scripts and JSON metadata
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")
imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
data_hash = Mcmlln::Tools.readjson(configfile)

# the cover filename and metadata
project_dir = data_hash['project']
stage_dir = data_hash['stage']
resource_dir = data_hash['resourcedir']

# --------------- ISBN FINDER COPIED FROM BOOKMAKER_ADDONS/METADATA_PREPROCESSING
# testing to see if ISBN style exists
spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)
multiple_isbns = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand)|(e\s*-*\s*book))\)/)

# determine ISBNs
pisbn, eisbn, allworks = findBookISBNs(Bkmkr::Paths.outputtmp_html, Bkmkr::Project.filename)

# get imprint for logo placement
imprint = findImprint(pisbn, eisbn)

# getting resource_dir based on imprint, for logo
resource_dir = getResourceDir(imprint, imprint_json)
puts "Resource dir: #{resource_dir}"

# --------------- FINISH ISBN FINDER

# Authentication data is required to use docraptor and
# to post images and other assets to the ftp for inclusion
# via docraptor. This auth data should be housed in
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"
submitted_images = Bkmkr::Paths.submitted_images
template_html = File.join(Bkmkr::Paths.project_tmp_dir, "titlepage.html")
pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "css")
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
unless Dir.exist?(final_dir)
  Mcmlln::Tools.makeDir(final_dir)
  Mcmlln::Tools.makeDir(final_dir_images)
end

# create the logging dir if it doesn't exist yet
unless Dir.exist?(logdir)
  Mcmlln::Tools.makeDir(logdir)
end

# find any new user-submitted titlepage images
allimg = File.join(submitted_images, "*")
etparr = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
ptparr = Dir[allimg].select { |f| f.include?('titlepage.')}

puts ptparr

if etparr.any?
  epubtitlepage = etparr.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  if epubtitlepage.nil?
    epubtitlepage = File.join(coverdir, "epubtitlepage.jpg")
  end
else
  epubtitlepage = File.join(coverdir, "epubtitlepage.jpg")
end

if ptparr.any?
  podtitlepage = ptparr.find { |e| /[\/|\\]titlepage\./ =~ e }
  if podtitlepage.nil?
    podtitlepage = File.join(coverdir, "titlepage.jpg")
  end
else
  podtitlepage = File.join(coverdir, "titlepage.jpg")
end

# if an epub-specific titlepage file has been submitted, use that;
# otherwise use the POD coverpage if it exists;
# and if neither exists, we'll create the epubtitlepage.
# (POD titlepage images should only be submitted manually by the user, never created programatically.)
if File.file?(epubtitlepage)
  final_cover = epubtitlepage
elsif File.file?(podtitlepage)
  final_cover = podtitlepage
else
  final_cover = epubtitlepage
end

# set the default switch to generate the titlepage
gen = false

# determine whether there are any titlepage images in the done dir from previous runs
if File.file?(arch_epubtp)
  arch_cover = arch_epubtp
elsif File.file?(arch_podtp)
  arch_cover = arch_podtp
else
  arch_cover = arch_podtp
end

# Determine whether or not to generate a titlepage.
# First check: if a titlepage has previously been generated, and no new image has been submitted by the user
if File.file?(titlepagelog) and !File.file?(final_cover)
  gen = true
  Mcmlln::Tools.deleteFile(titlepagelog)
  Mcmlln::Tools.deleteFile(arch_cover)
# Then check: if a titlepage has previously been generated, but there IS a new image submitted by the user
elsif File.file?(titlepagelog) and File.file?(final_cover)
  gen = false
  Mcmlln::Tools.deleteFile(titlepagelog)
  Mcmlln::Tools.deleteFile(arch_cover)
# Finally: if no titlepage has ever been generated, and no new image has been submitted,
# and there is no existing image archived from a previous run
elsif !File.file?(titlepagelog) and !File.file?(final_cover) and !File.file?(arch_cover)
  gen = true
end

# CSS that will format the final titlepage PDF
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/titlepage.css")
  cover_css_file = File.join(pdf_css_dir, project_dir, "titlepage.css")
else
  cover_css_file = File.join(pdf_css_dir, "generic", "titlepage.css")
end

embedcss = File.read(cover_css_file).gsub(/(\\)/,"\\0\\0").to_s

# prepare the HTML from which to generate the titlepage PDF
Bkmkr::Tools.runnode(gettitlepagejs, "#{Bkmkr::Paths.outputtmp_html} #{template_html}")

pdf_html = File.read(template_html).gsub(/<\/head>/,"<style>#{embedcss}</style></head>")
                                   .gsub(/RESOURCEDIR/,"#{resource_dir}").to_s

# Docraptor setup
DocRaptor.api_key "#{Bkmkr::Keys.docraptor_key}"

# change to DocRaptor 'test' mode when running from staging server
testing_value = "false"
if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt") then testing_value = "true" end

# Create the titlepage PDF
unless gen == false
  puts "Generating titlepage."
  FileUtils.cd(coverdir)
  File.open(cover_pdf, "w+b") do |f|
    f.write DocRaptor.create(:document_content => pdf_html,
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
  # convert the PDF to jpg
  `convert -density 150 -colorspace sRGB "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 -background white -flatten "#{final_cover}"`

  sleep 5 #trying to prevent intermittent permission errors when deleting the PDF

  # delete the now-useless PDF file
  FileUtils.rm(cover_pdf)

  # write the titlepage gen log, from which we determine whether titlepages have been created in the past
  File.open(titlepagelog, 'w+') do |f|
    f.puts Time.now
    f.puts "titlepage generated from document section.titlepage"
  end
end

puts "FINISHED TITLEPAGEMAKER"

# TESTING
if File.file?(final_cover)
  test_jpg_status = "pass: I found a titlepage image"
else
  test_jpg_status = "FAIL: no titlepage image was created"
end

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- TITLEPAGE PROCESSES"
  f.puts test_jpg_status
end
