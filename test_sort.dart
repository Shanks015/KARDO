import 'dart:math';

class Point {
  final double x, y;
  Point(this.x, this.y);
}

class Rect {
  final double left, top, width, height;
  Rect(this.left, this.top, this.width, this.height);
  double get right => left + width;
  double get bottom => top + height;
}

class Line {
  final String text;
  final Rect boundingBox;
  Line(this.text, this.boundingBox);
}

void main() {
  // Simulate vertical lines (rotated 90 deg clockwise)
  // MASSACHUSETTS is on the right
  // COLLEGE of PHARMACY is in the middle
  // and HEALTH SCIENCES is on the left
  var lines = [
    Line("and HEALTH SCIENCES", Rect(10, 100, 20, 200)),
    Line("COLLEGE of PHARMACY", Rect(40, 100, 20, 200)),
    Line("MASSACHUSETTS", Rect(70, 100, 20, 200)),
  ];

  // We want to sort them so MASSACHUSETTS comes first.
  // Find the principal axis of variance
  double minX = lines.map((l) => l.boundingBox.left).reduce(min);
  double maxX = lines.map((l) => l.boundingBox.left).reduce(max);
  double minY = lines.map((l) => l.boundingBox.top).reduce(min);
  double maxY = lines.map((l) => l.boundingBox.top).reduce(max);

  double xSpread = maxX - minX;
  double ySpread = maxY - minY;

  lines.sort((a, b) {
    if (xSpread > ySpread) {
       // Horizontally spread (vertical text). 
       // In english, lines go left to right. But wait, if they are rotated 90 deg clockwise,
       // the first line is on the right! (x is largest)
       // If rotated 90 deg counter-clockwise, first line is on the left! (x is smallest)
       // How to know? We can't know easily without corner points.
       // Let's just sort by left-to-right (standard).
       return a.boundingBox.left.compareTo(b.boundingBox.left);
    } else {
       // Vertically spread (horizontal text). Lines go top to bottom.
       return a.boundingBox.top.compareTo(b.boundingBox.top);
    }
  });
  
  print(lines.map((l) => l.text).join(' '));
}
