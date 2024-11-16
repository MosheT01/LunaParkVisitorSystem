import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class VisitorManagementPage extends StatefulWidget {
  const VisitorManagementPage({Key? key}) : super(key: key);

  @override
  State<VisitorManagementPage> createState() => _VisitorManagementPageState();
}

class _VisitorManagementPageState extends State<VisitorManagementPage> {
  final DatabaseReference _visitorsRef =
      FirebaseDatabase.instance.ref('visitors');
  final TextEditingController idController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController cashierController = TextEditingController();
  // New Controllers for Edit Dialog
  final TextEditingController editFirstNameController = TextEditingController();
  final TextEditingController editLastNameController = TextEditingController();
  final TextEditingController editNotesController = TextEditingController();
  final TextEditingController editCashierController = TextEditingController();

  File? _selectedImage;
  bool isLoading = false;

  // For search
  final TextEditingController searchIdController = TextEditingController();
  Map<String, dynamic>? searchResult;
  String? searchKey;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image captured')),
        );
        return;
      }

      // Resize image to 360p
      final directory = await getTemporaryDirectory();
      final resizedImagePath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_resized.jpg';

      final resizedImage = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        resizedImagePath,
        minWidth: 640, // 360p resolution (width: 640, height: 360)
        minHeight: 360,
        quality: 85,
      );

      setState(() {
        _selectedImage = resizedImage != null ? File(resizedImage.path) : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image successfully selected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadImage(String visitorId, String dateString) async {
    if (_selectedImage == null) return null;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('visitor_images/$dateString/$visitorId.jpg');

    final uploadTask = storageRef.putFile(_selectedImage!);
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _addVisitor() async {
    if (idController.text.isEmpty ||
        firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        cashierController.text.isEmpty ||
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and take a picture')),
      );
      return;
    }

    final visitorId = idController.text.trim();
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Format timeOfEntry as YYYY-MM-DD HH:MM
    final formattedTimeOfEntry = DateFormat('yyyy-MM-dd HH:mm').format(today);

    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await _visitorsRef
          .child(todayString)
          .orderByChild('id')
          .equalTo(visitorId)
          .once();

      if (snapshot.snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Visitor with this ID already exists for today')),
        );
      } else {
        final imageUrl = await _uploadImage(visitorId, todayString);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }

        await _visitorsRef.child(todayString).push().set({
          'id': visitorId,
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'notes': notesController.text.trim(),
          'cashier': cashierController.text.trim(),
          'timeOfEntry': formattedTimeOfEntry, // Human-readable format
          'imageUrl': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitor added successfully')),
        );

        _clearForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      debugPrint('Error during add visitor: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _searchVisitor() async {
    final searchId = searchIdController.text.trim();
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (searchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide the ID')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await _visitorsRef
          .child(todayString)
          .orderByChild('id')
          .equalTo(searchId)
          .once();

      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(
          (snapshot.snapshot.value as Map<Object?, Object?>),
        );
        final key = data.keys.first;
        setState(() {
          searchKey = key;
          searchResult = Map<String, dynamic>.from(data[key]);
        });

        _showEditDialog(context); // Show edit dialog
      } else {
        setState(() {
          searchResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No visitor found for the given ID')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      debugPrint('Error during search: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateVisitor(String imageUrl) async {
    if (searchKey == null || searchResult == null) return;

    final today = DateTime.now();
    final formattedTimeOfEntry = DateFormat('yyyy-MM-dd HH:mm').format(today);

    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      await _visitorsRef.child(todayString).child(searchKey!).update({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'notes': notesController.text.trim(),
        'cashier': cashierController.text.trim(),
        'imageUrl': imageUrl,
        'timeOfEntry': formattedTimeOfEntry, // Human-readable format
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating visitor: $e')),
      );
    }
  }

  void _showEditDialog(BuildContext context) {
    if (searchResult == null) return;

    // Populate Edit Dialog Controllers
    editFirstNameController.text = searchResult!['firstName'] ?? '';
    editLastNameController.text = searchResult!['lastName'] ?? '';
    editNotesController.text = searchResult!['notes'] ?? '';
    editCashierController.text = searchResult!['cashier'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (searchResult?['imageUrl'] != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenImage(
                                      imageUrl: searchResult!['imageUrl'],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  searchResult?['imageUrl'] ?? '',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: editFirstNameController,
                            label: 'First Name',
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: editLastNameController,
                            label: 'Last Name',
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: editNotesController,
                            label: 'Notes',
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: editCashierController,
                            label: 'Cashier Name',
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () async {
                              await _pickImage();
                              if (_selectedImage != null) {
                                final imageUrl = await _uploadImage(
                                  searchResult!['id'],
                                  searchResult!['timeOfEntry'].split(' ')[0],
                                );
                                if (imageUrl != null) {
                                  await _updateVisitor(imageUrl);
                                  setState(() {
                                    searchResult!['imageUrl'] = imageUrl;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            label: const Text(
                              'Change Picture',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final imageUrl = _selectedImage != null
                                      ? await _uploadImage(
                                          searchResult!['id'],
                                          searchResult!['timeOfEntry']
                                              .split(' ')[0],
                                        )
                                      : searchResult!['imageUrl'];
                                  await _updateVisitor(imageUrl!);
                                  setState(() {
                                    searchResult!['imageUrl'] = imageUrl;
                                  });
                                  Navigator.of(context).pop(); // Close dialog
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    _showDeleteConfirmation(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this visitor? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _deleteVisitor();
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Close edit dialog
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVisitor() async {
    if (searchKey == null || searchResult == null) return;

    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      // Delete image from Firebase Storage
      if (searchResult?['imageUrl'] != null) {
        final storageRef =
            FirebaseStorage.instance.refFromURL(searchResult!['imageUrl']);
        await storageRef.delete();
      }

      // Delete entry from Firebase Realtime Database
      await _visitorsRef.child(todayString).child(searchKey!).remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor deleted successfully')),
      );

      setState(() {
        searchResult = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting visitor: $e')),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: enabled ? Colors.white12 : Colors.black12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      ),
    );
  }

  void _clearForm() {
    idController.clear();
    firstNameController.clear();
    lastNameController.clear();
    notesController.clear();
    cashierController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Visitor Management',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Search Visitor by ID',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: searchIdController,
                        label: 'ID Number',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _searchVisitor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // White background
                          foregroundColor: Colors.black, // Black text
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Add Visitor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: idController,
                        label: 'ID Number',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: firstNameController,
                        label: 'First Name',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: lastNameController,
                        label: 'Last Name',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: notesController,
                        label: 'Notes',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: cashierController,
                        label: 'Cashier Name',
                      ),
                      const SizedBox(height: 16),
                      if (_selectedImage != null)
                        Image.file(
                          _selectedImage!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt, color: Colors.black),
                        label: const Text(
                          'Take Picture',
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _addVisitor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // White background
                          foregroundColor: Colors.black, // Black text
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add Visitor'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40, // Adjust to position correctly on your screen
            right: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.8),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
