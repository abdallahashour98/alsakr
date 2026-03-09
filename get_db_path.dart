import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  try {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = docDir.path + '/al_sakr_local.db';
    print("DB Path: $dbPath");
    if (File(dbPath).existsSync()) {
      print("DB Exists!");
    } else {
      print("DB not found at $dbPath");
    }
  } catch(e) {
    print("Error: $e");
  }
}
