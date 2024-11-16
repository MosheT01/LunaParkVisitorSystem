import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:luna_park_management/admin/admin_dashboard.dart';
import 'package:luna_park_management/admin/manage_users.dart';
import 'package:luna_park_management/home_page.dart';
import 'package:luna_park_management/login_page.dart';
import 'package:luna_park_management/visitor_management.dart'; // Import the VisitorManagementPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the correct database URL
  FirebaseDatabase.instance.databaseURL =
      'https://lunaparkmanagement-a8a9c-default-rtdb.europe-west1.firebasedatabase.app';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luna Park Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/admin': (context) => const AdminDashboard(),
        '/manageUsers': (context) => const ManageUsersPage(),
        '/visitorManagement': (context) =>
            const VisitorManagementPage(), // Add the new route
      },
    );
  }
}
