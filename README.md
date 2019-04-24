# UniVis
Interactive visualization to evaluate the performance of Italian universities, based on the questionnaires given to students by [AlmaLaurea](https://www2.almalaurea.it/cgi-php/universita/statistiche/tendine.php?LANG=it&config=profilo). 

Data of the University of Bari and the Polytechnic of Bari are provided, but other data provided by AlmaLaurea can also be used.

## How to use
First, install [Dart SDK](https://webdev.dartlang.org/tools/sdk#install)

Active the package webdev
```
pub global activate webdev
webdev
```
If this doesn't work, you may need to set up your path.

Gets all the dependencies listed in [pubspec.yaml](pubspec.yaml)
```
pub get
```
Start server
```
webdev serve
```
In your browser go to http://localhost:8080/up_index.html to use the visualization
