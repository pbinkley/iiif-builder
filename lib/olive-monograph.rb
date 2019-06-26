#!/usr/bin/env ruby

require 'iiif/presentation'
require_relative './olive.rb'
require 'yaml'
require 'byebug'

class Monograph
  attr_accessor :manifest, :olive, :manifestname
  def initialize(manifestname, olivename, publication)

    @olive = Olive.new olivename, publication
    @manifestname = manifestname
    @baselabel = 'Peel ' + @manifestname

    # create skeleton manifest

    @manifest = IIIF::Presentation::Manifest.new({
      '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '.json',
      'label' => publication,
      'logo' => 'https://mobile.ualberta.ca/img/UAlberta_Icon.png',
      'metadata' => [
        {
          "label": "Peel no.",
          "value": [publication]
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

    tileroot = 'https://tiles.library.ualberta.ca/fcgi-bin/iipsrv.fcgi?IIIF=/maps/tileserver/bibliography/' + manifestname.gsub('-', '/') + '/'

    # create IIIF canvases from METS pages

    @olive.pages.each do |page|
      # build a canvas element and insert it into manifest.canvases

      canvas = IIIF::Presentation::Canvas.new()
      # page identifiers in Olive are in the form Pg001
      id = page[0].gsub(/[a-zA-Z]*/, '').to_i.to_s
      canvas['@id'] = '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + id
      canvas.label = 'p. ' + page[1].xpath('@PAGE_LABEL').text

      infourl = tileroot + id + '.tif/info.json'

      response = RestClient.get(infourl)
      imageinfo = JSON.parse(response)

      # note: our NDNP METS do not store the width/height accessibly: they
      # can be calculated from measurements in the ALTO, or extracted from an
      # unstructure text comment
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

    @manifest.sequences << sequence
  end

  def experiment experimentname
    # append experimentname to the raw title of the manifest
    @manifest.label = @baselabel + ' / ' + experimentname
  end

  def datarange_page
    # these article ranges include a link to a single canvas: i.e. they
    # are page-level links

    data = YAML.load_file('P796.yml')
    idlist = []
    rangelist = []
    canvaslist = []
    @olive.pages.each do |page|
      pageid = page[0]
      pagenum = pageid.gsub(/[a-zA-Z]*/, '').to_i.to_s
      datapage = data.select { |p| p['p'].to_s == pagenum }.first
      canvasid = '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + pagenum
      thiscanvas = @manifest['sequences'].first['canvases'].select { |c| c['@id'] == canvasid }.first
      thiscanvas.label = datapage['label']
      canvaslist << canvasid
    end

    # create ranges for sections
    data.select { |p| p['section'] }.each do |section|
  	  rangeid = '{{ site.url }}{{ site.baseurl }}/manifests/' + @manifestname + '/range/sec' + section['p'].to_s
  	  label = section['section']
  	  range = IIIF::Presentation::Range.new ({
  	      '@id' => rangeid,
  	      'label' => label,
  	      'canvases' => ['{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + section['p'].to_s]
  	  })
  	  rangelist << range
  	  idlist << rangeid
  	end

    @manifest.structures = [IIIF::Presentation::Range.new({
      '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/range/r0',
      'label' => 'Table of Contents',
      'viewingHint' => 'top',
      'ranges' => idlist,
      'canvases' => canvaslist
    })] + rangelist
    return true
  end

  def articlerange_xywh root, page, article
    # includes links to all rects as xywh fragments
    a = @articles[page][article]
    d = @divs[page][article]
    pagenum = page.gsub(/[a-zA-Z]*/, '')
    range = {
      '@id' => root + '/' + pagenum + '/range/' + article,
      '@type' => 'sc:Range',
      # join title and subTitle (if any) with ': '
      'label' => a.xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle').to_a.join(': '),
      'canvases' => []
    }
    d.each do |div|
      # convert to xywh i.e. replace second xy with width and height
      coords = div.split(',').map { |v| v.to_i }
      coords[2] = coords[2] - coords[0]
      coords[3] = coords[3] - coords[1]
      # byebug
      range['canvases'] << root + '/' + pagenum + '#xywh=' + coords.map { |v| v.to_s }.join(',')
    end
    return range
  end

  def search
  	@manifest['service'] = [
  	  IIIF::Service.new({
	      '@context' => 'http://iiif.io/api/search/0/context.json',
	      '@id' => '{{ site.url }}{{ site.baseurl }}/annos/search796.json',
	      'profile' => 'http://iiif.io/api/search/0/search',
	      'label' => 'Search within this manifest'
	    })
	]
  end
end
