import 'package:flutter/material.dart';
import '../../../core/theme/ffig_theme.dart';

class FilterBottomSheet extends StatefulWidget {
  final List<String> initialSelectedIndustries;
  final List<String> initialSelectedCountries;
  final List<String> initialSelectedTiers;
  final List<String> availableCountries;
  final Function(List<String> industries, List<String> countries, List<String> tiers) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialSelectedIndustries,
    required this.initialSelectedCountries,
    required this.initialSelectedTiers,
    required this.availableCountries,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late List<String> _selectedIndustries;
  late List<String> _selectedCountries;
  late List<String> _selectedTiers;

  final Map<String, String> _industryMap = {
    'TECH': 'Technology',
    'FIN': 'Finance',
    'HLTH': 'Healthcare',
    'RET': 'Retail',
    'EDU': 'Education',
    'MED': 'Media & Arts',
    'LEG': 'Legal',
    'FASH': 'Fashion',
    'MAN': 'Manufacturing',
    'OTH': 'Other',
  };

  final Map<String, String> _tierMap = {
    'FREE': 'Free',
    'STANDARD': 'Standard',
    'PREMIUM': 'Premium',
  };

  @override
  void initState() {
    super.initState();
    _selectedIndustries = List.from(widget.initialSelectedIndustries);
    _selectedCountries = List.from(widget.initialSelectedCountries);
    _selectedTiers = List.from(widget.initialSelectedTiers);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndustries.clear();
                    _selectedCountries.clear();
                    _selectedTiers.clear();
                  });
                },
                child: const Text("Reset All", style: TextStyle(color: Colors.red)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection("Membership Type", _tierMap, _selectedTiers),
                  const SizedBox(height: 24),
                  _buildSection("Industry", _industryMap, _selectedIndustries),
                  const SizedBox(height: 24),
                  _buildCountrySection(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selectedIndustries, _selectedCountries, _selectedTiers);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FfigTheme.primaryBrown,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("APPLY FILTERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Map<String, String> options, List<String> selection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final isSelected = selection.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selection.add(entry.key);
                  } else {
                    selection.remove(entry.key);
                  }
                });
              },
              selectedColor: FfigTheme.primaryBrown.withOpacity(0.2),
              checkmarkColor: FfigTheme.primaryBrown,
              labelStyle: TextStyle(
                color: isSelected ? FfigTheme.primaryBrown : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCountrySection() {
    if (widget.availableCountries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Country", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableCountries.map((country) {
            final isSelected = _selectedCountries.contains(country);
            return FilterChip(
              label: Text(country),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCountries.add(country);
                  } else {
                    _selectedCountries.remove(country);
                  }
                });
              },
              selectedColor: FfigTheme.primaryBrown.withOpacity(0.2),
              checkmarkColor: FfigTheme.primaryBrown,
              labelStyle: TextStyle(
                color: isSelected ? FfigTheme.primaryBrown : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
