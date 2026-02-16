import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/services/admin_api_service.dart';

class BusinessProfileEditorScreen extends StatefulWidget {
  const BusinessProfileEditorScreen({super.key});

  @override
  State<BusinessProfileEditorScreen> createState() => _BusinessProfileEditorScreenState();
}

class _BusinessProfileEditorScreenState extends State<BusinessProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController(); // NEW
  final _descController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false; // Track if we are editing an existing profile

  @override
  void initState() {
    super.initState();
    _fetchExisting();
  }

  Future<void> _fetchExisting() async {
    setState(() => _isLoading = true);
    try {

      final api = AdminApiService();
      final data = await api.fetchMyBusinessProfile();
      
      String? existingLocation;
      
      if (data != null) {
          _isEditing = true;
          _nameController.text = data['company_name'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _descController.text = data['description'] ?? '';
          existingLocation = data['location'];
          if (existingLocation != null) _locationController.text = existingLocation;
      }
      
      // Auto-fill from User Profile if empty
      if (_locationController.text.isEmpty) {
          await _fetchUserProfileLocation();
      }

    } catch (e) {
       // Ignore errors, assume fresh
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserProfileLocation() async {
      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        if (token == null) return;
        
        final response = await http.get(
            Uri.parse('${baseUrl}members/me/'),
            headers: {'Authorization': 'Bearer $token'}
        );
        
        if (response.statusCode == 200) {
            final userData = jsonDecode(response.body);
            // Handle list response just in case (reusing logic from Dashboard)
            var profile = userData;
            if (userData is List && userData.isNotEmpty) profile = userData.first;
            
            if (profile is Map && profile['location'] != null) {
                 if (mounted) {
                     setState(() {
                         _locationController.text = profile['location'];
                         // Flag is usually already in the string from EditProfileScreen
                     });
                 }
            }
        }
      } catch (e) {
          print("Error fetching user location: $e");
      }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final api = AdminApiService();
      final data = {
        'company_name': _nameController.text,
        'website': _websiteController.text,
        'location': _locationController.text,
        'description': _descController.text,
      };

      if (_isEditing) {
          await api.updateBusinessProfile(data);
      } else {
          await api.createBusinessProfile(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? "Profile Updated!" : "Submitted for Approval!")));
        Navigator.pop(context);
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Business Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text("As a Premium Member, your business profile will be featured in the Business Directory upon approval."),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Company Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: "Website URL"),
              ),
              const SizedBox(height: 16),
              
              GestureDetector(
                onTap: () {
                    showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        onSelect: (Country country) {
                            setState(() {
                                _locationController.text = "${country.flagEmoji} ${country.displayNameNoCountryCode}";
                            });
                        },
                    );
                },
                child: AbsorbPointer(
                    child: TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                            labelText: "Country / Location",
                            suffixIcon: Icon(Icons.arrow_drop_down)
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Description", alignLabelWithHint: true),
                maxLines: 5,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black
                ),
                child: Text(_isLoading ? "Submitting..." : "SUBMIT FOR APPROVAL"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
