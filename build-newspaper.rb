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

seed = {
  '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '.json',
  'label' => publication + ': ' + date + ', ' + edition,
  'logo' => '{{ site.url }}{{ site.baseurl }}/assets/logo.png'
}

manifest = IIIF::Presentation::Manifest.new(seed)

tileroot = 'https://tiles.library.ualberta.ca/fcgi-bin/iipsrv.fcgi?IIIF=/maps/tileserver/newspapers/' + manifestname.gsub('-', '/') + '/'

mets.pages.each do |page|
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

  canvas.images = [
    {
      "@context": "http://iiif.io/api/presentation/2/context.json",
      "@id": "{{ site.url }}{{ site.baseurl }}/manifests/" + manifestname + "/annotation/p" + id.rjust(4, '0') + '-image'
      "@type": "oa:Annotation",
      "motivation": "sc:painting",
      "resource": {
        "@id": infourl,
        "@type": "dctypes:Image",
        "format": "image/jpeg",
        # note: embedding the whole info.json response in the service property 
        # is permitted, but not required. It saves the client having to fetch
        # the info.json separately, but it means updating the manifest when
        # the tile service changes.
        "service": imageinfo,
        "height": imageinfo['height'],
        "width": imageinfo['width']
      },
      "on": canvas['@id']
    }
  ]
  manifest.sequences << canvas
end

File.open(manifestname + '-output-manifest.json', 'w') do |f|
  f.write(manifest.to_json(pretty: true))
end
