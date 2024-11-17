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
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    _usersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final fetchedUsers = data.entries
            .where((e) => e.key != currentUserId) // Exclude the current user
            .map((e) {
          return {
            'id': e.key,
            ...Map<String, dynamic>.from(e.value),
          };
        }).toList();

        setState(() {
          users = fetchedUsers;
          filteredUsers = fetchedUsers;
          isLoading = false;
        });
      } else {
        setState(() {
          users = [];
          filteredUsers = [];
          isLoading = false;
        });
      }
    });
  }

  void _filterUsers() {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredUsers = users;
      });
    } else {
      setState(() {
        filteredUsers = users.where((user) {
          final email = (user['email'] ?? '').toLowerCase();
          return email.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> updates) async {
    await _usersRef.child(userId).update(updates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Manage Users',
          style: TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white12,
          hintText: 'Search Users...',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return Card(
          color: Colors.white12,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              user['email'] ?? 'No Email',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusText('Activated', user['activated'] ?? false),
                _buildStatusText('Admin', user['admin'] ?? false),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggle(
                  isActive: user['activated'] ?? false,
                  label: 'Activated',
                  onTap: () {
                    _updateUser(user['id'],
                        {'activated': !(user['activated'] ?? false)});
                  },
                ),
                const SizedBox(width: 10),
                _buildToggle(
                  isActive: user['admin'] ?? false,
                  label: 'Admin',
                  onTap: () {
                    _updateUser(
                        user['id'], {'admin': !(user['admin'] ?? false)});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(String label, bool status) {
    return Text(
      '$label: ${status ? "Yes" : "No"}',
      style: const TextStyle(color: Colors.white70),
    );
  }

  Widget _buildToggle({
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
