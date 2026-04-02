import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/admin_api_service.dart';

class QuizFormScreen extends StatefulWidget {
  final Map<String, dynamic>? quiz; // If null, we're adding. Else, editing.
  const QuizFormScreen({super.key, this.quiz});

  @override
  State<QuizFormScreen> createState() => _QuizFormScreenState();
}

class _QuizFormScreenState extends State<QuizFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = AdminApiService();
  bool _isSaving = false;

  late TextEditingController _promptController;
  late TextEditingController _explanationController;
  late DateTime _expiryDate;
  late List<TextEditingController> _optionControllers;
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.quiz?['prompt'] ?? '');
    _explanationController = TextEditingController(text: widget.quiz?['explanation'] ?? '');
    _expiryDate = widget.quiz != null 
        ? DateTime.parse(widget.quiz!['expires_at']) 
        : DateTime.now().add(const Duration(days: 7));
    _correctIndex = widget.quiz?['correct_index'] ?? 0;

    if (widget.quiz != null && widget.quiz!['options'] != null) {
      _optionControllers = (widget.quiz!['options'] as List)
          .map((opt) => TextEditingController(text: opt.toString()))
          .toList();
    } else {
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]; // Defaults to 3 choices
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _explanationController.dispose();
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
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
        if (_correctIndex >= _optionControllers.length) {
          _correctIndex = _optionControllers.length - 1;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final options = _optionControllers.map((c) => c.text).toList();

    final data = {
      'prompt': _promptController.text,
      'explanation': _explanationController.text,
      'expires_at': _expiryDate.toIso8601String(),
      'options': options,
      'correct_index': _correctIndex,
    };

    try {
      if (widget.quiz != null) {
        await _api.updateQuiz(widget.quiz!['id'], data);
      } else {
        await _api.createQuiz(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.quiz != null ? "Quiz updated" : "Quiz created! Push notification sent.")));
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
    final isEditing = widget.quiz != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "EDIT QUIZ" : "ADD NEW QUIZ", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Quiz Question", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _promptController,
              decoration: const InputDecoration(
                hintText: "Enter the question prompt",
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? "Prompt is required" : null,
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
                const Text("Select Correct Answer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Choice"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Radio<int>(
                      value: index,
                      groupValue: _correctIndex,
                      onChanged: (v) => setState(() => _correctIndex = v!),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: "Choice ${index + 1}",
                          border: const OutlineInputBorder(),
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
            
            const SizedBox(height: 24),
            const Text("Explanation (Shown after answer)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _explanationController,
              decoration: const InputDecoration(
                hintText: "Explain the correct answer...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? "UPDATE QUIZ" : "CREATE & SEND NOTIFICATION", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
