import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/admin_api_service.dart';

class PollFormScreen extends StatefulWidget {
  final Map<String, dynamic>? poll; // If null, we're adding. Else, editing.
  const PollFormScreen({super.key, this.poll});

  @override
  State<PollFormScreen> createState() => _PollFormScreenState();
}

class _PollFormScreenState extends State<PollFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = AdminApiService();
  bool _isSaving = false;

  late TextEditingController _questionController;
  late DateTime _expiryDate;
  late List<TextEditingController> _optionControllers;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.poll?['question'] ?? '');
    _expiryDate = widget.poll != null 
        ? DateTime.parse(widget.poll!['expires_at']) 
        : DateTime.now().add(const Duration(days: 7));

    // Initialize option controllers from existing options or defaults
    if (widget.poll != null && widget.poll!['options'] != null) {
      _optionControllers = (widget.poll!['options'] as List)
          .map((opt) => TextEditingController(text: opt['label']))
          .toList();
    } else {
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
      ]; // Start with 2 default empty options
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiryDate),
      );
      if (time != null) {
        setState(() {
          _expiryDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 10 options allowed")));
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Min 2 options required")));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < _optionControllers.length; i++) {
      final controller = _optionControllers[i];
      final optionData = {'label': controller.text};
      
      // If editing, try to preserve the original ID for existing options
      if (widget.poll != null && widget.poll!['options'] != null) {
        final existingOptions = widget.poll!['options'] as List;
        if (i < existingOptions.length) {
          optionData['id'] = existingOptions[i]['id'];
        }
      }
      options.add(optionData);
    }

    final data = {
      'question': _questionController.text,
      'expires_at': _expiryDate.toIso8601String(),
      'options': options,
    };

    try {
      if (widget.poll != null) {
        await _api.updatePoll(widget.poll!['id'], data);
      } else {
        await _api.createPoll(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.poll != null ? "Poll updated" : "Poll created! Push notification sent.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.poll != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "EDIT POLL" : "ADD NEW POLL", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Poll Question", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                hintText: "Enter the question",
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? "Question is required" : null,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Expiry Date & Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                OutlinedButton.icon(
                  onPressed: _selectExpiry,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(DateFormat('MMM d, h:mm a').format(_expiryDate)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Options (2-10)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Option"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: "Option ${index + 1}",
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.drag_indicator, color: Colors.grey),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removeOption(index),
                    ),
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? "UPDATE POLL" : "CREATE & SEND NOTIFICATION", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
