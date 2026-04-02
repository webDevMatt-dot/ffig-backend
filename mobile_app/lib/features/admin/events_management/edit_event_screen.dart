import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/api/constants.dart';
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
        _mapEventToControllers(widget.event!);
        _loadFullDetails();
    }
  }

  void _mapEventToControllers(Map<String, dynamic> event) {
      _tiers.clear();
      _speakers.clear();
      _agenda.clear();
      _faqs.clear();

      _tiers.addAll(event['ticket_tiers'] ?? []);
      _speakers.addAll(event['speakers'] ?? []);
      _agenda.addAll(event['agenda'] ?? []);
      _faqs.addAll(event['faqs'] ?? []);

      _titleController.text = event['title'] ?? '';
      
      final rawDate = event['date'] ?? '';
      try {
          final dt = DateTime.parse(rawDate);
          _dateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      } catch (_) {
          _dateController.text = rawDate;
      }
      
      final rawEndDate = event['end_date'] ?? '';
      try {
          if (rawEndDate.isNotEmpty) {
              final dt = DateTime.parse(rawEndDate);
              _endDateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
          }
      } catch (_) {
          _endDateController.text = rawEndDate;
      }
      _locationController.text = event['location'] ?? '';
      _priceLabelController.text = event['price_label'] ?? '';
      _descriptionController.text = event['description'] ?? '';
      _imageUrlController.text = event['image_url'] ?? '';
      _virtualLinkController.text = event['virtual_link'] ?? '';
      _emailAutomationController.text = event['email_automation_text'] ?? '';
      _isVirtual = event['is_virtual'] ?? false;
      _isRsvpOnly = event['is_rsvp_only'] ?? false;
  }

  Future<void> _loadFullDetails() async {
      try {
          final api = AdminApiService();
          final fullEvent = await api.fetchEventDetails(widget.event!['id']);
          if (mounted) {
              setState(() {
                  _mapEventToControllers(fullEvent);
              });
          }
      } catch (e) {
          debugPrint("Failed to load full event details: $e");
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
      _buildStyledTextField(name, "Tier Name", icon: Icons.label_outline, validator: (v) => v!.isEmpty ? "Tier name is required" : null),
      StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: DropdownButtonFormField<String>(
              value: currencies.contains(selectedCurrency) ? selectedCurrency : 'USD',
              dropdownColor: Theme.of(context).cardColor,
              style: GoogleFonts.inter(fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                  labelText: "Currency",
                  labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.currency_exchange, color: FfigTheme.accentBrown, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: currencies.map((c) => DropdownMenuItem(
                value: c, 
                child: Text(c, style: GoogleFonts.inter())
              )).toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedCurrency = v);
              },
            ),
          );
        }
      ),
      _buildStyledTextField(price, "Price", icon: Icons.payments_outlined, isNumber: true, validator: (v) => v!.isEmpty ? "Price is required" : null),
      _buildStyledTextField(cap, "User Capacity", icon: Icons.people_outline, isNumber: true, validator: (v) => v!.isEmpty ? "Capacity is required" : null),
    ], 
