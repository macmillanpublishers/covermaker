var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var newfile = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  var output = $('section[data-type="titlepage"]');
    fs.writeFile(newfile, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});