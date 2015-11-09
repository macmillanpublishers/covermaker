function addCoverMetadata() {
  var booktitle = document.getElementById('booktitle');
  var booksubtitle = document.getElementById('booksubtitle');
  var bookauthor = document.getElementById('bookauthor');
  var titletext = "BKMKRINSERTBKTITLE";
  var textnode = document.createTextNode(titletext);
  booktitle.appendChild(textnode);
  var subtitletext = "BKMKRINSERTBKSUBTITLE";
  textnode = document.createTextNode(subtitletext);
  booksubtitle.appendChild(textnode);
  var authortext = "BKMKRINSERTBKAUTHOR";
  textnode = document.createTextNode(authortext);
  bookauthor.appendChild(textnode);
}

window.onload = function() {
  addCoverMetadata();
};