import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Widget buildSelectedImage(XFile file, {double height = 200, BoxFit fit = BoxFit.cover}) {
  return Image.file(File(file.path), height: height, fit: fit);
}

Future<void> deleteSelectedImage(XFile file) async {
  final imageFile = File(file.path);
  if (await imageFile.exists()) {
    await imageFile.delete();
  }
}
