require 'nokogiri'
require 'rest-client'
require 'open-uri'
require 'pathname'
require 'byebug'

# This class presents a METS object
class Olive
  attr_reader :publication, :pages, :articles, :divs

  # metsfile is string path to articles METS file
  def initialize(olivefile, publication)
    @olive = File.open(olivefile) { |f| Nokogiri::XML(f, &:noblanks) }
    @publication = publication

    # get page mods file in a hash
    @pages = {}
    xpath('/Xmd_toc/Body_np/Section/Page').each do |page|
      @pages[page['ID']] = page
    end
  end

  def xpath(xp)
    @olive.xpath(xp)
  end

  def pages
    @pages
  end

  def to_xml
    @olive.to_xml
  end

end
