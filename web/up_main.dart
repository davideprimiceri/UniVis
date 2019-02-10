import 'dart:html';
import 'package:color/color.dart';

CanvasElement canvas = document.querySelector('#canvas');
CanvasRenderingContext2D context = canvas.getContext('2d');
CanvasElement canvasOverlay = document.querySelector('#canvasOverlay');
CanvasRenderingContext2D contextOverlay = canvasOverlay.getContext('2d');
FileUploadInputElement selectFolder = document.querySelector('#selectFolder');
InputElement minYear = document.querySelector('#minYear');
InputElement maxYear = document.querySelector('#maxYear');
ButtonElement vis = document.querySelector('#vis');
CheckboxInputElement long = document.querySelector('#long');
InputElement nG = document.querySelector('#numGroups');
List<CheckboxInputElement> satisfaction = [document.querySelector('#overall'),
    document.querySelector('#teachers'), document.querySelector('#students')];

List <Department> departments;
List <YearChart> yearCharts = [];

var dataPath = 'universita';

var x,
    y=15,
    padding=10,
    chartSpace,
    boxWidth,
    boxSpace;

var minScore,
    maxScore;

var minY = int.parse(minYear.value),
    maxY = int.parse(maxYear.value);

class Department {
  var name;
  var year;
  var score;

  Department (name, year, score) {
    this.name = name;
    this.year = year;
    this.score = score;
  }

  double getSelectedScore () {
    var scoreDep = 0;
    var cont = 0;
    for (int i=0; i<satisfaction.length; i++){
      if (satisfaction[i].checked) {
        scoreDep += score[i];
        cont += 1;
      }
    };
    if (cont > 0)
      return scoreDep/cont;
    else
      return 0;
  }

  double getScaledScore (minY) {
    var height = canvas.height-padding;
    var scoreDep = getSelectedScore();
    if (scoreDep != 0)
      return (minY-height)*((scoreDep-minScore)/(maxScore-minScore))+height;
  }
}

class YearChart {
  var year;
  var xPos;
  var depPos;

  YearChart(year, xPos, depPos) {
    this.year = year;
    this.xPos = xPos;
    this.depPos = depPos;
  }

  bool isInHeader(MouseEvent e) {
    bool value = false;
    if (e.offset.x >= 10 && e.offset.x <= xPos)
      value = true;
    return value;
  }

  void drawPoint (var color, var depIndex, var canvasContext) {
    canvasContext
      ..lineWidth = 2
      ..fillStyle = color
      ..beginPath()
      ..arc(xPos, depPos[depIndex][1], 5, 0, 2*3.14)
      ..fill();
  }

  bool isInChart(MouseEvent e) {
    bool value = false;
    if (e.offset.x <= xPos+2 && e.offset.x >= xPos-2)
      value = true;
    return value;
  }

  double getOriginalScore(depIndex, minY) {
    var height = canvas.height-padding;
    return (((maxScore-minScore)*(depPos[depIndex][1]-height))/(minY-height))+minScore;
  }
}

void main() async {
  departments = [];
  // caricamento iniziale dei dati
  for (int i = minY; i <= maxY; i++) {
    var data = await HttpRequest.getString(dataPath + '/' + i.toString() + '.csv');
    setData(data, i);
  }
  drawVis();
  window.onResize.listen((event) {
    drawVis();
  });
  selectFolder.title = '';
  selectFolder.onChange.listen((event) {
    setFiles();
    loadNewData();
  });
  vis.onClick.listen((event) {
    minY = int.parse(minYear.value);
    maxY = int.parse(maxYear.value);
    drawVis();
  });
  long.onChange.listen((event) {
    drawVis();
  });
  satisfaction.forEach((var checkbox) {
    checkbox.onChange.listen((event) {
      drawVis();
    });
  });
  canvasOverlay.onMouseMove.listen(emphPath);
}

void setData (String data, var year) {
  var performanceData = data.split("7. GIUDIZI SULL'ESPERIENZA UNIVERSITARIA");
  performanceData = performanceData[1].split("8. CONOSCENZE LINGUISTICHE E INFORMATICHE");
  setDepartments(performanceData, year);
}

void setDepartments (var performanceData, var year) {
  performanceData = performanceData[0].split('\n');
  var depsNames = performanceData[1].split(';');
  var overallScores = [performanceData[3].split(';'), performanceData[4].split(';')];
  var teachScores = [performanceData[8].split(';'), performanceData[9].split(';')];
  var studentsScores = [performanceData[13].split(';'), performanceData[14].split(';')];
  for (int i=2; i<depsNames.length; i++) {
    var department = depsNames[i].split('(')[0];
    if (department.length >= 50)
      department = department.split(':')[0];
    department = department.replaceAll('"', '');
    var score = computeScore(overallScores, teachScores, studentsScores, i);
    departments.add(new Department(department, year, score));
  }
}

