import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({Key? key}) : super(key: key);

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  Map<String, bool> selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    _usersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          users = data.entries
              .where((e) => e.key != currentUserId) // Exclude the current user
              .map((e) {
            return {
              'id': e.key,
              ...Map<String, dynamic>.from(e.value),
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          users = [];
          isLoading = false;
        });
      }
    });
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> updates) async {
    await _usersRef.child(userId).update(updates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? const Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: selectedUsers[user['id']] ?? false,
                          onChanged: (value) {
                            setState(() {
                              selectedUsers[user['id']] = value!;
                            });
                          },
                        ),
                        title: Text(user['email'] ?? 'No Email'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activated: ${user['activated'] ?? false}'),
                            Text('Admin: ${user['admin'] ?? false}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: user['activated'] ?? false,
                              onChanged: (value) {
                                _updateUser(user['id'], {'activated': value});
                              },
                            ),
                            Switch(
                              value: user['admin'] ?? false,
                              onChanged: (value) {
                                _updateUser(user['id'], {'admin': value});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
