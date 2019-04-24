#!/usr/bin/env ruby

require 'iiif/presentation'
require_relative './lib/mets.rb'
require 'byebug'

manifestname = 'EDB-1918-11-11'

mets = Mets.new '/home/pbinkley/Projects/iiif/peelsamples/newspapers/EDB/1918/11/11/articles_1918111101.xml', 'Edmonton Bulletin'

mods = mets.mods_issue

publication = mets.publication
part = mods.xpath('mods:relatedItem/mods:part').first
volume = part.xpath('mods:detail[@type="volume"]').text
issue = part.xpath('mods:detail[@type="issue"]').text
volume = part.xpath('mods:detail[@type="volume"]').text
edition = part.xpath('mods:detail[@type="edition"]/mods:caption').text
date = mods.xpath('mods:originInfo/mods:dateIssued').first.text

manifest = IIIF::Presentation::Manifest.new({
  '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '.json',
  'label' => publication + ': ' + date + ', ' + edition,
  'logo' => '{{ site.url }}{{ site.baseurl }}/assets/logo.png',
  'metadata' => [
    {
      "label": "Publication",
      "value": [publication]
    },
    {
      "label": "Date",
      "value": [date]
    },
    {
      "label": "Volume",
      "value": [volume]
    },
    {
      "label": "Issue",
      "value": [issue]
    },
    {
      "label": "Edition",
      "value": [edition]
    }
  ],
  'description' => [
    {
      '@value' => 'Experimental manifest',
      '@language' => 'en'
    }
  ],
  'license' => 'https://creativecommons.org/licenses/by/3.0/',
  'attribution' => 'University of Alberta Libraries',
  'sequences' => []
})

sequence = IIIF::Presentation::Sequence.new({
  '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/sequence/s1',
  'canvases' => []
})

tileroot = 'https://tiles.library.ualberta.ca/fcgi-bin/iipsrv.fcgi?IIIF=/maps/tileserver/newspapers/' + manifestname.gsub('-', '/') + '/'

mets.pages.each do |page|
  # build a canvas element and insert it into manifest.canvases

  canvas = IIIF::Presentation::Canvas.new()
  # page identifiers in our NDNP METS are in the form PageModsBib1
  id = page[0].gsub(/[a-zA-Z]*/, '')
  canvas['@id'] = '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + id
  canvas.label = 'p. ' + id

  infourl = tileroot + id + '.tif/info.json'

  response = RestClient.get(infourl)
  imageinfo = JSON.parse(response)

  canvas.width = imageinfo['width']
  canvas.height = imageinfo['height']

  # note: we're storing the whole info.json response as the service element.
  # This saves time for the client, but it means we'll have to regenerate
  # the manifest if the image service changes (upgrade to tileserver etc.)
  canvas.images = [
    IIIF::Presentation::Annotation.new({
      '@context' => 'http://iiif.io/api/presentation/2/context.json',
      'resource' => IIIF::Presentation::Resource.new({
        '@id' => infourl,
        '@type' => 'dctypes:Image',
        'format' => 'image/jpeg',
        'service' => imageinfo,
        'height' => imageinfo['height'],
        'width' => imageinfo['width']
      }),
      'on' => canvas['@id']
    })
  ]
  
  sequence.canvases << canvas
end

manifest.sequences << sequence

File.open('output/' + manifestname + '-output-manifest.json', 'w') do |f|
  f.write(manifest.to_json(pretty: true))
end
