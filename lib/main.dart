import 'package:flutter/material.dart';
import 'Login.dart';
import 'RouteGenerator.dart';
import 'dart:io';

final ThemeData temaIOS = ThemeData(
    primaryColor: Colors.grey[200],
    accentColor: Color(0xff25D366)
);

final ThemeData temaPadrao = ThemeData(
  primaryColor: Color(0xff2A5E8e),
  accentColor: Color(0xff91998A),
);

void main(){
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MaterialApp(
    home: Login(),
    theme: Platform.isIOS ? temaIOS : temaPadrao,
    initialRoute: "/",
    onGenerateRoute: RouteGenerator.generateRoute,
    debugShowCheckedModeBanner: false,
  ));

}

