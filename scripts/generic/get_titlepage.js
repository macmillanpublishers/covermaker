var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var newfile = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  if ( $('.TitlepageBookSubtitlestit + .TitlepageAuthorNameau').length ) {
    $('section[data-type="titlepage"]').addClass("anthology");
  };

  if ( $('.TitlepageLogologo').length ) {
    var logoimg = '<img src="https://raw.githubusercontent.com/macmillanpublishers/bookmaker_assets/master/pdfmaker/images/RESOURCEDIR/logo.jpg"></img>';
    $('.TitlepageLogologo').empty().append(logoimg);
    console.log('YES');
  } else { 
    var logoholder = '<p class="TitlepageLogologo"><img src="https://raw.githubusercontent.com/macmillanpublishers/bookmaker_assets/master/pdfmaker/images/RESOURCEDIR/logo.jpg"/></p>';
    $('section[data-type="titlepage"]').append(logoholder);
    console.log('NO');
  };

  var content = $('section[data-type="titlepage"]');
  var $body = $( '<body></body>' );
  $body.append(content)
  var $head = $( '<head></head>' );
  $head.append( $('<title>Generated Titlepage</title>') );
  var output = $('html').empty().append( $head, $body );
    fs.writeFile(newfile, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});