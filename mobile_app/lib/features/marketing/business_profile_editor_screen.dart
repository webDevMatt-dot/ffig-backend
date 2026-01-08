import 'package:flutter/material.dart';
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
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchExisting();
  }

  Future<void> _fetchExisting() async {
    // TODO: Fetch from backend /api/members/business/me/
    // For now, assume fresh
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final api = AdminApiService();
      await api.createBusinessProfile({
        'company_name': _nameController.text,
        'website': _websiteController.text,
        'description': _descController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted for Approval!")));
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
