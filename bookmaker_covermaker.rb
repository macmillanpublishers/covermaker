ENV["NLS_LANG"] = "AMERICAN_AMERICA.WE8MSWIN1252"

require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")
watermark_css = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "css", "generic", "watermark.css")
cover_pdf_html = File.join(Bkmkr::Paths.project_tmp_dir, "cover_pdf.html")

# Authentication data is required to use docraptor and
# to post images and other assets to the ftp for inclusion
# via docraptor. This auth data should be housed in
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
# ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
# ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
# ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"

DocRaptor.api_key "#{docraptor_key}"

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

coverdir = Bkmkr::Paths.project_tmp_dir_submitted
archivedir = File.join(Metadata.final_dir, "cover")

# ---------------------- METHODS

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

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def chooseHTML(project_dir, stage_dir, logkey='')
  # template html file
  if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/#{stage_dir}.html")
    template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/#{stage_dir}.html"
  elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html")
    template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/#{project_dir}/template.html"
  else
    template_html = "#{Bkmkr::Paths.scripts_dir}/covermaker/html/generic/template.html"
  end
  return template_html
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def chooseCSS(project_dir, stage_dir, logkey='')
  # pdf css to be added to the file that will be sent to docraptor
  if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/#{stage_dir}.css")
    cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/#{stage_dir}.css"
  elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css")
    cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/cover.css"
  else
    cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/generic/cover.css"
  end
  return cover_css_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getEmbedCSS(cover_css_file, logkey='')
  embedcss = File.read(cover_css_file).gsub(/(\\)/,"\\0\\0").to_s
  return embedcss
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def chooseJs(project_dir, stage_dir, logkey='')
  # pdf js to be added to the file that will be sent to docraptor
  if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/#{stage_dir}.js")
    cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/#{stage_dir}.js"
  elsif File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/cover.js")
    cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/#{project_dir}/cover.js"
  else
    cover_js_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/scripts/generic/cover.js"
  end
  return cover_js_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def updateHTMLmetainfo(template_html, booktitle, booksubtitle, authorname, resource_dir, logkey='')
  pdf_html_contents = File.read(template_html).gsub(/BKMKRINSERTBKTITLE/,"#{booktitle}")
                                          .gsub(/BKMKRINSERTBKSUBTITLE/,"#{booksubtitle}")
                                          .gsub(/BKMKRINSERTBKAUTHOR/,"#{authorname}")
                                          .gsub(/RESOURCEDIR/,"#{resource_dir}")
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

# detect whether the cover was autogenerated or not
def detectAutoGeneratedCover(coverlog, final_cover, archived_cover, logkey='')
  gen = false
  if File.file?(coverlog) and !File.file?(final_cover)
    gen = true
    Mcmlln::Tools.deleteFile(coverlog)
    Mcmlln::Tools.deleteFile(archived_cover)
  elsif File.file?(coverlog) and File.file?(final_cover)
    gen = false
    Mcmlln::Tools.deleteFile(coverlog)
    Mcmlln::Tools.deleteFile(archived_cover)
  elsif !File.file?(coverlog) and !File.file?(final_cover) and !File.file?(archived_cover)
    gen = true
  end
  return gen
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def watermarkCover(watermark, watermarktmp, final_cover, logkey='')
  FileUtils.cp(watermark, watermarktmp)
  markcover = final_cover
  markcovername = Metadata.frontcover
  targetwidth = `identify -format "%w" "#{final_cover}"`
  targetwidth = targetwidth.to_f
  currwidth = `identify -format "%w" "#{watermarktmp}"`
  currwidth = currwidth.to_f
  shave = (currwidth - targetwidth) / 2
  `convert "#{watermarktmp}" -shave #{shave}x0 -quality 100 "#{watermarktmp}"`
  `convert "#{watermarktmp}" "#{final_cover}" -append -border 3x3 "#{final_cover}"`
  FileUtils.rm(watermarktmp)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def generateCover(coverdir, cover_pdf, pdf_html_contents, pdf_html_file, cover_css_file, testing_value, watermark_css, logkey='')
  if Bkmkr::Tools.os == "mac" or Bkmkr::Tools.os == "unix"
    princecmd = "prince"
  elsif Bkmkr::Tools.os == "windows"
    princecmd = File.join(Bkmkr::Paths.resource_dir, "Program Files (x86)", "Prince", "engine", "bin", "prince.exe")
    princecmd = "\"#{princecmd}\""
  end
  if Bkmkr::Tools.pdfprocessor == "prince"
    if !Bkmkr::Keys.http_username.empty? && !Bkmkr::Keys.http_password.empty?
      princecmd = "#{princecmd} -s \"#{cover_css_file}\" --javascript --http-user=#{Bkmkr::Keys.http_username} --http-password=#{Bkmkr::Keys.http_password} \"#{pdf_html_file}\" -o \"#{cover_pdf}\""
    else
      princecmd = "#{princecmd} -s \"#{cover_css_file}\" --javascript \"#{pdf_html_file}\" -o \"#{cover_pdf}\""
    end
    if testing_value == "true"
      princecmd = "#{princecmd} -s \"#{watermark_css}\""
    end
    output = `#{princecmd}`
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

