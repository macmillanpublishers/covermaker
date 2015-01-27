require 'rubygems'
require 'doc_raptor'

DocRaptor.api_key "***REMOVED***"

input_file = ARGV[0]
filename_split = input_file.split("\\").pop
filename = filename_split.split(".").shift.gsub(/ /, "")
working_dir_split = ARGV[0].split("\\")
working_dir = working_dir_split[0...-2].join("\\")
project_dir = working_dir_split[0...-3].pop
# determine current working volume
`cd > currvol.txt`
currpath = File.read("currvol.txt")
currvol = currpath.split("\\").shift

# set working dir based on current volume
tmp_dir = "#{currvol}\\bookmaker_tmp"
coverdir = "#{tmp_dir}\\#{filename}\\"

html_file = "#{tmp_dir}\\#{filename}\\outputtmp.html"

# template html file
template_html = "S:\\resources\\covermaker\\html\\#{project_dir}\\template.html"

# pdf css to be added to the file that will be sent to docraptor
css_file = File.read("S:\\resources\\covermaker\\css\\#{project_dir}\\cover.css").to_s

# pulling cover metadata from html file
eisbn_basestring = File.read("#{html_file}").scan(/ISBN\s*.+\s*\(e-book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
eisbn = eisbn_basestring.scan(/\d+\(ebook\)/).to_s.gsub(/\(ebook\)/,"").gsub(/\["/,"").gsub(/"\]/,"")

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
                           :test             => true,
	                         :prince_options	 => {
	                           :http_user		   => "bookmaker",
	                           :http_password	 => "***REMOVED***"
							             }
                       		)
                           
end

# convert to jpg
`convert -density 150 #{coverdir}\\cover.pdf -quality 100 -sharpen 0x1.0 -resize 600 #{coverdir}\\cover.jpg`