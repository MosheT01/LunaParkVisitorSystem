import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

  File? _selectedImage;
  bool isLoading = false;

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

  Future<String?> _uploadImage(String visitorId, DateTime date) async {
    if (_selectedImage == null) return null;

    // Format the date to include only yyyy-MM-dd
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Save the image in the folder named by the formatted date
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
    final todayString = '${today.year}-${today.month}-${today.day}';

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
        final imageUrl = await _uploadImage(visitorId, today);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }

        await _visitorsRef.child(todayString).push().set({
          'id': visitorId,
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'notes': notesController.text.trim(),
          'cashier': cashierController.text.trim(),
          'timeOfEntry': DateTime.now().toIso8601String(),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Visitor Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                          controller: idController, label: 'ID Number'),
                      const SizedBox(height: 16),
                      _buildTextField(
                          controller: firstNameController, label: 'First Name'),
                      const SizedBox(height: 16),
                      _buildTextField(
                          controller: lastNameController, label: 'Last Name'),
                      const SizedBox(height: 16),
                      _buildTextField(
                          controller: notesController, label: 'Notes'),
                      const SizedBox(height: 16),
                      _buildTextField(
                          controller: cashierController, label: 'Cashier Name'),
                      const SizedBox(height: 16),
                      if (_selectedImage != null)
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text(
                          'Take Picture',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _addVisitor,
                          child: const Text(
                            'Add Visitor',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      ),
    );
  }
}
