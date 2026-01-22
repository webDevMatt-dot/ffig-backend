import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import 'package:google_fonts/google_fonts.dart';

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
      _buildStyledTextField(name, "Tier Name", icon: Icons.label),
      const SizedBox(height: 12),
      _buildStyledTextField(price, "Price (\$)", icon: Icons.attach_money, isNumber: true),
      const SizedBox(height: 12),
      _buildStyledTextField(cap, "Capacity", icon: Icons.people, isNumber: true),
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
      _buildStyledTextField(name, "Full Name", icon: Icons.person),
      const SizedBox(height: 12),
      _buildStyledTextField(role, "Role / Title", icon: Icons.work),
      const SizedBox(height: 12),
      _buildStyledTextField(photo, "Photo URL", icon: Icons.image),
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
      _buildStyledTextField(title, "Session Title", icon: Icons.event_note),
      const SizedBox(height: 12),
      Row(children: [
          Expanded(child: _buildStyledTextField(start, "Start", icon: Icons.schedule)),
          const SizedBox(width: 8),
          Expanded(child: _buildStyledTextField(end, "End", icon: Icons.schedule_send)),
      ]),
      const SizedBox(height: 12),
      _buildStyledTextField(desc, "Description", icon: Icons.description, maxLines: 2),
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
      _buildStyledTextField(q, "Question", icon: Icons.help_outline),
      const SizedBox(height: 12),
      _buildStyledTextField(a, "Answer", icon: Icons.info_outline, maxLines: 3),
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

  Widget _buildStyledTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1, IconData? icon}) {
      return TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: icon != null ? Icon(icon, color: FfigTheme.primaryBrown) : null,
              filled: true,
              fillColor: Colors.grey[50], // Very light grey
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FfigTheme.primaryBrown, width: 2)),
              labelStyle: TextStyle(color: Colors.grey[700]),
          ),
      );
  }

  void _showFormDialog(String title, List<Widget> fields, Future<void> Function() onSave) {
    showDialog(
      context: context, 
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(title, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: FfigTheme.primaryBrown)),
                        const SizedBox(height: 8),
                         Container(height: 2, width: 40, color: FfigTheme.accentBrown),
                        const SizedBox(height: 24),
                        ...fields,
                        const SizedBox(height: 24),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx), 
                                    child: const Text("CANCEL", style: TextStyle(color: Colors.grey))
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: FfigTheme.primaryBrown,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                                    ),
                                    onPressed: () async {
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
                                    }, 
                                    child: const Text("ADD ITEM")
                                )
                            ],
                        )
                    ],
                ),
            ),
        ),
      )
    );
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
                 _buildStyledTextField(_titleController, "Event Title"),
                 const SizedBox(height: 12),
                 TextFormField(
                   controller: _dateController,
                   decoration: InputDecoration(
                     labelText: "Date", 
                     prefixIcon: const Icon(Icons.calendar_today, color: FfigTheme.primaryBrown),
                     filled: true,
                     fillColor: Colors.grey[50], 
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                     enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                     focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FfigTheme.primaryBrown, width: 2)),
                   ),
                   readOnly: true,
                   onTap: () async {
                     DateTime? picked = await showDatePicker(
                       context: context,
                       initialDate: DateTime.now(),
                       firstDate: DateTime(2000),
                       lastDate: DateTime(2100),
                       builder: (context, child) {
                           return Theme(
                               data: Theme.of(context).copyWith(
                                   colorScheme: const ColorScheme.light(primary: FfigTheme.primaryBrown),
                               ), 
                               child: child!
                           );
                       }
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
                 _buildStyledTextField(_locationController, "Location"),
                 const SizedBox(height: 12),
                 _buildStyledTextField(_priceLabelController, "Price Label (e.g. 'From \$20')"),
                 const SizedBox(height: 12),
                 _buildStyledTextField(_imageUrlController, "Cover Image URL"),
                 const SizedBox(height: 12),
                 _buildStyledTextField(_descriptionController, "Description", maxLines: 3),
                 const SizedBox(height: 12),
                 SwitchListTile(
                     title: const Text("Is Virtual Event?"), 
                     activeThumbColor: FfigTheme.primaryBrown,
                     value: _isVirtual, 
                     onChanged: (v) => setState(() => _isVirtual = v)
                 ),
                 if (_isVirtual) _buildStyledTextField(_virtualLinkController, "Meeting Link", icon: Icons.link),
              ]),
              
              const SizedBox(height: 24),
              _buildListSection("Ticket Tiers", 'tier', widget.event != null ? widget.event!['ticket_tiers'] : _localTiers, (i) => "${i['name']} (\$${i['price']})", Icons.airplane_ticket),
              _buildListSection("Speakers", 'speaker', widget.event != null ? widget.event!['speakers'] : _localSpeakers, (i) => "${i['name']} (${i['role']})", Icons.mic),
              _buildListSection("Agenda", 'agenda', widget.event != null ? widget.event!['agenda'] : _localAgenda, (i) => "${i['start_time']} - ${i['title']}", Icons.calendar_view_day),
              _buildListSection("FAQ", 'faq', widget.event != null ? widget.event!['faqs'] : _localFaqs, (i) => i['question'], Icons.help),

               const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("SAVE EVENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
       color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: FfigTheme.primaryBrown)),
            const SizedBox(height: 16),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(String title, String type, List? items, String Function(dynamic) label, IconData sectionIcon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2))
      ),
      child: Column(
         children: [
             Padding(
                 padding: const EdgeInsets.all(16),
                 child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                   Row(children: [
                       Icon(sectionIcon, color: FfigTheme.primaryBrown, size: 20),
                       const SizedBox(width: 8),
                       Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   ]),
                   IconButton(
                       icon: const Icon(Icons.add_circle, color: FfigTheme.accentBrown, size: 28), 
                       onPressed: () => _showAddDialog(type)
                   )
                 ]),
             ),
             const Divider(height: 1),
             if (items == null || items.isEmpty) 
                 const Padding(padding: EdgeInsets.all(20), child: Text("No items added yet.", style: TextStyle(color: Colors.grey))),
             
             ...(items ?? []).asMap().entries.map((entry) {
                final i = entry.value;
                final index = entry.key;
                final id = i['id'] ?? index; 
                return ListTile(
                  title: Text(label(i), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () => _deleteItem(type, id)),
                  dense: true,
                );
             }),
             if (items != null && items.isNotEmpty) const SizedBox(height: 8),
         ],
      ),
    );
  }
}
