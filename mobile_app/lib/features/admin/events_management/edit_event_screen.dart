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
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceLabelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  bool _isVirtual = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!['title'] ?? '';
      _dateController.text = widget.event!['date'] ?? '';
      _locationController.text = widget.event!['location'] ?? '';
      _priceLabelController.text = widget.event!['price_label'] ?? '';
      _descriptionController.text = widget.event!['description'] ?? '';
      _imageUrlController.text = widget.event!['image_url'] ?? '';
      _virtualLinkController.text = widget.event!['virtual_link'] ?? '';
      _isVirtual = widget.event!['is_virtual'] ?? false;
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
        'description': _descriptionController.text,
        'image_url': _imageUrlController.text,
        'is_virtual': _isVirtual,
        'virtual_link': _virtualLinkController.text,
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

  // --- Sub-Item logic ---
  Future<void> _deleteItem(String type, int id) async {
    try {
      final api = AdminApiService();
      if (type == 'tier') await api.deleteTicketTier(id);
      if (type == 'speaker') await api.deleteEventSpeaker(id);
      if (type == 'agenda') await api.deleteAgendaItem(id);
      if (type == 'faq') await api.deleteEventFAQ(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted. Re-open to refresh.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showAddDialog(String type) {
    // Generic dialog handler could be complex. Let's do concrete ones or a switch.
    // For brevity in this tool call, I'll inline the specific dialogs or calls.
    if (type == 'tier') _addTierDialog();
    if (type == 'speaker') _addSpeakerDialog();
    if (type == 'agenda') _addAgendaDialog();
    if (type == 'faq') _addFAQDialog();
  }

  void _addTierDialog() {
    final name = TextEditingController();
    final price = TextEditingController();
    final cap = TextEditingController();
    _showFormDialog("Add Ticket Tier", [
      TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
      TextField(controller: price, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
      TextField(controller: cap, decoration: const InputDecoration(labelText: "Capacity"), keyboardType: TextInputType.number),
    ], () async {
       await AdminApiService().createTicketTier({
         'event': widget.event!['id'],
         'name': name.text,
         'price': double.tryParse(price.text) ?? 0,
         'capacity': int.tryParse(cap.text) ?? 100,
         'available': int.tryParse(cap.text) ?? 100
       });
    });
  }

  void _addSpeakerDialog() {
    final name = TextEditingController();
    final role = TextEditingController();
    final photo = TextEditingController();
    _showFormDialog("Add Speaker", [
      TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
      TextField(controller: role, decoration: const InputDecoration(labelText: "Role")),
      TextField(controller: photo, decoration: const InputDecoration(labelText: "Photo URL")),
    ], () async {
       await AdminApiService().createEventSpeaker({
         'event': widget.event!['id'],
         'name': name.text,
         'role': role.text,
         'photo_url': photo.text,
       });
    });
  }

  void _addAgendaDialog() {
    final title = TextEditingController();
    final start = TextEditingController(text: "09:00");
    final end = TextEditingController(text: "10:00");
    final desc = TextEditingController();
    _showFormDialog("Add Agenda Item", [
      TextField(controller: title, decoration: const InputDecoration(labelText: "Title")),
      TextField(controller: start, decoration: const InputDecoration(labelText: "Start (HH:MM)")),
      TextField(controller: end, decoration: const InputDecoration(labelText: "End (HH:MM)")),
      TextField(controller: desc, decoration: const InputDecoration(labelText: "Description")),
    ], () async {
       await AdminApiService().createAgendaItem({
         'event': widget.event!['id'],
         'title': title.text,
         'start_time': start.text,
         'end_time': end.text,
         'description': desc.text,
       });
    });
  }

  void _addFAQDialog() {
    final q = TextEditingController();
    final a = TextEditingController();
    _showFormDialog("Add FAQ", [
      TextField(controller: q, decoration: const InputDecoration(labelText: "Question")),
      TextField(controller: a, decoration: const InputDecoration(labelText: "Answer"), maxLines: 3),
    ], () async {
       await AdminApiService().createEventFAQ({
         'event': widget.event!['id'],
         'question': q.text,
         'answer': a.text,
       });
    });
  }

  void _showFormDialog(String title, List<Widget> fields, Future<void> Function() onSave) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          try {
            await onSave();
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added! Re-open to refresh.")));
          } catch(e) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        }, child: const Text("Add"))
      ]
    ));
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection("Details", [
                 TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
                 const SizedBox(height: 12),
                 TextFormField(controller: _dateController, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)")),
                 const SizedBox(height: 12),
                 TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: "Location")),
                 const SizedBox(height: 12),
                 TextFormField(controller: _priceLabelController, decoration: const InputDecoration(labelText: "Price Label")),
                 const SizedBox(height: 12),
                 TextFormField(controller: _imageUrlController, decoration: const InputDecoration(labelText: "Image URL")),
                 const SizedBox(height: 12),
                 TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
                 SwitchListTile(title: const Text("Is Virtual?"), value: _isVirtual, onChanged: (v) => setState(() => _isVirtual = v)),
                 if (_isVirtual) TextFormField(controller: _virtualLinkController, decoration: const InputDecoration(labelText: "Virtual Link")),
              ]),
              
              if (widget.event != null) ...[
                const SizedBox(height: 24),
                _buildListSection("Ticket Tiers", 'tier', widget.event!['ticket_tiers'], (i) => "${i['name']} (\$${i['price']})"),
                _buildListSection("Speakers", 'speaker', widget.event!['speakers'], (i) => "${i['name']} (${i['role']})"),
                _buildListSection("Agenda", 'agenda', widget.event!['agenda'], (i) => "${i['start_time']} - ${i['title']}"),
                _buildListSection("FAQ", 'faq', widget.event!['faqs'], (i) => i['question']),
              ] else 
                const Padding(padding: EdgeInsets.all(16), child: Text("Save event to add sub-items.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), textAlign: TextAlign.center)),

               const SizedBox(height: 32),
               ElevatedButton(
                 onPressed: _isLoading ? null : _save,
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                 child: Text(_isLoading ? "Saving..." : "SAVE EVENT"),
               )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(String title, String type, List? items, String Function(dynamic) label) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () => _showAddDialog(type))
             ]),
             if (items == null || items.isEmpty) const Text("No items.", style: TextStyle(color: Colors.grey)),
             ...(items ?? []).map((i) => ListTile(
               title: Text(label(i)),
               trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteItem(type, i['id'])),
               dense: true,
             )).toList()
          ],
        ),
      ),
    );
  }
}
