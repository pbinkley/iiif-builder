#!/usr/bin/env ruby

require_relative './lib/olive-monograph.rb'
require 'byebug'

manifestname = '796'
olivename = '/home/pbinkley/Projects/iiif/peelsamples/bibliography/796/P000796_olive/data/TOC.xml'
publication = 'Peel 796'

monograph = Monograph.new manifestname, olivename, publication
monograph.experiment 'Barebones'

File.open('output/' + manifestname + '-manifest.json', 'w') do |f|
  f.write("---\n---\n" + monograph.manifest.to_json(pretty: true))
end

monograph.datarange_page
monograph.experiment 'Data Range'

File.open('output/' + manifestname + '-datarange-manifest.json', 'w') do |f|
  f.write("---\n---\n" + monograph.manifest.to_json(pretty: true))
end

monograph.search
monograph.experiment 'Data Range + Search'

File.open('output/' + manifestname + '-datarange-search-manifest.json', 'w') do |f|
  f.write("---\n---\n" + monograph.manifest.to_json(pretty: true))
end

