import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/utils/url_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final _endDateController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceLabelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  final _emailAutomationController = TextEditingController();
  bool _isVirtual = false;
  bool _isRsvpOnly = false;
  File? _selectedImage;

  bool _isLoading = false;

  final List<dynamic> _tiers = [];
  final List<dynamic> _speakers = [];
  final List<dynamic> _agenda = [];
  final List<dynamic> _faqs = [];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
        _tiers.addAll(widget.event!['tiers'] ?? []);
        _speakers.addAll(widget.event!['speakers'] ?? []);
        _agenda.addAll(widget.event!['agenda'] ?? []);
        _faqs.addAll(widget.event!['faqs'] ?? []);

      _titleController.text = widget.event!['title'] ?? '';
      
      final rawDate = widget.event!['date'] ?? '';
      try {
          final dt = DateTime.parse(rawDate);
          _dateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      } catch (_) {
          _dateController.text = rawDate;
      }
      
      final rawEndDate = widget.event!['end_date'] ?? '';
      try {
          if (rawEndDate.isNotEmpty) {
              final dt = DateTime.parse(rawEndDate);
              _endDateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
          }
      } catch (_) {
          _endDateController.text = rawEndDate;
      }
      _locationController.text = widget.event!['location'] ?? '';
      _priceLabelController.text = widget.event!['price_label'] ?? '';
      _descriptionController.text = widget.event!['description'] ?? '';
      _imageUrlController.text = widget.event!['image_url'] ?? '';
      _virtualLinkController.text = widget.event!['virtual_link'] ?? '';
      _emailAutomationController.text = widget.event!['email_automation_text'] ?? '';
      _isVirtual = widget.event!['is_virtual'] ?? false;
      _isRsvpOnly = widget.event!['is_rsvp_only'] ?? false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Event Image',
              toolbarColor: FfigTheme.primaryBrown,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true,
              activeControlsWidgetColor: FfigTheme.accentBrown,
            ),
            IOSUiSettings(
              title: 'Crop Event Image',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _selectedImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cropping failed: $e")));
      }
    }
  }

  Future<void> _cropExisting() async {
    if (_selectedImage == null) return;
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _selectedImage!.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Event Image',
            toolbarColor: FfigTheme.primaryBrown,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            activeControlsWidgetColor: FfigTheme.accentBrown,
          ),
          IOSUiSettings(
            title: 'Crop Event Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cropping failed: $e")));
      }
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
        'end_date': () {
             if (_endDateController.text.isEmpty) return null;
             final parts = _endDateController.text.split('-');
             if (parts.length == 3) {
                 return "${parts[2]}-${parts[1]}-${parts[0]}";
             }
             return _endDateController.text;
         }(),
        'location': _locationController.text,
        'price_label': _priceLabelController.text,
        'description': _descriptionController.text,
        'is_virtual': _isVirtual.toString(),
        'is_rsvp_only': _isRsvpOnly.toString(),
        'virtual_link': normalizeUrl(_virtualLinkController.text),
        'email_automation_text': _emailAutomationController.text,
      };
      
      final api = AdminApiService();
      if (widget.event == null) {
        await _createWithSubItems(data);
      } else {
        await api.updateEvent(widget.event!['id'], data, imageFile: _selectedImage ?? _imageUrlController.text);
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
      final newEvent = await api.createEvent(eventData, imageFile: _selectedImage);
      final eventId = newEvent['id'];

      try {
        for (var t in _tiers) {
           await api.createTicketTier({...t, 'event': eventId});
        }
        for (var s in _speakers) {
           await api.createEventSpeaker({...s, 'event': eventId});
        }
        for (var a in _agenda) {
           await api.createAgendaItem({...a, 'event': eventId});
        }
        for (var f in _faqs) {
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

  Future<void> _deleteItem(String type, int idOrIndex) async {
    try {
      if (widget.event != null) {
        if (type == 'tier') await AdminApiService().deleteTicketTier(idOrIndex);
        if (type == 'speaker') await AdminApiService().deleteEventSpeaker(idOrIndex);
        if (type == 'agenda') await AdminApiService().deleteAgendaItem(idOrIndex);
        if (type == 'faq') await AdminApiService().deleteEventFAQ(idOrIndex);
        
        setState(() {
          if (type == 'tier') _tiers.removeWhere((t) => t['id'] == idOrIndex);
          if (type == 'speaker') _speakers.removeWhere((s) => s['id'] == idOrIndex);
          if (type == 'agenda') _agenda.removeWhere((a) => a['id'] == idOrIndex);
          if (type == 'faq') _faqs.removeWhere((f) => f['id'] == idOrIndex);
        });
      } else {
        setState(() {
          if (type == 'tier') _tiers.removeAt(idOrIndex);
          if (type == 'speaker') _speakers.removeAt(idOrIndex);
          if (type == 'agenda') _agenda.removeAt(idOrIndex);
          if (type == 'faq') _faqs.removeAt(idOrIndex);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showManageDialog(String type, {Map<String, dynamic>? item, int? indexOrId}) {
    if (type == 'tier') _tierDialog(item: item, indexOrId: indexOrId);
    if (type == 'speaker') _speakerDialog(item: item, indexOrId: indexOrId);
    if (type == 'agenda') _agendaDialog(item: item, indexOrId: indexOrId);
    if (type == 'faq') _faqDialog(item: item, indexOrId: indexOrId);
  }

  void _tierDialog({Map<String, dynamic>? item, int? indexOrId}) {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final price = TextEditingController(text: item?['price']?.toString() ?? '');
    final cap = TextEditingController(text: item?['capacity']?.toString() ?? '');
    String selectedCurrency = item?['currency']?.toString().toUpperCase() ?? 'USD';

    final List<String> currencies = ['USD', 'ZAR', 'EUR', 'GBP', 'KES', 'NGN', 'GHS'];

    _showFormDialog(item == null ? "Add Ticket Tier" : "Edit Ticket Tier", [
      _buildStyledTextField(name, "Tier Name", icon: Icons.label, validator: (v) => v!.isEmpty ? "Tier name is required" : null),
      const SizedBox(height: 12),
      StatefulBuilder(
        builder: (context, setDialogState) {
          return DropdownButtonFormField<String>(
            value: currencies.contains(selectedCurrency) ? selectedCurrency : 'USD',
            decoration: const InputDecoration(
                labelText: "Currency",
                prefixIcon: Icon(Icons.currency_exchange, color: FfigTheme.primaryBrown),
            ),
            items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => selectedCurrency = v);
            },
          );
        }
      ),
      const SizedBox(height: 12),
      _buildStyledTextField(price, "Price", icon: Icons.payments, isNumber: true, validator: (v) => v!.isEmpty ? "Price is required" : null),
      const SizedBox(height: 12),
      _buildStyledTextField(cap, "Capacity", icon: Icons.people, isNumber: true, validator: (v) => v!.isEmpty ? "Capacity is required" : null),
    ], () async {
       final data = {
         'name': name.text,
         'price': double.tryParse(price.text) ?? 0,
         'currency': selectedCurrency.toLowerCase(),
         'capacity': int.tryParse(cap.text) ?? 100,
         if (item == null) 'available': int.tryParse(cap.text) ?? 100
       };
       if (widget.event == null) {
          setState(() => item == null ? _tiers.add(data) : _tiers[indexOrId!] = data);
       } else {
          if (item == null) {
              final newItem = await AdminApiService().createTicketTier({...data, 'event': widget.event!['id']});
              setState(() => _tiers.add(newItem));
          } else {
              await AdminApiService().updateTicketTier(indexOrId!, data);
              setState(() {
                  final idx = _tiers.indexWhere((t) => t['id'] == indexOrId);
                  if (idx != -1) _tiers[idx] = {..._tiers[idx], ...data};
              });
          }
       }
    }, isEdit: item != null);
  }

  void _speakerDialog({Map<String, dynamic>? item, int? indexOrId}) {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final role = TextEditingController(text: item?['role']?.toString() ?? '');
    final photo = TextEditingController(text: item?['photo_url']?.toString() ?? '');

    void _showUserSearch() {
        final searchController = TextEditingController();
        List<dynamic> users = [];
        bool searchLoading = true; // Auto-trigger search on open

        showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
                builder: (context, setDialogState) {
                    // Logic to load users on first opening
                    if (users.isEmpty && searchLoading && searchController.text.isEmpty) {
                        AdminApiService().searchUsers("").then((results) {
                            if (ctx.mounted) {
                                setDialogState(() {
                                    users = results;
                                    searchLoading = false;
                                });
                            }
                        }).catchError((e) {
                             if (ctx.mounted) setDialogState(() => searchLoading = false);
                        });
                    }

                    return AlertDialog(
                        title: const Text("Select User as Speaker"),
                        content: SizedBox(
                            width: double.maxFinite,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    TextField(
                                        controller: searchController,
                                        decoration: InputDecoration(
                                            hintText: "Search users...",
                                            suffixIcon: IconButton(
                                                icon: const Icon(Icons.search),
                                                onPressed: () async {
                                                    setDialogState(() => searchLoading = true);
                                                    try {
                                                        final results = await AdminApiService().searchUsers(searchController.text);
                                                        setDialogState(() => users = results);
                                                    } finally {
                                                        setDialogState(() => searchLoading = false);
                                                    }
                                                },
                                            ),
                                        ),
                                        onSubmitted: (_) async {
                                            setDialogState(() => searchLoading = true);
                                            try {
                                                final results = await AdminApiService().searchUsers(searchController.text);
                                                setDialogState(() => users = results);
                                            } finally {
                                                setDialogState(() => searchLoading = false);
                                            }
                                        },
                                    ),
                                    const SizedBox(height: 16),
                                    if (searchLoading) const Center(child: CircularProgressIndicator()),
                                    SizedBox(
                                        height: 300,
                                        child: ListView.builder(
                                            itemCount: users.length,
                                            itemBuilder: (context, index) {
                                                final u = users[index];
                                                final profile = u['profile'] ?? {};
                                                return ListTile(
                                                    leading: CircleAvatar(
                                                        backgroundImage: profile['photo'] != null ? NetworkImage(profile['photo']) : null,
                                                        child: profile['photo'] == null ? const Icon(Icons.person) : null,
                                                    ),
                                                    title: Text("${u['first_name']} ${u['last_name']}"),
                                                    subtitle: Text(profile['business_name'] ?? profile['tier'] ?? 'Member'),
                                                    onTap: () {
                                                        setState(() {
                                                            name.text = "${u['first_name']} ${u['last_name']}";
                                                            role.text = profile['business_name'] ?? profile['tier'] ?? '';
                                                            photo.text = profile['photo'] ?? '';
                                                        });
                                                        Navigator.pop(ctx);
                                                    },
                                                );
                                            },
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    );
                }
            )
        );
    }

    _showFormDialog(item == null ? "Add Speaker" : "Edit Speaker", [
      ElevatedButton.icon(
          onPressed: _showUserSearch, 
          icon: const Icon(Icons.person_search), 
          label: const Text("SEARCH EXISTING USERS"),
          style: ElevatedButton.styleFrom(
              backgroundColor: FfigTheme.accentBrown.withOpacity(0.1),
              foregroundColor: FfigTheme.primaryBrown,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12)
          ),
      ),
      const SizedBox(height: 16),
      _buildStyledTextField(name, "Full Name", icon: Icons.person, validator: (v) => v!.isEmpty ? "Name is required" : null),
      const SizedBox(height: 12),
      _buildStyledTextField(role, "Role / Title", icon: Icons.work, validator: (v) => v!.isEmpty ? "Role is required" : null),
      const SizedBox(height: 12),
      _buildStyledTextField(photo, "Photo URL", icon: Icons.image),
    ], () async {
       final data = {
         'name': name.text,
         'role': role.text,
         'photo_url': normalizeUrl(photo.text),
       };
       if (widget.event == null) {
          setState(() => item == null ? _speakers.add(data) : _speakers[indexOrId!] = data);
       } else {
          if (item == null) {
              final newItem = await AdminApiService().createEventSpeaker({...data, 'event': widget.event!['id']});
              setState(() => _speakers.add(newItem));
          } else {
              await AdminApiService().updateEventSpeaker(indexOrId!, data);
              setState(() {
                  final idx = _speakers.indexWhere((s) => s['id'] == indexOrId);
                  if (idx != -1) _speakers[idx] = {..._speakers[idx], ...data};
              });
          }
       }
    }, isEdit: item != null);
  }

  void _agendaDialog({Map<String, dynamic>? item, int? indexOrId}) {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final start = TextEditingController(text: item?['start_time']?.toString() ?? "09:00");
    final end = TextEditingController(text: item?['end_time']?.toString() ?? "10:00");
    final desc = TextEditingController(text: item?['description']?.toString() ?? '');
    _showFormDialog(item == null ? "Add Agenda Item" : "Edit Agenda Item", [
      _buildStyledTextField(title, "Session Title", icon: Icons.event_note, validator: (v) => v!.isEmpty ? "Title is required" : null),
      const SizedBox(height: 12),
      Row(children: [
          Expanded(child: _buildStyledTextField(start, "Start", icon: Icons.schedule, validator: (v) => v!.isEmpty ? "Required" : null)),
          const SizedBox(width: 8),
          Expanded(child: _buildStyledTextField(end, "End", icon: Icons.schedule_send, validator: (v) => v!.isEmpty ? "Required" : null)),
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
          setState(() => item == null ? _agenda.add(data) : _agenda[indexOrId!] = data);
       } else {
          if (item == null) {
              await AdminApiService().createAgendaItem({...data, 'event': widget.event!['id']});
          } else {
              await AdminApiService().updateAgendaItem(indexOrId!, data);
          }
       }
    }, isEdit: item != null);
  }

  void _faqDialog({Map<String, dynamic>? item, int? indexOrId}) {
    final q = TextEditingController(text: item?['question']?.toString() ?? '');
    final a = TextEditingController(text: item?['answer']?.toString() ?? '');
    _showFormDialog(item == null ? "Add FAQ" : "Edit FAQ", [
      _buildStyledTextField(q, "Question", icon: Icons.help_outline, validator: (v) => v!.isEmpty ? "Question is required" : null),
      const SizedBox(height: 12),
      _buildStyledTextField(a, "Answer", icon: Icons.info_outline, maxLines: 3, validator: (v) => v!.isEmpty ? "Answer is required" : null),
    ], () async {
       final data = {
         'question': q.text,
         'answer': a.text,
       };
       if (widget.event == null) {
          setState(() => item == null ? _faqs.add(data) : _faqs[indexOrId!] = data);
       } else {
          if (item == null) {
              await AdminApiService().createEventFAQ({...data, 'event': widget.event!['id']});
          } else {
              await AdminApiService().updateEventFAQ(indexOrId!, data);
          }
       }
    }, isEdit: item != null);
  }

  Widget _buildStyledTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1, IconData? icon, String? Function(String?)? validator, String? helperText}) {
      return TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              helperText: helperText,
              prefixIcon: icon != null ? Icon(icon, color: FfigTheme.primaryBrown) : null,
          ),
          validator: validator,
      );
  }

  void _showFormDialog(String title, List<Widget> fields, Future<void> Function() onSave, {bool isEdit = false}) {
    final subFormKey = GlobalKey<FormState>();
    showDialog(
      context: context, 
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(ctx).cardColor,
        child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
                child: Form(
                    key: subFormKey,
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
                                          if (!subFormKey.currentState!.validate()) return;
                                          try {
                                            if (widget.event != null) {
                                               await onSave(); 
                                               Navigator.pop(ctx);
                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Updated! Re-open to refresh." : "Added! Re-open to refresh.")));
                                            } else {
                                               await onSave();
                                               Navigator.pop(ctx);
                                            }
                                          } catch(e) {
                                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                          }
                                        }, 
                                        child: Text(isEdit ? "SAVE CHANGES" : "ADD ITEM")
                                    )
                                ],
                            )
                        ],
                    ),
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
                   decoration: const InputDecoration(
                     labelText: "Date",
                     prefixIcon: Icon(Icons.calendar_today, color: FfigTheme.primaryBrown),
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
                       setState(() {
                       _dateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                       });
                     }
                   },
                   validator: (v) => v!.isEmpty ? "Required" : null,
                 ),
                 const SizedBox(height: 12),
                 TextFormField(
                   controller: _endDateController,
                   decoration: const InputDecoration(
                     labelText: "End Date (Optional)",
                     prefixIcon: Icon(Icons.calendar_month, color: FfigTheme.primaryBrown),
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
                       setState(() {
                         _endDateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                       });
                     }
                   },
                 ),
                 const SizedBox(height: 12),
                 _buildStyledTextField(_locationController, "Location"),
                 const SizedBox(height: 12),
                 _buildStyledTextField(_priceLabelController, "Price Label (e.g. 'From \$20')"),
                 const SizedBox(height: 12),
                 Stack(
                   children: [
                     InkWell(
                       onTap: _pickImage,
                       child: Container(
                         height: 150,
                         width: double.infinity,
                         decoration: BoxDecoration(
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: Theme.of(context).colorScheme.outline)
                         ),
                         child: _selectedImage != null
                             ? ClipRRect(
                                 borderRadius: BorderRadius.circular(12),
                                 child: Image.file(_selectedImage!, fit: BoxFit.cover),
                               )
                             : (_imageUrlController.text.isNotEmpty && _imageUrlController.text.startsWith('http')
                                 ? ClipRRect(
                                     borderRadius: BorderRadius.circular(12),
                                     child: CachedNetworkImage(imageUrl: _imageUrlController.text, fit: BoxFit.cover, placeholder: (c,u) => const Center(child: CircularProgressIndicator()), errorWidget: (c,u,e) => const Icon(Icons.error)),
                                   )
                                 : Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                         Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                                         const SizedBox(height: 8),
                                         Text(widget.event != null ? "Change Cover Image" : "Upload Cover Image", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                     ],
                                   )),
                       ),
                     ),
                     if (_selectedImage != null)
                        Positioned(
                          top: 8, right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.crop, color: Colors.white),
                              onPressed: _cropExisting,
                            ),
                          ),
                        ),
                   ],
                 ),
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
                 const SizedBox(height: 12),
                  SwitchListTile(
                      title: const Text("Is RSVP Only?"), 
                      subtitle: const Text("Users can RSVP without buying tickets."),
                      activeThumbColor: FfigTheme.primaryBrown,
                      value: _isRsvpOnly, 
                      onChanged: (v) => setState(() => _isRsvpOnly = v)
                  ),
                  const SizedBox(height: 12),
                 _buildStyledTextField(
                   _emailAutomationController, 
                   "Email Automation Text", 
                   icon: Icons.auto_fix_high, 
                   maxLines: 5,
                   helperText: "Custom message sent to ticket purchasers immediately after purchase.",
                 ),
              ]),
              
              const SizedBox(height: 24),
              _buildListSection("Ticket Tiers", 'tier', _tiers, (i) => "${i['name']} (${(i['currency'] ?? 'USD').toString().toUpperCase()} ${i['price']})", Icons.airplane_ticket),
              _buildListSection("Speakers", 'speaker', _speakers, (i) => "${i['name']} (${i['role']})", Icons.mic),
              _buildListSection("Agenda", 'agenda', _agenda, (i) => "${i['start_time']} - ${i['title']}", Icons.calendar_view_day),
              _buildListSection("FAQ", 'faq', _faqs, (i) => i['question'], Icons.help),

               const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
       color: Theme.of(context).cardColor,
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
          color: Theme.of(context).cardColor,
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
                       onPressed: () => _showManageDialog(type)
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => _showManageDialog(type, item: Map<String, dynamic>.from(i), indexOrId: id)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteItem(type, id)),
                    ],
                  ),
                  dense: true,
                );
             }),
             if (items != null && items.isNotEmpty) const SizedBox(height: 8),
         ],
      ),
    );
  }
}