// Calcola il punteggio del dipartimento con id depId
List<double> computeScore (overall, teach, students, depId) {
  double ovScore=0, tScore=0, stScore=0;
  for (int i=0; i<overall.length; i++) {
    ovScore += double.parse(overall[i][depId].replaceAll(',', '.').replaceAll('"', ""));
    tScore += double.parse(teach[i][depId].replaceAll(',', '.').replaceAll('"', ""));
    stScore += double.parse(students[i][depId].replaceAll(',', '.').replaceAll('"', ""));
  }
  return [ovScore, tScore, stScore];
}

void setFiles() {
  FileList files = selectFolder.files;
  var numFiles = files.length;
  dataPath = files[0].relativePath.split('/')[0];
  minY = int.parse(files[0].name.split('.csv')[0]);
  maxY = int.parse(files[numFiles-1].name.split('.csv')[0]);
  minYear.value = minY.toString();
  maxYear.value = maxY.toString();
}

void loadNewData() async {
  departments = [];
  FileList files = selectFolder.files;
  for (int i=0; i<files.length; i++) {
    var data = await HttpRequest.getString(dataPath + '/' + files[i].name);
    var year = int.parse(files[i].name.split('.csv')[0]);
    setData(data, year);
  }
  drawVis();
}

void drawVis() {
  setCanvas();
  minScore = 100.0;
  maxScore = 0.0;
  yearCharts = [];
  var depsNames = setHeader();
  // ciclo perchè devo impostare gli anni con i maxScore e minScore trovati
  for (int i=minY; i<=maxY; i++) {
    setYear(i, x, y);
    x += chartSpace;
  }
  var color;
  depsNames.forEach((String name) {
    if (long.checked)
      color = getLongevityColor(name);
    else
      color = '#BEBEBE';
    drawPath(name, color, context);
  });
}

void setCanvas() {
  var canvasPadding = 65;
  canvas.height = window.innerHeight-canvasPadding;
  canvas.width = window.innerWidth-canvasPadding;
  canvasOverlay.height = window.innerHeight-canvasPadding;
  canvasOverlay.width = window.innerWidth-canvasPadding;
  boxWidth = canvas.width~/4.3;
  x = boxWidth+padding*4;
  chartSpace = (canvas.width-x)~/(maxY-minY+0.5);
}

String getLongevityColor (var name) {
  var numGroups = int.parse(nG.value);
  String color;
  var cont = 0;
  departments.forEach((var d) {
    if (d.name == name)
      if (d.year >= minY && d.year <= maxY)
        cont += 1;
  });
  var numY = maxY-minY+1;
  var groups = numY/numGroups;
  var saturation = 0;
  var lightness = 80;
  var saturationSum = (100~/numGroups);
  for (var i=0.0; i<=numY; i+=groups) {
    if (cont > i)
      color = new HslColor(240, saturation, lightness).toCssString();
    saturation += saturationSum;
    lightness -= 5;
  }
  return color;
}

/* Per ogni dipartimento e anno calcola i punteggi,
restituisce la lista dei dipartimenti per ogni anno
 */

void setYear (var year, var x, var y) {
  var depPos = [];
  drawChart(year, x, y);
  departments.forEach((Department d) {
    if (d.year == year)
      depPos.add([d.name, d.getScaledScore(y)]);
  });
  yearCharts.add(new YearChart(year, x, depPos));
}

void drawChart(var year, var x, var y) {
  context
    ..font = '12px Arial'
    ..fillStyle = 'black'
    ..fillText(year.toString(), x-15, y-5)
    ..strokeStyle = '#e0e0d1'
    ..lineWidth = 1
    ..beginPath()
    ..moveTo(x, y)
    ..lineTo(x, canvas.height-padding)
    ..moveTo(x-10, y)
    ..lineTo(x+10, y)
    ..moveTo(x-10, canvas.height-padding)
    ..lineTo(x+10, canvas.height-padding)
    ..closePath()
    ..stroke();
  if (year == minY) {
    context
      ..font = '10px Arial'
      ..fillText(maxScore.toStringAsFixed(1), x-30, y+5)
      ..fillText(minScore.toStringAsFixed(1), x-30, canvas.height-padding);
  }
}

