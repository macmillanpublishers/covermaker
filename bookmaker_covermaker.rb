require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# Local path var(s)
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# the cover filename
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# Authentication data is required to use docraptor and 
# to post images and other assets to the ftp for inclusion 
# via docraptor. This auth data should be housed in 
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"

DocRaptor.api_key "#{docraptor_key}"

# change to DocRaptor 'test' mode when running from staging server
testing_value = "false"
if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt") then testing_value = "true" end

coverdir = Bkmkr::Paths.submitted_images

# template html file
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/#{stage_dir}.html")
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/#{stage_dir}.html"
elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html")
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html"
else
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/generic/template.html"
end

# pdf css to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/#{stage_dir}.css")
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/#{stage_dir}.css"
elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css")
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css"
else
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/generic/cover.css"
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
test_pisbn_chars = Metadata.pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_pisbn_length = Metadata.pisbn.split(%r{\s*})
test_eisbn_chars = Metadata.eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_eisbn_length = Metadata.eisbn.split(%r{\s*})

if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
  thissql = exactSearchSingleKey(Metadata.pisbn, "EDITION_EAN")
  myhash = runQuery(thissql)
elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
  thissql = exactSearchSingleKey(Metadata.eisbn, "EDITION_EAN")
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

# test_cover_html = File.join(coverdir, "cover.html")
# File.open(test_cover_html, "w") do |cover|
#   cover.puts pdf_html
# end

# sends file to docraptor for conversion
cover_pdf = File.join(coverdir, "cover.pdf")
FileUtils.cd(coverdir)
File.open(cover_pdf, "w+b") do |f|
  f.write DocRaptor.create(:document_content => pdf_html,
                           :name             => "cover.pdf",
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
final_cover = File.join(coverdir, Metadata.frontcover)
`convert -density 150 "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 "#{final_cover}"`

FileUtils.rm(cover_pdf)

# TESTING

# title should exist
test_title_chars = booktitle.scan(/[a-z]/)
test_title_nums = booktitle.scan(/[1-9]/)

if test_title_chars.length != 0 or test_title_nums.length != 0
  test_title_status = "pass: title is composed of one or more letters or numbers"
else
  test_title_status = "FAIL: title is composed of one or more letters or numbers"
end

# author name should be text or blank space
# subtitle should be text or blank space

# cover jpg should exist in tmp dir
if File.file?(final_cover)
  test_jpg_status = "pass: The cover jpg was successfully created"
else
  test_jpg_status = "FAIL: The cover jpg was successfully created"
end

# cover jpg should be 600px wide

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- COVERMAKER PROCESSES"
  f.puts test_title_status
  f.puts test_jpg_status
end