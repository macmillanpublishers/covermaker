require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# Local path var(s)
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")

project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift
stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

# Authentication data is required to use docraptor and 
# to post images and other assets to the ftp for inclusion 
# via docraptor. This auth data should be housed in 
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"

DocRaptor.api_key "#{Bkmkr::Keys.docraptor_key}"

spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)
multiple_isbns = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand)|(e\s*-*\s*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.?on.?demand))\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/<span class="spanISBNisbn">\s*.+<\/span>\s*\(e\s*-*\s*book\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(ebook\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# just in case no isbn is found
if pisbn.length == 0
  pisbn = Bkmkr::Project.filename
end

if eisbn.length == 0
  eisbn = Bkmkr::Project.filename
end

# change to DocRaptor 'test' mode when running from staging server
testing_value = "false"
if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt") then testing_value = "true" end

coverdir = Bkmkr::Paths.submitted_images

# template html file
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/titlepage.html")
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/titlepage.html"
else
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/generic/titlepage.html"
end

# pdf css to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/titlepage.css")
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/titlepage.css"
else
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/generic/titlepage.css"
end

embedcss = File.read(cover_css_file).gsub(/(\\)/,"\\0\\0").to_s

# pdf js to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/#{stage_dir}.js")
  cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/#{stage_dir}.js"
elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/cover.js")
  cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/cover.js"
else
  cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/generic/cover.js"
end

pdf_js_file = File.join(Bkmkr::Paths.project_tmp_dir, "cover.js")

# connect to DB for all other metadata
test_pisbn_chars = pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_pisbn_length = pisbn.split(%r{\s*})
test_eisbn_chars = eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_eisbn_length = eisbn.split(%r{\s*})

if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
  thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
  myhash = runQuery(thissql)
elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
  thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
  myhash = runQuery(thissql)
else
  myhash = {}
end

unless myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  puts "DB Connection SUCCESS: Found a book record"
else
  puts "No DB record found; falling back to manuscript fields"
end

# Finding author name(s)
if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['WORK_COVERAUTHOR'].nil? or myhash['book']['WORK_COVERAUTHOR'].empty? or !myhash['book']['WORK_COVERAUTHOR']
  authorname = Metadata.bookauthor
else
  authorname = myhash['book']['WORK_COVERAUTHOR']
  authorname = authorname.encode('utf-8')
end

# Finding book title
if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
  booktitle = Metadata.booktitle
else
  booktitle = myhash["book"]["WORK_COVERTITLE"]
  booktitle = booktitle.encode('utf-8')
end

# Finding book subtitle
if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_SUBTITLE"].nil? or myhash["book"]["WORK_SUBTITLE"].empty? or !myhash["book"]["WORK_SUBTITLE"]
  booksubtitle = Metadata.booksubtitle
else
  booksubtitle = myhash["book"]["WORK_SUBTITLE"]
  booksubtitle = booksubtitle.encode('utf-8')
end

if booksubtitle == "Unknown"
	booksubtitle = " "
end

FileUtils.cp(cover_js_file, pdf_js_file)
jscontents = File.read(pdf_js_file).gsub(/BKMKRINSERTBKTITLE/,"#{booktitle}").gsub(/BKMKRINSERTBKSUBTITLE/,"#{booksubtitle}").gsub(/BKMKRINSERTBKAUTHOR/,"#{authorname}")
File.open(pdf_js_file, 'w') do |output| 
  output.write jscontents
end

embedjs = File.read(pdf_js_file).to_s

pdf_html = File.read(template_html).gsub(/<\/head>/,"<script>#{embedjs}</script><style>#{embedcss}</style></head>").to_s

# sends file to docraptor for conversion
cover_pdf = File.join(coverdir, "titlepage.pdf")

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

# convert to jpg
final_cover = File.join(coverdir, "titlepage.jpg")
`convert -density 150 "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 "#{final_cover}"`

FileUtils.rm(cover_pdf)
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