List<String> setHeader () {
  var depPos = [];
  var deps = [];
  departments.forEach((Department d) {
    if (d.year >= minY && d.year <= maxY) {
      updateMinMax(d.getSelectedScore());
      deps.add(d.name);
    }
  });
  List<String> depsNames = List.from(deps.toSet());
  boxSpace = (canvas.height~/depsNames.length)-1;
  var y = 15+padding;
  var color;
  for (int i=0; i<depsNames.length; i++) {
    if (long.checked)
      color = getLongevityColor(depsNames.elementAt(i));
    else
      color = 'white';
    drawBox(color, 'black', depsNames.elementAt(i), y, context);
    depPos.add([depsNames.elementAt(i), y-5]);
    y += boxSpace;
  }
  yearCharts.insert(0, new YearChart(0, 320, depPos));
  return depsNames;
}

void updateMinMax (var score) {
  if (score != 0) {
    if (score <= minScore)
      minScore = score;
    if (score >= maxScore)
      maxScore = score;
  }
  else {
    minScore = 0.0;
    maxScore = 100.0;
  }
}

void drawBox (var boxColor, var fontColor, var name, var y, var canvasContext) {
  canvasContext
    ..fillStyle = boxColor
    ..fillRect(10, y-10, boxWidth, 13)
    ..font = getFontSize().toString()+'px Arial'
    ..fillStyle = fontColor
    ..fillText(name, 10, y);
}

int getFontSize() {
  if ((canvas.width >= 1000) || (canvas.height >= 500))
    return 12;
  else if ((canvas.width >= 800 && canvas.width < 1000) || (canvas.height >= 400 && canvas.height < 500))
    return 8;
  else if ((canvas.width >= 600 && canvas.width < 800) || (canvas.height >= 300 && canvas.height < 400))
    return 6;
  else if ((canvas.width >= 400 && canvas.width < 600) || (canvas.height >= 200 && canvas.height < 300))
    return 4;
  else if ((canvas.width < 400) || (canvas.height < 200))
    return 2;
}

void drawPath (var name, var color, var canvasContext) {
  for (int i=1; i<yearCharts.length; i++) {
    YearChart chart = yearCharts[i];
    // itero nel primo chart
    for (int j=0; j<chart.depPos.length; j++) {
      if (name == chart.depPos[j][0]) {
        chart.drawPoint(color, j, canvasContext);
        // itero nel secondo chart
        if (i == yearCharts.length-1)
          break;
        YearChart nextChart = yearCharts[i+1];
        for (int k=0; k<nextChart.depPos.length; k++) {
          // se trovo il dipartimento anche nel secondo chart, allora effettuo il collegamento
          if (name == nextChart.depPos[k][0]) {
            canvasContext
              ..strokeStyle = color
              ..lineWidth = 3
              ..beginPath()
              ..moveTo(chart.xPos, chart.depPos[j][1])
              ..lineTo(nextChart.xPos, nextChart.depPos[k][1])
              ..closePath()
              ..stroke();
            break;
          }
        }
      }
    }
  }
}

void emphPath (MouseEvent e) {
  contextOverlay.clearRect(0, 0, canvasOverlay.width, canvasOverlay.height);
  var color, name;
  YearChart chart = yearCharts[0];
  if (chart.isInHeader(e)) {
    chart.depPos.forEach((var dep) {
      if (e.offset.y <= dep[1]+6 && e.offset.y >= dep[1]-3) {
        color = 'black';
        name = dep[0];
        drawPath(name, color, contextOverlay);
        drawBox (color, 'white', name, dep[1]+5, contextOverlay);
      }
    });
  }
  else {
    yearCharts.forEach((var yChart) {
      if (yChart.isInChart(e)) {
        for (int i=0; i<yChart.depPos.length; i++) {
          if (e.offset.y <= yChart.depPos[i][1]+3 && e.offset.y >= yChart.depPos[i][1]-3) {
            color = 'black';
            name = yChart.depPos[i][0];
            drawPath(name, color, contextOverlay);
            drawTooltip(e.offset.x, e.offset.y, yChart.getOriginalScore(i, y));
            chart.depPos.forEach((var dep) {
              if (dep[0] == name)
                drawBox(color, 'white', name, dep[1]+5, contextOverlay);
            });
            break;
          }
        }
      }
    });
  }
}

void drawTooltip (var x, var y, var score) {
  contextOverlay
    ..fillStyle = 'white'
    ..fillRect(x+10, y-17, 30, 15)
    ..font = '12px Arial'
    ..fillStyle = 'black'
    ..fillText(score.toStringAsFixed(1), x+13, y-5);
}