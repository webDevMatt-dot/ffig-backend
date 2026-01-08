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

  Future<void> _deleteTier(int id) async {
    // Call API and reload? Ideally we reload the full event. 
    // Since we don't have a reload method here easily, we rely on parent or implement logic.
    // Simpler: Just delete and warn user they need to reopen to see changes? 
    // Better: Re-fetch event. But EditEventScreen takes event as param.
    // Best for MVP: Delete and close screen or show snackbar.
    await AdminApiService().deleteTicketTier(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tier deleted. Re-open to refresh.")));
  }

  void _showAddTierDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final capCtrl = TextEditingController();

    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Add Ticket Tier"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name (e.g. VIP)")),
        TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
        TextField(controller: capCtrl, decoration: const InputDecoration(labelText: "Capacity"), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            try {
               await AdminApiService().createTicketTier({
                 'event': widget.event!['id'],
                 'name': nameCtrl.text,
                 'price': double.tryParse(priceCtrl.text) ?? 0.0,
                 'capacity': int.tryParse(capCtrl.text) ?? 100,
                 'available': int.tryParse(capCtrl.text) ?? 100
               });
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tier added. Re-open to refresh.")));
            } catch(e) { /* handle */ }
        }, child: const Text("Add"))
      ],
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
            children: [
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _dateController, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)"), validator: (v) => v!.isEmpty ? "Required" : null),
               const SizedBox(height: 16),
              TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: "Location"), validator: (v) => v!.isEmpty ? "Required" : null),
               const SizedBox(height: 16),
              TextFormField(controller: _priceLabelController, decoration: const InputDecoration(labelText: "Price Label (e.g. Free, \$50)")),
               const SizedBox(height: 32),
               
              TextFormField(controller: _priceLabelController, decoration: const InputDecoration(labelText: "Price Label (e.g. Free, \$50)")),
               const SizedBox(height: 32),
               
               if (widget.event != null) ...[
                 const Divider(),
                 const Text("Ticket Tiers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 const SizedBox(height: 8),
                 ...(widget.event!['ticket_tiers'] as List? ?? []).map<Widget>((t) => ListTile(
                   title: Text(t['name']),
                   subtitle: Text("\$${t['price']} • ${t['available']}/${t['capacity']} left"),
                   trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTier(t['id'])),
                 )).toList(),
                 TextButton.icon(
                   icon: const Icon(Icons.add),
                   label: const Text("Add Ticket Tier"),
                   onPressed: _showAddTierDialog,
                 ),
                 const Divider(),
               ] else 
                 const Text("Save event to add tickets.", style: TextStyle(color: Colors.grey)),

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
