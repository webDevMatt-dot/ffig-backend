import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';

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

  // Local state for creation flow
  final List<Map<String, dynamic>> _localTiers = [];
  final List<Map<String, dynamic>> _localSpeakers = [];
  final List<Map<String, dynamic>> _localAgenda = [];
  final List<Map<String, dynamic>> _localFaqs = [];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!['title'] ?? '';
      
      final rawDate = widget.event!['date'] ?? '';
      try {
          final dt = DateTime.parse(rawDate);
          _dateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      } catch (_) {
          _dateController.text = rawDate;
      }
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
        'date': () {
             final parts = _dateController.text.split('-');
             if (parts.length == 3) {
                 return "${parts[2]}-${parts[1]}-${parts[0]}";
             }
             return _dateController.text;
         }(),
        'location': _locationController.text,
        'price_label': _priceLabelController.text,
        'description': _descriptionController.text,
        'image_url': _imageUrlController.text,
        'is_virtual': _isVirtual,
        'virtual_link': _virtualLinkController.text,
      };
      
      final api = AdminApiService();
      if (widget.event == null) {
        await _createWithSubItems(data);
      } else {
        await api.updateEvent(widget.event!['id'], data);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createWithSubItems(Map<String, dynamic> eventData) async {
      final api = AdminApiService();
      // 1. Create Event
      final newEvent = await api.createEvent(eventData);
      final eventId = newEvent['id'];

      // 2. Create Sub-items
      try {
        for (var t in _localTiers) {
           await api.createTicketTier({...t, 'event': eventId});
        }
        for (var s in _localSpeakers) {
           await api.createEventSpeaker({...s, 'event': eventId});
        }
        for (var a in _localAgenda) {
           await api.createAgendaItem({...a, 'event': eventId});
        }
        for (var f in _localFaqs) {
           await api.createEventFAQ({...f, 'event': eventId});
        }
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event & Details Created!")));
           Navigator.pop(context);
        }
      } catch (e) {
         if (mounted) DialogUtils.showError(context, "Partial Error", "Event created but some details failed: $e");
      }
  }

  // --- Sub-Item logic ---
  Future<void> _deleteItem(String type, int indexOrId) async {
    if (widget.event == null) {
       // Local delete
       setState(() {
         if (type == 'tier') _localTiers.removeAt(indexOrId);
         if (type == 'speaker') _localSpeakers.removeAt(indexOrId);
         if (type == 'agenda') _localAgenda.removeAt(indexOrId);
         if (type == 'faq') _localFaqs.removeAt(indexOrId);
       });
       return;
    }
    // API delete
    try {
      final api = AdminApiService();
      if (type == 'tier') await api.deleteTicketTier(indexOrId);
      if (type == 'speaker') await api.deleteEventSpeaker(indexOrId);
      if (type == 'agenda') await api.deleteAgendaItem(indexOrId);
      if (type == 'faq') await api.deleteEventFAQ(indexOrId);
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
       final data = {
         'name': name.text,
         'price': double.tryParse(price.text) ?? 0,
         'capacity': int.tryParse(cap.text) ?? 100,
         'available': int.tryParse(cap.text) ?? 100
       };
       if (widget.event == null) {
          setState(() => _localTiers.add(data));
       } else {
          await AdminApiService().createTicketTier({...data, 'event': widget.event!['id']});
       }
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
       final data = {
         'name': name.text,
         'role': role.text,
         'photo_url': photo.text,
       };
       if (widget.event == null) {
          setState(() => _localSpeakers.add(data));
       } else {
          await AdminApiService().createEventSpeaker({...data, 'event': widget.event!['id']});
       }
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
       final data = {
         'title': title.text,
         'start_time': start.text,
         'end_time': end.text,
         'description': desc.text,
       };
       if (widget.event == null) {
          setState(() => _localAgenda.add(data));
       } else {
          await AdminApiService().createAgendaItem({...data, 'event': widget.event!['id']});
       }
    });
  }

  void _addFAQDialog() {
    final q = TextEditingController();
    final a = TextEditingController();
    _showFormDialog("Add FAQ", [
      TextField(controller: q, decoration: const InputDecoration(labelText: "Question")),
      TextField(controller: a, decoration: const InputDecoration(labelText: "Answer"), maxLines: 3),
    ], () async {
       final data = {
         'question': q.text,
         'answer': a.text,
       };
       if (widget.event == null) {
          setState(() => _localFaqs.add(data));
       } else {
          await AdminApiService().createEventFAQ({...data, 'event': widget.event!['id']});
       }
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
            if (widget.event != null) {
               await onSave(); 
               Navigator.pop(ctx);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added! Re-open to refresh.")));
            } else {
               // Local add
               await onSave();
               Navigator.pop(ctx);
            }
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
                 TextFormField(
                   controller: _dateController,
                   decoration: const InputDecoration(
                     labelText: "Date", 
                     suffixIcon: Icon(Icons.calendar_today)
                   ),
                   readOnly: true,
                   onTap: () async {
                     DateTime? picked = await showDatePicker(
                       context: context,
                       initialDate: DateTime.now(),
                       firstDate: DateTime(2000),
                       lastDate: DateTime(2100),
                     );
                     if (picked != null) {
                       // Format: YYYY-MM-DD
                       setState(() {
                       _dateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                       });
                     }
                   },
                   validator: (v) => v!.isEmpty ? "Required" : null,
                 ),
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
              
              const SizedBox(height: 24),
              _buildListSection("Ticket Tiers", 'tier', widget.event != null ? widget.event!['ticket_tiers'] : _localTiers, (i) => "${i['name']} (\$${i['price']})"),
              _buildListSection("Speakers", 'speaker', widget.event != null ? widget.event!['speakers'] : _localSpeakers, (i) => "${i['name']} (${i['role']})"),
              _buildListSection("Agenda", 'agenda', widget.event != null ? widget.event!['agenda'] : _localAgenda, (i) => "${i['start_time']} - ${i['title']}"),
              _buildListSection("FAQ", 'faq', widget.event != null ? widget.event!['faqs'] : _localFaqs, (i) => i['question']),

               const SizedBox(height: 100),
               // ElevatedButton(
               //   onPressed: _isLoading ? null : _save,
               //   style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
               //   child: Text(_isLoading ? "Saving..." : "SAVE EVENT"),
               // )
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
              ),
              child: Text(_isLoading ? "Saving..." : "SAVE EVENT"),
            ),
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
             ...(items ?? []).asMap().entries.map((entry) {
                final i = entry.value;
                final index = entry.key;
                final id = i['id'] ?? index; // Use ID if valid, else index for local
                return ListTile(
                  title: Text(label(i)),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteItem(type, id)),
                  dense: true,
                );
             }).toList()
          ],
        ),
      ),
    );
  }
}
