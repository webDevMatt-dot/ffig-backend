import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';

class EditEventScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  const EditEventScreen({super.key, this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController(); // DatePicker ideally
  final _locationController = TextEditingController();
  final _priceLabelController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!['title'];
      _dateController.text = widget.event!['date'];
      _locationController.text = widget.event!['location'];
      _priceLabelController.text = widget.event!['price_label'];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text,
        'date': _dateController.text,
        'location': _locationController.text,
        'price_label': _priceLabelController.text,
        // TODO: Ticket Tiers
      };
      
      final api = AdminApiService();
      if (widget.event == null) {
        await api.createEvent(data);
      } else {
        await api.updateEvent(widget.event!['id'], data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? "Create Event" : "Edit Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _dateController, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)"), validator: (v) => v!.isEmpty ? "Required" : null),
               const SizedBox(height: 16),
              TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: "Location"), validator: (v) => v!.isEmpty ? "Required" : null),
               const SizedBox(height: 16),
              TextFormField(controller: _priceLabelController, decoration: const InputDecoration(labelText: "Price Label (e.g. Free, \$50)")),
               const SizedBox(height: 32),
               
               ElevatedButton(
                 onPressed: _isLoading ? null : _save,
                 child: Text(_isLoading ? "Saving..." : "SAVE EVENT"),
               )
            ],
          ),
        ),
      ),
    );
  }
}
