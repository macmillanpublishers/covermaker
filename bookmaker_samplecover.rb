require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# Local path var(s)
configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# the cover filename
project_dir = data_hash['project']
stage_dir = data_hash['stage']

coverdir = Bkmkr::Paths.submitted_images
overlay = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "images", "sample", "overlay.png")
coverfile = File.join(coverdir, Metadata.frontcover)

final_cover = File.join(coverdir, "#{Metadata.pisbn}_FC.jpg")

# create cover with overlay
`composite -gravity SouthWest #{overlay} #{coverfile} #{final_cover}`

# resize
`convert -density 150 #{final_cover} -quality 100 -sharpen 0x1.0 -resize 600 #{final_cover}`

# TESTING

# cover jpg should exist in tmp dir
if File.file?(final_cover)
  test_jpg_status = "pass: The cover jpg was successfully created"
else
  test_jpg_status = "FAIL: The cover jpg was successfully created"
end

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- COVERMAKER PROCESSES"
  f.puts test_title_status
  f.puts test_jpg_status
end