() async {
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
    int? selectedUserId = item?['user'];

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

                    return BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: AlertDialog(
                            backgroundColor: Theme.of(ctx).cardColor.withOpacity(0.95),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            title: Text(
                              "Select User as Speaker".toUpperCase(), 
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: FfigTheme.accentBrown)
                            ),
                            content: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.9,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: TextField(
                                              controller: searchController,
                                              style: GoogleFonts.inter(fontSize: 14),
                                              decoration: InputDecoration(
                                                  hintText: "Search by name or email...",
                                                  hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                                                  prefixIcon: const Icon(Icons.search, size: 20),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                        ),
                                        const SizedBox(height: 16),
                                        if (searchLoading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                                        if (!searchLoading && users.isEmpty) 
                                          Padding(
                                            padding: const EdgeInsets.all(32),
                                            child: Text("No users found", style: GoogleFonts.inter(color: Colors.grey)),
                                          ),
                                        if (users.isNotEmpty)
                                          SizedBox(
                                              height: 350,
                                              child: ListView.separated(
                                                  itemCount: users.length,
                                                  separatorBuilder: (c,i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                                                  itemBuilder: (context, index) {
                                                      final u = users[index];
                                                      String? photoUrl = u['photo_url'];
                                                      if (photoUrl != null && photoUrl.startsWith('/')) {
                                                          final domain = baseUrl.replaceAll('/api/', '');
                                                          photoUrl = '$domain$photoUrl';
                                                      }

                                                      return ListTile(
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                          leading: CircleAvatar(
                                                              radius: 20,
                                                              backgroundColor: FfigTheme.accentBrown.withOpacity(0.1),
                                                              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                                              child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: FfigTheme.accentBrown, size: 20) : null,
                                                          ),
                                                          title: Text("${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim(), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                                          subtitle: Text(u['tier'] ?? 'Member', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                                                          onTap: () {
                                                              setState(() {
                                                                  name.text = "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim();
                                                                  role.text = u['tier'] ?? 'Member';
                                                                  photo.text = photoUrl ?? '';
                                                                  selectedUserId = u['id']; // Store the user ID
                                                              });
                                                              Navigator.pop(context);
                                                          },
                                                      );
                                                  },
                                              ),
                                          ),
                                    ],
                                ),
                            ),
                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx), 
                                    child: const Text("CLOSE", style: TextStyle(color: Colors.grey))
                                )
                            ],
                        ),
                    );
                }
            )
        );
    }

    _showFormDialog(item == null ? "Add Speaker" : "Edit Speaker", [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        child: ElevatedButton.icon(
            onPressed: _showUserSearch, 
            icon: const Icon(Icons.person_search_rounded, size: 20), 
            label: Text("SEARCH EXISTING USERS", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
                backgroundColor: FfigTheme.accentBrown.withOpacity(0.08),
                foregroundColor: FfigTheme.accentBrown,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: FfigTheme.accentBrown.withOpacity(0.2)),
                ),
            ),
        ),
      ),
      _buildStyledTextField(name, "Full Name", icon: Icons.person_outline, validator: (v) => v!.isEmpty ? "Name is required" : null),
      _buildStyledTextField(role, "Role / Title", icon: Icons.work_outline, validator: (v) => v!.isEmpty ? "Role is required" : null),
      _buildStyledTextField(photo, "Photo URL", icon: Icons.image_outlined),
    ], () async {
       final data = {
         'name': name.text,
         'role': role.text,
         'photo_url': normalizeUrl(photo.text),
         'user': selectedUserId,
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
      _buildStyledTextField(title, "Session Title", icon: Icons.event_note_outlined, validator: (v) => v!.isEmpty ? "Title is required" : null),
      Row(children: [
          Expanded(child: _buildStyledTextField(start, "Start Time", icon: Icons.schedule_outlined, validator: (v) => v!.isEmpty ? "Required" : null)),
          const SizedBox(width: 12),
          Expanded(child: _buildStyledTextField(end, "End Time", icon: Icons.more_time_outlined, validator: (v) => v!.isEmpty ? "Required" : null)),
      ]),
      _buildStyledTextField(desc, "Description / Notes", icon: Icons.description_outlined, maxLines: 2),
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
      _buildStyledTextField(q, "Question", icon: Icons.help_outline_rounded, validator: (v) => v!.isEmpty ? "Question is required" : null),
      _buildStyledTextField(a, "Answer", icon: Icons.info_outline_rounded, maxLines: 3, validator: (v) => v!.isEmpty ? "Answer is required" : null),
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
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 15),
            decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                helperText: helperText,
                prefixIcon: icon != null ? Icon(icon, color: FfigTheme.accentBrown, size: 20) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: validator,
        ),
      );
  }

  void _showFormDialog(String title, List<Widget> fields, Future<void> Function() onSave, {bool isEdit = false}) {
    final subFormKey = GlobalKey<FormState>();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            child: FadeTransition(
              opacity: anim1,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.transparent,
                child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: SingleChildScrollView(
                        child: Form(
                            key: subFormKey,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Text(
                                      title.toUpperCase(), 
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 22, 
                                        fontWeight: FontWeight.w900, 
                                        color: FfigTheme.accentBrown,
                                        letterSpacing: 1.2
                                      )
                                    ),
                                    const SizedBox(height: 8),
                                    Container(height: 1, width: 60, color: FfigTheme.accentBrown.withOpacity(0.3)),
                                    const SizedBox(height: 24),
                                    ...fields,
                                    const SizedBox(height: 32),
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(ctx), 
                                                child: Text("CANCEL", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1))
                                            ),
                                            const SizedBox(width: 16),
                                            ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: FfigTheme.accentBrown,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                                    elevation: 8,
                                                    shadowColor: FfigTheme.accentBrown.withOpacity(0.5),
                                                ),
                                                onPressed: () async {
                                                  if (!subFormKey.currentState!.validate()) return;
                                                  try {
                                                    if (widget.event != null) {
                                                       await onSave(); 
                                                       Navigator.pop(ctx);
                                                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Updated!" : "Added!")));
                                                    } else {
                                                       await onSave();
                                                       Navigator.pop(ctx);
                                                    }
                                                  } catch(e) {
                                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                                  }
                                                }, 
                                                child: Text(
                                                  (isEdit ? "SAVE CHANGES" : "ADD ITEM").toUpperCase(),
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                )
                                            )
                                        ],
                                    )
                                ],
                            ),
                        ),
                    ),
                ),
              ),
            ),
          ),
        );
      },
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
              _buildSection("EVENT DETAILS", [
                 _buildStyledTextField(_titleController, "Event Title", icon: Icons.title),
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _dateController,
                   decoration: InputDecoration(
                     labelText: "Start Date",
                     prefixIcon: const Icon(Icons.calendar_today, color: FfigTheme.accentBrown),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 16),
                 TextFormField(
                   controller: _endDateController,
                   decoration: InputDecoration(
                     labelText: "End Date (Optional)",
                     prefixIcon: const Icon(Icons.calendar_month, color: FfigTheme.accentBrown),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 16),
                 _buildStyledTextField(_locationController, "Location", icon: Icons.location_on),
                 const SizedBox(height: 16),
                 _buildStyledTextField(_priceLabelController, "Price Label (e.g. 'From \$20')", icon: Icons.payments),
                 const SizedBox(height: 24),
                 
                 const Text("COVER IMAGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Theme.of(context).dividerColor)
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
                     if (_selectedImage != null || (_imageUrlController.text.isNotEmpty && _imageUrlController.text.startsWith('http')))
                        Positioned(
                          bottom: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: FfigTheme.accentBrown,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.crop, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _cropExisting,
                            ),
                          ),
                        ),
                   ],
                 ),
                 const SizedBox(height: 24),
                 _buildStyledTextField(_descriptionController, "Full Description", maxLines: 4, icon: Icons.description),
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
                  const SizedBox(height: 16),
                 _buildStyledTextField(
                   _emailAutomationController, 
                   "Email Automation Message", 
                   icon: Icons.auto_fix_high, 
                   maxLines: 4,
                   helperText: "Sent to ticket purchasers immediately after purchase.",
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 20),
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
