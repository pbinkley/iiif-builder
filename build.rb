#!/usr/bin/env ruby

require 'json'
require 'rest-client'

require 'byebug'

rootpath = ARGV[0]
imagecount = ARGV[1].to_i

manifest = JSON.parse(File.read('minimal-manifest.json'))
canvases = manifest['sequences'].first['canvases']

(1..imagecount).each do |image|
  puts image.to_s
  url = rootpath + image.to_s + '.tif/info.json'
  response = RestClient.get(url)
  imageinfo = JSON.parse(response)

  canvas = {
          "@id": rootpath + image.to_s + '/canvas', 
          "@type": "sc:Canvas", 
          "label": image.to_s, 
          "height": imageinfo['height'], 
          "width": imageinfo['width'], 
          "images": [
            {
              "@type": "oa:Annotation", 
              "motivation": "sc:painting", 
              "resource": {
                "@id": rootpath + image.to_s + '.tif', 
                "@type": "dctypes:Image", 
                "height": imageinfo['height'], 
                "width": imageinfo['width'], 
              }, 
              "on": rootpath + image.to_s + '/canvas'
            }
          ]
        }

  canvases << canvas
  puts imageinfo['width'].to_s + 'x' + imageinfo['height'].to_s
end

File.open('output-manifest.json', 'w') do |f|
  f.write(JSON.pretty_generate(manifest))
end
