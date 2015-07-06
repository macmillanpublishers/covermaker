require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# Local path var(s)
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# the cover filename
project_dir = data_hash['project']

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
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html")
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html"
else
  template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/generic/template.html"
end

# pdf css to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css")
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css"
else
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/generic/cover.css"
end

css_file = File.read("#{cover_css_file}").to_s

book_title = File.read(Bkmkr::Paths.outputtmp_html).scan(/<h1 class="TitlepageBookTitletit">.+?<\/h1>/).to_s.gsub(/<h1 class="TitlepageBookTitletit">/,"").gsub(/<\/h1>/,"").gsub(/\["/,"").gsub(/"\]/,"")

book_author_basestring = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?<\/p>/)

if book_author_basestring.any?
  authorname1 = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?<\/p>/).join(",")
  book_author = authorname1.gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/<\/p>/,"")
else
  authorname1 = " "
  book_author = " "
end

book_subtitle_basestring = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageBookSubtitlestit">.+?<\/p>/)

if book_subtitle_basestring.any?
  book_subtitle = book_subtitle_basestring.pop.to_s.gsub(/<p class="TitlepageBookSubtitlestit">/,"").gsub(/<\/p>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
  book_subtitle = " "
end

# inserts the css into the head of the html
pdf_html = File.read("#{template_html}").to_s.gsub(/CSSFILEHERE/,"#{css_file}").gsub(/BOOKTITLE/,"#{book_title}").gsub(/BOOKSUBTITLE/,"#{book_subtitle}").gsub(/BOOKAUTHOR/,"#{book_author}")

# sends file to docraptor for conversion
# currently running in test mode; remove test when css is finalized
cover_pdf = File.join(coverdir, "cover.pdf")
FileUtils.cd(coverdir)
File.open(cover_pdf, "w+b") do |f|
  f.write DocRaptor.create(:document_content => pdf_html,
                           :name             => "cover.pdf",
                           :document_type    => "pdf",
                           :strict			     => "none",
                           :test             => "#{testing_value}",
	                         :prince_options	 => {
	                           :http_user		   => "#{ftp_uname}",
	                           :http_password	 => "#{ftp_pass}"
							             }
                       		)
                           
end

# convert to jpg
final_cover = File.join(coverdir, "#{Metadata.pisbn}_FC.jpg")
`convert -density 150 #{cover_pdf} -quality 100 -sharpen 0x1.0 -resize 600 #{final_cover}`

FileUtils.rm(cover_pdf)

# TESTING

# title should exist
test_title_chars = book_title.scan(/[a-z]/)
test_title_nums = book_title.scan(/[1-9]/)

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