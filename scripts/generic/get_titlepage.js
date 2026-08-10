var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var newfile = process.argv[3];
var doctemplatetype = process.argv[4];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  //vars for target stylenames based on doctemplatetype
  if (doctemplatetype == 'rsuite') {
    var anthologyselector = 'section[data-type="titlepage"] > .SubtitleSttl + .Author1Au1'
    var logo_stylename = 'Logo-PlacementLogo'
  } else {
    var anthologyselector = '.TitlepageBookSubtitlestit + .TitlepageAuthorNameau'
    var logo_stylename = 'TitlepageLogologo'
  }

  if ( $(anthologyselector).length ) {
    $('section[data-type="titlepage"]').addClass("anthology");
  };

  if ( $('.' + logo_stylename).length ) {
    var logoimg = '<img src="S:/resources/bookmaker_scripts/bookmaker_assets/pdfmaker/images/RESOURCEDIR/logo.jpg"></img>';
    $('.' + logo_stylename).empty().append(logoimg);
  } else {
    var logoholder = '<p class="' + logo_stylename + '"><img src="S:/resources/bookmaker_scripts/bookmaker_assets/pdfmaker/images/RESOURCEDIR/logo.jpg"/></p>';
    $('section[data-type="titlepage"]').append(logoholder);
  };

  var content = $('section[data-type="titlepage"]');
  var $body = $( '<body></body>' );
  $body.append(content)
  var $head = $( '<head></head>' );
  $head.append( $('<title>Generated Titlepage</title>') );

  // replace html with new head and body
  $('html').empty().append( $head, $body );
  
  var output = $.html();
    fs.writeFile(newfile, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});
