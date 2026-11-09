// Inicialización de SQLite para plataformas nativas (Android, iOS, escritorio).
// Solo se compila cuando existe dart:io, por lo que dart:ffi nunca llega a web.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void inicializarSqlitePlataforma() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Escritorio: sqflite no tiene plugin nativo, se usa la versión FFI.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('SQLite inicializado con FFI (escritorio)');
  }
  // Android/iOS: inicialización estándar de sqflite, no se requiere nada.
}
