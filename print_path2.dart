import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() {
  sqfliteFfiInit();
  print(databaseFactoryFfi.getDatabasesPath());
}
