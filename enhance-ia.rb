#!/usr/bin/env ruby

require 'iiif/presentation'
require 'rest-client'
require 'csv'

require 'byebug'

# load csv with contents data
contents = CSV.read('polychronicon1939.csv', headers: true)

manifest_url='https://iiif.archivelab.org/iiif/polychronicon1939/manifest.json'
manifest_source = RestClient.get(manifest_url)
manifest = IIIF::Service.parse(manifest_source)

id = manifest['@id']
id_root = id.gsub(/^(.*\/).*$/, '\1') # e.g. "https://iiif.archivelab.org/iiif/polychronicon1939/"

manifest.structures = [
  IIIF::Presentation::Range.new(
    {
      '@id' => id_root + 'range/toc',
      'label' => 'Table of Contents',
      'canvases' => []
    }
  )
]

# we will update the manifest with values from the contents
# canvas labels will be overwritten
manifest.sequences.first.canvases.each_with_index do |canvas, index|
  content = contents[index]
  canvas.label = content['label'] if content['label']
  manifest.structures.first.canvases << canvas['@id']
  if content['heading 1']
    manifest.structures <<  IIIF::Presentation::Range.new(
      {
        '@id' => canvas['@id'] + '/range/heading_1',
        'within' => id_root + 'range/toc',
        'label' => content['heading 1'],
        'canvases' => [canvas['@id']]
      }
    )
  end
end

File.open("polychronicon1939-iiif-enhanced.json","w") do |f|
  f.write(manifest.to_json(pretty: true))
end
