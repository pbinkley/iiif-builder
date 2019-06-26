#!/usr/bin/env ruby

require 'iiif/presentation'
require_relative './mets.rb'
require 'byebug'

class Newspaper
  attr_accessor :manifest, :mets, :manifestname
  def initialize(manifestname, metsname, publication, doimages)

    @mets = Mets.new metsname, publication
    @manifestname = manifestname
    
    FileUtils.mkdir_p 'output/' + manifestname + '/annos'
    
    # get issue-level metadata from METS
    mods = @mets.mods_issue

    part = mods.xpath('mods:relatedItem/mods:part').first
    volume = part.xpath('mods:detail[@type="volume"]').text
    issue = part.xpath('mods:detail[@type="issue"]').text
    volume = part.xpath('mods:detail[@type="volume"]').text
    edition = part.xpath('mods:detail[@type="edition"]/mods:caption').text
    date = mods.xpath('mods:originInfo/mods:dateIssued').first.text
    @baselabel = publication + ': ' + date + ', ' + edition

    # create skeleton manifest

    @manifest = IIIF::Presentation::Manifest.new({
      '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '.json',
      'label' => @baselabel,
      'logo' => 'https://mobile.ualberta.ca/img/UAlberta_Icon.png',
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

    # create IIIF canvases from METS pages

    @mets.pages.each_with_index do |page, index|
      # build a canvas element and insert it into manifest.canvases

      canvas = IIIF::Presentation::Canvas.new()
      # page identifiers in our NDNP METS are in the form PageModsBib1
      id = page[0].gsub(/[a-zA-Z]*/, '')
      canvas['@id'] = '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + id
      canvas.label = 'p. ' + id

      infourl = tileroot + id + '.tif/info.json'

      if doimages
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
      else
        # dummy image values
        canvas.width = 666
        canvas.height = 666
        canvas.images = [
          IIIF::Presentation::Annotation.new({
            '@context' => 'http://iiif.io/api/presentation/2/context.json',
            'resource' => IIIF::Presentation::Resource.new({
              '@id' => index.to_s,
              '@type' => 'dctypes:Image',
              'format' => 'image/jpeg',
              'service' => {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "https://iiif.iiif/" + index.to_s,
                  "profile": "https://iiif.io/api/image/2/profiles/level2.json"
                },
              'height' => 666,
              'width' => 666
            }),
            'on' => canvas['@id']
          })
        ]
      end

      sequence.canvases << canvas
    end

    @manifest.sequences << sequence
  end

  def experiment experimentname
    # append experimentname to the raw title of the manifest
    @manifest.label = @baselabel + ' / ' + experimentname
  end

  def articlerange_page
    # these article ranges include a link to a single canvas: i.e. they
    # are page-level links
    idlist = []
    rangelist = []
    canvaslist = []
    @mets.pages.each do |page|
      pageid = page[0]
      pagenum = pageid.gsub(/[a-zA-Z]*/, '')
      canvaslist << '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + pagenum
      @mets.articles[pageid].each do |article|
        articleid = article[0]
        rangeid = '{{ site.url }}{{ site.baseurl }}/manifests/' + @manifestname + '/canvas/p' + pagenum + '/range/' + articleid
        # join title and subTitle (if any) with ': '
        label = article[1].xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle', NAMESPACES).to_a.join(': ')
        # use classification if there's no title
        label = '[' + article[1].xpath('mods:classification').text + ']' if label == ''
        range = IIIF::Presentation::Range.new ({
          '@id' => rangeid,
          'label' => label,
          'canvases' => ['{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/canvas/p' + pagenum]
        })
        rangelist << range
        idlist << rangeid
      end
    end
    @manifest.structures = [IIIF::Presentation::Range.new({
      '@id' => '{{ site.url }}{{ site.baseurl }}/manifests/' + manifestname + '/range/r0',
      'label' => '',
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
      'label' => a.xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle', NAMESPACES).to_a.join(': '),
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

  def headline_annotations
    # generate page-level annotations containing headlines with xywh
    @mets.pages.each do |page|
      pageid = page[0]
      pagenum = pageid.gsub(/[a-zA-Z]*/, '')

      resources = []

      @mets.articles[pageid].each do |article|
        articleid = article[0]
        headlineid = '{{ site.url }}{{ site.baseurl }}/manifests/' + @manifestname + '/annos/p' + pagenum + '/headline/' + articleid
        # join title and subTitle (if any) with ': '
        label = article[1].xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle', NAMESPACES).to_a.join(': ')
        # use classification if there's no title
        label = '[' + article[1].xpath('mods:classification').text + ']' if label == ''

        resource = IIIF::Presentation::Resource.new(
          {
          '@id' => headlineid + '/text',
          '@type' => 'cnt:ContentAsText',
          'format' => 'text/plain',
          'chars' => label
          }
        )

        # get xywh of first div
        puts articleid
        topDivXYWH = @mets.divs[pageid][articleid]
        if topDivXYWH
          anno = IIIF::Presentation::Annotation.new(
            {
            '@id' => headlineid,
            'motivation' => 'oa:commenting',
            'on' => '{{ site.url }}{{ site.baseurl }}/manifests/' + @manifestname + '/canvas/p' + pagenum + '#xywh=' + topDivXYWH.first,
            'resource' => resource
            }
          )

          resources << anno
        else
          puts articleid + ': no divs'
        end
      end
      annolist = IIIF::Presentation::AnnotationList.new( {
        '@context' =>  'http://iiif.io/api/presentation/2/context.json',
        '@id' => '{{ site.url }}{{ site.baseurl }}/' + manifestname + '/annos/page-' + pagenum + '.json',
        'resources' => resources
      })

      File.open('output/' + manifestname + '/annos/page-' + pagenum + '.json', 'w') do |f|
        f.write("---\n---\n" + annolist.to_json(pretty: true))
      end

      # add page-level links to annotation lists
      @manifest['sequences'][0]['canvases'][pagenum.to_i - 1]['otherContent'] =
[IIIF::Presentation::AnnotationList.new(
        {
          '@id' => '{{ site.url }}{{ site.baseurl }}/annos/' + manifestname + '/page-' + pagenum + '.json'
        }
      )]
    end
  end
end
