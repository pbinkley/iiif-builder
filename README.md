Ruby scripts to create or enhance IIIF manifests for various library digitization formats.

### build.rb

Add canvases to a bare-bones manifest by pulling ```info.json``` from a tile server for
each of a specified number of page-level tiffs.

### build-monograph.rb

Uses ```lib/olive-monograph.rb``` to build three progressively more complex manifests for
an Olive-format monograph. It will pull ```info.json``` responses from UAlberta Library's
tile server for an experimental Olive item to populate the canvases.

The progressive enhancements are defined in methods in ```lib/olive-monograph.md```

#### datarange_page


#### articlerange_xywh root, page, article


####  search


### build-newspaper.rb

Uses ```lib/iiif-newspaper.rb``` to build manifests for a METS/ALTO newspaper issue.

### enhance-ia.rb

Enhances an Internet Archive manifest with content labels and ranges derived from a csv file.
Each row in the csv represents a page, and has a ```label``` column populated with the page
number or other page label ('Cover' etc.), and heading columns labeled ```h1```, ```h2```, etc.
(the script does not limit the number), which should contain section titles of various levels
(see [polychronicon1939.csv](polychronicon1939.csv)
for an example). Each section title will be converted into a range, with lower-level headings
nested within the preceding higher-level heading. The ```@id``` of the enhanced manifest
is designed to allow it to be uploaded into the Internet Archive object as ```iiif-manifest-enhanced.json```
and served from there.