require 'rubygems'
require 'doc_raptor'

require_relative '..\\bookmaker\\header.rb'

# --------------------HTML FILE DATA START--------------------
# This block creates a variable to point to the 
# converted HTML file, and pulls the isbn data
# out of the HTML file.

# the working html file
html_file = "#{Bkmkr::Dir.tmp_dir}\\#{Bkmkr::Project.filename}\\outputtmp.html"

# testing to see if ISBN style exists
spanisbn = File.read("#{html_file}").scan(/spanISBNisbn/)
multiple_isbns = File.read("#{html_file}").scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(e-*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  pisbn_basestring = File.read("#{html_file}").match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+<\/span>\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  pisbn_basestring = File.read("#{html_file}").match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
  pisbn_basestring = File.read("#{html_file}").match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  eisbn_basestring = File.read("#{html_file}").match(/spanISBNisbn">\s*.+<\/span>\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+<\/span>\(ebook\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  eisbn_basestring = File.read("#{html_file}").match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
  eisbn_basestring = File.read("#{html_file}").match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# just in case no isbn is found
if pisbn.length == 0
  pisbn = "#{Bkmkr::Project.filename}"
end

if eisbn.length == 0
  eisbn = "#{Bkmkr::Project.filename}"
end
# --------------------HTML FILE DATA END--------------------

# Authentication data is required to use docraptor and 
# to post images and other assets to the ftp for inclusion 
# via docraptor. This auth data should be housed in 
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Dir.bookmaker_dir}\\bookmaker_authkeys\\api_key.txt")
ftp_uname = File.read("#{Bkmkr::Dir.bookmaker_dir}\\bookmaker_authkeys\\ftp_username.txt")
ftp_pass = File.read("#{Bkmkr::Dir.bookmaker_dir}\\bookmaker_authkeys\\ftp_pass.txt")

DocRaptor.api_key "#{docraptor_key}"

# change to DocRaptor 'test' mode when running from staging server
testing_value = "false"
if File.file?("C:/staging.txt") then testing_value = "true" end

coverdir = "#{Bkmkr::Dir.tmp_dir}\\#{Bkmkr::Project.filename}\\images\\"

# template html file
if File.file?("#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\html\\#{Bkmkr::Project.project_dir}\\template.html")
  template_html = "#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\html\\#{Bkmkr::Project.project_dir}\\template.html"
else
  template_html = "#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\html\\generic\\template.html"
end

# pdf css to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\css\\#{Bkmkr::Project.project_dir}\\cover.css")
  cover_css_file = "#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\css\\#{Bkmkr::Project.project_dir}\\cover.css"
else
  cover_css_file = "#{Bkmkr::Dir.bookmaker_dir}\\covermaker\\css\\generic\\cover.css"
end

css_file = File.read("#{cover_css_file}").to_s

book_title = File.read("#{html_file}").scan(/<h1 class="TitlepageBookTitletit">.+?<\/h1>/).to_s.gsub(/<h1 class="TitlepageBookTitletit">/,"").gsub(/<\/h1>/,"").gsub(/\["/,"").gsub(/"\]/,"")

book_author_basestring = File.read("#{html_file}").scan(/<p class="TitlepageAuthorNameau">.*?<\/p>/)

if book_author_basestring.any?
  authorname1 = File.read("#{html_file}").scan(/<p class="TitlepageAuthorNameau">.*?<\/p>/).join(",")
  book_author = authorname1.gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/<\/p>/,"")
else
  authorname1 = " "
  book_author = " "
end

book_subtitle_basestring = File.read("#{html_file}").scan(/<p class="TitlepageBookSubtitlestit">.+?<\/p>/)

if book_subtitle_basestring.any?
  book_subtitle = book_subtitle_basestring.pop.to_s.gsub(/<p class="TitlepageBookSubtitlestit">/,"").gsub(/<\/p>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
  book_subtitle = " "
end

# inserts the css into the head of the html
pdf_html = File.read("#{template_html}").to_s.gsub(/CSSFILEHERE/,"#{css_file}").gsub(/BOOKTITLE/,"#{book_title}").gsub(/BOOKSUBTITLE/,"#{book_subtitle}").gsub(/BOOKAUTHOR/,"#{book_author}")

# sends file to docraptor for conversion
# currently running in test mode; remove test when css is finalized
`chdir #{coverdir}`
File.open("#{coverdir}\\cover.pdf", "w+b") do |f|
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
`convert -density 150 #{coverdir}\\cover.pdf -quality 100 -sharpen 0x1.0 -resize 600 #{coverdir}\\#{pisbn}_FC.jpg`

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

# pdf should exist and have file size > 0
test_pdf_size = File.size("#{coverdir}\\cover.pdf")

if test_pdf_size != 0
  test_filesize_status = "pass: cover pdf appears to have content"
else
  test_filesize_status = "FAIL: cover pdf appears to have content"
end

# cover jpg should exist in tmp dir
if File.file?("#{coverdir}\\#{pisbn}_FC.jpg")
  test_jpg_status = "pass: The cover jpg was successfully created"
else
  test_jpg_status = "FAIL: The cover jpg was successfully created"
end

# cover jpg should be 600px wide

# Printing the test results to the log file
File.open("#{Bkmkr::Dir.log_dir}\\#{Bkmkr::Project.filename}.txt", 'a+') do |f|
  f.puts "----- COVERMAKER PROCESSES"
  f.puts test_title_status
  f.puts test_filesize_status
  f.puts test_jpg_status
end