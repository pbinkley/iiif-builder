require 'nokogiri'
require 'rest-client'
require 'open-uri'
require 'pathname'
require 'byebug'

NAMESPACES = {
  mix: 'http://www.loc.gov/mix/',
  ndnp: 'http://www.loc.gov/ndnp',
  premis: 'http://www.oclc.org/premis',
  mods: 'http://www.loc.gov/mods/v3',
  mets: 'http://www.loc.gov/METS/',
  empty: ''
}.freeze

# This class presents a METS object
class Mets
  attr_reader :publication, :pages, :articles, :divs

  # metsfile is string path to articles METS file
  def initialize(metsfile, publication)
    begin
      @mets = File.open(metsfile) { |f| Nokogiri::XML(f, &:noblanks) }
      @publication = publication
      @exists = true

      # get page mods file in a hash
      @pages = {}
      xpath('/mets:mets/mets:dmdSec[mets:mdWrap/@MDTYPE="MODS"][mets:mdWrap/@LABEL="Page metadata"]').each do |page|
        @pages[page['ID']] = page.xpath('mets:mdWrap/mets:xmlData/mods:mods', NAMESPACES).first
      end

      # get articles under pages
      @articles = {}
      @pages.keys.each do |page|
        @articles[page] = {}
        xpath('/mets:mets/mets:dmdSec[mets:mdWrap/@MDTYPE="MODS"][mets:mdWrap/@LABEL="Article metadata"][mets:mdWrap/mets:xmlData/mods:mods[mods:identifier[@type="firstPage"] = "' + page + '"]]').each do |article|
          @articles[page][article['ID']] = article.xpath('mets:mdWrap/mets:xmlData/mods:mods', NAMESPACES).first
        end
      end

      # get rectangle divs under articles
      structmap = @mets.xpath('/mets:mets/mets:structMap[@TYPE="LOGICAL"]', NAMESPACES).first
      @divs = {}
      @pages.keys.each do |page|
        @divs[page] = {}
        @articles[page].keys.each do |article|
          structmap.xpath('mets:div/mets:div[@DMDID="' + page + '"]/mets:div[@DMDID="' + article + '"]', NAMESPACES).each do |rect|
            rects = []
            rect.xpath('mets:div/mets:fptr/mets:area[@SHAPE="RECT"]/@COORDS', NAMESPACES).each do |coords|
              rects << coords.text
            end
            @divs[page][article] = rects
          end
        end
      end

    rescue RestClient::ExceptionWithResponse
      @exists = false
    end
    return if @exists
  end

  def xpath(xp)
    @mets.xpath(xp, NAMESPACES)
  end

  def mods_issue
    xpath('/mets:mets/mets:dmdSec/mets:mdWrap[@MDTYPE="MODS"][@LABEL="Issue metadata"]/mets:xmlData/mods:mods').first
  end

  def pages
    @pages
  end

  def articles
    @articles
  end

  def divs
    @divs
  end

  def toc_text
    # plain-text table of contents
    output = ''
    @pages.keys.each do |page|
      pagenum = page.gsub(/[a-zA-Z]*/, '')
      output += 'Page ' + pagenum + "\n\n"
      @articles[page].keys.each do |article|
        this = @articles[page][article]
        # join title and subTitle (if any) with ': '
        title = this.xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle', NAMESPACES).to_a.join(': ')
        title = '[' + this.xpath('mods:classification', NAMESPACES).text + ']' unless title != ''
        output += title + "\n" if title != ''
      end
      output += "\n"
    end
    return output
  end

  def toc_page root
    # json table of contents with page-level canvases
    # {
    #  "@id": "{{ site.url }}{{ site.baseurl }}/manifests/EDB-1918-11-11/canvas/3/range/artModsBib_3_6",
    #  "@type": "sc:Range",
    #  "label": "Owing to Laxity of ...",
    #  "canvases": [
    #    "{{ site.url }}{{ site.baseurl }}/manifests/EDB-1918-11-11/canvas/3"
    #  ]
    # }
    output = []
    @pages.keys.each do |page|
      pagenum = page.gsub(/[a-zA-Z]*/, '')
      # could add page-level range here
      @articles[page].keys.each do |article|
        this = @articles[page][article]
        # join title and subTitle (if any) with ': '
        title = this.xpath('mods:titleInfo/mods:title | mods:titleInfo/mods:subTitle', NAMESPACES).to_a.join(': ')
        title = '[' + this.xpath('mods:classification', NAMESPACES).text + ']' unless title != ''
        output << {
          "@id" => root + '/' + pagenum + '/range/' + article,
          "@type" => "sc:Range",
          "label" => title,
          "canvases" => [
            root + '/' + pagenum
          ]
        }
      end
    end
    byebug
    return output
  end

  def articlerange_page root, page, article
    # includes link to single canvas
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
    range['canvases'] << root + '/' + pagenum
    return range
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

  def to_xml
    @mets.to_xml
  end

  def exists?
    @exists
  end
end
