import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Widget buildSelectedImage(XFile file, {double height = 200, BoxFit fit = BoxFit.cover}) {
  return Image.network(file.path, height: height, fit: fit);
}

Future<void> deleteSelectedImage(XFile file) async {
  return;
}
