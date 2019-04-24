#!/usr/bin/env ruby

require_relative './lib/iiif-newspaper.rb'
require 'byebug'

manifestname = 'EDB-1918-11-11'
metsname = '/home/pbinkley/Projects/iiif/peelsamples/newspapers/EDB/1918/11/11/articles_1918111101.xml'
publication = 'Edmonton Bulletin'

newspaper = Newspaper.new manifestname, metsname, publication

File.open('output/' + manifestname + '-output-manifest.json', 'w') do |f|
  f.write(newspaper.manifest.to_json(pretty: true))
end
