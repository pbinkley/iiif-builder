#!/usr/bin/env ruby

require 'iiif/presentation'
require 'rest-client'
require 'csv'

require 'byebug'

ia_id = ARGV[0]
abort 'Provide Internet Archive id' unless ia_id

# load csv with contents data
contents = CSV.read(ia_id + '.csv', headers: true)
# get list of headings in the csv: ['h1', 'h2', ...]
headings = contents.first.to_hash.keys.select{ |i| i[/h\d+/] }

# fetch and parse IA's manifest
manifest_url='https://iiif.archivelab.org/iiif/' + ia_id + '/manifest.json'
manifest_source = RestClient.get(manifest_url)
manifest = IIIF::Service.parse(manifest_source)

# update manifest @id to the url it will occupy
manifest['@id'] = 'https://archive.org/download/' + ia_id + '/iiif-manifest-enhanced.json'

id = manifest['@id']
id_root = id.gsub(/^(.*)\.json$/, '\1') + '/' # e.g. "https://iiif.archivelab.org/iiif/polychronicon1939/"

# correct the @context - IA manifests incorrectly use the image @context
# (see https://github.com/ArchiveLabs/iiif.archivelab.org/issues/37)
manifest['@context'] = 'http://iiif.io/api/presentation/2/context.json'
manifest.sequences.first['@context'] = 'http://iiif.io/api/presentation/2/context.json'

range_counter = 0

# create top-level range
manifest.structures = [
  IIIF::Presentation::Range.new(
    {
      '@id' => id_root + 'range/toc',
      'label' => 'Table of Contents',
      'viewingHint' => 'top',
      'ranges' => [],
      'canvases' => []
    }
  )
]

# accumlators: a hash pointing to currently-open ranges at all levels, into which
# canvases and new subranges should be inserted
accumulators = {
  toc: manifest.structures.first
}

# we will update the manifest with values from the contents .csv file
manifest.sequences.first.canvases.each_with_index do |canvas, index|
  # get row from contents.csv
  content = contents[index]
  # canvas labels will be overwritten
  canvas.label = content['label'] if content['label']
  
  # iterate through the headings (h1, h2, ...) and look for content
  headings.each_with_index do |heading, heading_index|
    if content[heading]
      # we have a heading text, so create a range
      range_id = id_root + 'range/r' + range_counter.to_s
      manifest.structures <<  IIIF::Presentation::Range.new(
        {
          '@id' => range_id,
          'label' => content[heading],
          'ranges' => [],
          'canvases' => []
        }
      )
      # insert new range into appropriate accumulator
      if heading == 'h1'
        accumulators[:toc]['ranges'] << range_id
      else
        accumulators[headings[heading_index - 1]]['ranges'] << range_id
      end
      # make the new range the accumulator for this heading, to receive
      # subranges and canvases
      accumulators[heading] = manifest.structures.last
      # since we have a new range at this level, remove all lower-level
      # accumulators: they close when their parents close
      headings[heading_index + 1 .. headings.count].each do |subheading|
        accumulators[subheading] = nil
      end
      range_counter += 1
    end
    # add this canvas to the appropriate accumulators
    accumulators[heading].canvases << canvas['@id'] if accumulators[heading]
  end
  # always add canvas to top-level range
  accumulators[:toc].canvases << canvas['@id']
end

# ranges should contain subranges or canvases, but not both
# so we discard canvases from ranges that include subranges
manifest.structures.each do |range|
  if range.ranges.count > 0
    range.delete 'canvases'
  else
    range.delete 'ranges'
  end
end

FileUtils.mkdir_p ia_id
File.open(ia_id + '/iiif-manifest-enhanced.json', 'w') do |f|
  f.write(manifest.to_json(pretty: true))
end
