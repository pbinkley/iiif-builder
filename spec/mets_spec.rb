describe Mets do 
   context "when testing the Mets class" do 
      
      mets = Mets.new '/home/pbinkley/Projects/iiif/peelsamples/newspapers/EDB/1918/11/11/articles_1918111101.xml', 'Edmonton Bulletin'

      it "should return 'true' to exists?" do 
         message = mets.exists? 
         expect(message).to eq true
      end
      
      it "should return page count 14" do 
         expect(mets.pages.count).to eq 14
      end
      
      it "should return page 5 id in fifth spot" do
        expect(mets.pages.keys[4]).to eq 'pageModsBib5'
      end

      it "should find 10 articles on page 1" do
        expect(mets.articles['pageModsBib1'].count).to eq 10
      end

      it "should have 3rd article on p.1 with title 'Germany Accepts Terms'" do
        expect(mets.articles['pageModsBib1']['artModsBib_1_4'].xpath('mods:titleInfo/mods:title').first.text).to eq 'Germany Accepts Terms'
      end

      it "should return correct coords for a rect within an article" do
        expect(mets.divs['pageModsBib1']['artModsBib_1_4'][1]).to eq '1211,1029,1738,2258'
      end

      it "should generate text toc correctly" do
        expect(mets.toc_text).to start_with "Page 1\n\n[masthead]\n[unclassified]\nGermany Accepts Terms: Great World War is Brought to End\n"
      end

      it "should generate a well-formed IIIF Range with page for articles" do
        r = mets.articlerange_page('test', 'pageModsBib3', 'artModsBib_3_6')
        expect(r['@id']).to eq 'test/3/range/artModsBib_3_6'
        expect(r['label']).to eq 'Owing to Laxity of City Board of Health, Province to Compel Enforcement of the Health Law: Situation Grows More Serious throughout Province-Many Cases of Epidemic Not Being Reported'
        expect(r['canvases'].count).to eq 1
        expect(r['canvases'][0]).to eq 'test/3'
      end

      it "should generate a well-formed IIIF Range with xywh for articles" do
        r = mets.articlerange_xywh('test', 'pageModsBib3', 'artModsBib_3_6')
        expect(r['@id']).to eq 'test/3/range/artModsBib_3_6'
        expect(r['label']).to eq 'Owing to Laxity of City Board of Health, Province to Compel Enforcement of the Health Law: Situation Grows More Serious throughout Province-Many Cases of Epidemic Not Being Reported'
        expect(r['canvases'].count).to eq 7
        expect(r['canvases'][0]).to eq 'test/3#xywh=1211,1029,1738,2258'
      end

      it "should generate a well-formed JSON page-level toc" do
        r = mets.toc_page('test')
        l = r.last
        expect(r.count).to eq 125
        expect(l['@id']).to eq 'test/14/range/artModsBib_14_8'
      end
   end
end