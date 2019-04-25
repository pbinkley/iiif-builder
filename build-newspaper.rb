#!/usr/bin/env ruby

require_relative './lib/iiif-newspaper.rb'
require 'byebug'

manifestname = 'EDB-1918-11-11'
metsname = '/home/pbinkley/Projects/iiif/peelsamples/newspapers/EDB/1918/11/11/articles_1918111101.xml'
publication = 'Edmonton Bulletin'

newspaper = Newspaper.new manifestname, metsname, publication
newspaper.experiment 'Barebones'

File.open('output/' + manifestname + '-manifest.json', 'w') do |f|
  f.write("---\n---\n" + newspaper.manifest.to_json(pretty: true))
end

newspaper.articlerange_page
newspaper.experiment 'TOC in Ranges'

File.open('output/' + manifestname + '-toc-ranges-manifest.json', 'w') do |f|
  f.write("---\n---\n" + newspaper.manifest.to_json(pretty: true))
end
