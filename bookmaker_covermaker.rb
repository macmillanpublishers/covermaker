ENV["NLS_LANG"] = "AMERICAN_AMERICA.WE8MSWIN1252"

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
data_hash = Mcmlln::Tools.readjson(configfile)

# the cover filename and metadata
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
archivedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "cover")

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

# Finding author name(s)
authorname = Metadata.bookauthor

# Finding book title
booktitle = Metadata.booktitle

# Finding book subtitle
booksubtitle = Metadata.booksubtitle

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

final_cover = File.join(coverdir, Metadata.frontcover)
archived_cover = File.join(archivedir, Metadata.frontcover)

if File.file?(final_cover) or File.file?(archived_cover)
  watermark = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "images", "disclaimer.jpg")
  watermarktmp = File.join(archivedir, "disclaimer.jpg")
  FileUtils.cp(watermark, watermarktmp)
  if File.file?(final_cover)
    currcover = final_cover
  elsif File.file?(archived_cover)
    currcover = archived_cover
  end
  targetwidth = `identify -format "%w" "#{currcover}"`
  targetwidth = targetwidth.to_f
  currwidth = `identify -format "%w" "#{watermarktmp}"`
  currwidth = currwidth.to_f
  shave = (targetwidth - currwidth) / 2
  FileUtils.cp(cover_js_file, pdf_js_file)
  `convert -shave #{shave}x0 -quality 100 "#{watermarktmp}"`
  `convert "#{currcover}" "#{watermarktmp}" -append "#{currcover}"`
  FileUtils.rm(watermarktmp)
else
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
  `convert -density 150 "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 "#{final_cover}"`

  # delete the PDF
  FileUtils.rm(cover_pdf)
end

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