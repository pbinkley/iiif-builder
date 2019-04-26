describe Newspaper do 
  context "when testing the Newspaper class" do 

    newspaper = Newspaper.new 'EDB-1918-11-11', '/home/pbinkley/Projects/iiif/peelsamples/newspapers/EDB/1918/11/11/articles_1918111101.xml', 'Edmonton Bulletin'

    it "should return have correct label" do  
       expect(newspaper.mets.label).to eq 'Edmonton Bulletin: 1918-11-11, CITY EDITION'
    end
  end
end