def convertGeneratedCover(cover_pdf, final_cover, logkey='')
  `convert -density 150 -colorspace sRGB "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 -background white -flatten "#{final_cover}"`
  # sleep is to prevent intermittent permission errors when deleting the PDF post-conversion
  sleep 5
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

def writeCoverLog(coverlog, logkey='')
  File.open(coverlog, 'w+') do |f|
    f.puts Time.now
    f.puts "cover generated from document metadata"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def covermakerTests(booktitle, final_cover, logkey='')
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
  return test_title_status, test_jpg_status
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')

#local definition(s) based on config.json (cover filename and metadata)
project_dir = data_hash['project']
stage_dir = data_hash['stage']
resource_dir = data_hash['resourcedir']

# run method: testingValue
testing_value = testingValue(testing_value_file, 'testing_value_test')
@log_hash['running_on_testing_server'] = testing_value

puts "RUNNING COVERMAKER"

# template html file
template_html = chooseHTML(project_dir, stage_dir, 'choose_html')
@log_hash['template_html'] = template_html

# pdf css to be added to the file that will be sent to docraptor
cover_css_file = chooseCSS(project_dir, stage_dir, 'choose_cover_css')
@log_hash['cover_css_file'] = cover_css_file

embedcss = getEmbedCSS(cover_css_file, 'get_embed_css')

# pdf js to be added to the file that will be sent to docraptor
cover_js_file = chooseJs(project_dir, stage_dir, 'choose_cover_js_file')
@log_hash['cover_js_file'] = cover_js_file

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

# update metainfo placeholders in html template
pdf_html_contents = updateHTMLmetainfo(template_html, booktitle, booksubtitle, authorname, resource_dir, 'update_html_metainfo')

# write updated html back to file for prince conversion
overwriteHtml(cover_pdf_html, pdf_html_contents, 'write_updated_templateHTML_to_file')

# prepare raw html with embedcss for Docraptor conversion
pdf_html_contents = embedCSSinHTML(pdf_html_contents, embedcss, 'embed_css_in_html')

# pdf_html = editPdfHtml(template_html, embedcss, booktitle, booksubtitle, authorname, resource_dir, 'edit_pdf_html')

final_cover = File.join(coverdir, Metadata.frontcover)
archived_cover = File.join(archivedir, Metadata.frontcover)
watermark = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "images", "disclaimer.jpg")
watermarktmp = File.join(archivedir, "disclaimer.jpg")

logdir = File.join(Metadata.final_dir, "logs")
coverlog = File.join(logdir, "cover.txt")

# detect whether the cover was autogenerated or not
gen = detectAutoGeneratedCover(coverlog, final_cover, archived_cover, 'detect_auto-generated_cover')
@log_hash['gen(erate_cover)_value'] = gen


# generate cover, watermark existing cover, or skip
if File.file?(final_cover)
  @log_hash['cover_status'] = "Found submitted cover; watermarking."
  watermarkCover(watermark, watermarktmp, final_cover, 'watermark_final_cover')
elsif File.file?(archived_cover) and gen == false
  @log_hash['cover_status'] = "Found existing cover; skipping conversion."
elsif gen == true
  @log_hash['cover_status'] = "Generating cover."
  cover_pdf = File.join(coverdir, "cover.pdf")
  # convert to pdf via prince or docraptor
  generateCover(coverdir, cover_pdf, pdf_html_contents, cover_pdf_html, cover_css_file, testing_value, watermark_css, 'generate_cover')
  # convert to jpg
  convertGeneratedCover(cover_pdf, final_cover, 'convert_generated_cover_to_jpg')
  # delete the PDF
  rmFile(cover_pdf, 'rm_cover_pdf')

  makeFolder(logdir, 'create_logdir_as_needed')

  writeCoverLog(coverlog, 'write_cover_logfile')
end
puts @log_hash['cover_status']

puts "FINISHED COVERMAKER"

# covermaker tests
test_title_status, test_jpg_status = covermakerTests(booktitle, final_cover, 'covermaker_tests')
@log_hash['test_title_status'] = test_title_status
@log_hash['test_jpg_status'] = test_jpg_status

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
