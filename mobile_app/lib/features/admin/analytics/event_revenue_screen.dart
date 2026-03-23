import 'package:flutter/material.dart';
import '../../../../core/theme/ffig_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class EventRevenueScreen extends StatelessWidget {
  final List<dynamic> eventData;

  const EventRevenueScreen({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // Determine maximum revenue for Y-axis scaling
    double maxRevenue = 0;
    for (var ev in eventData) {
      final rev = (ev['revenue'] ?? 0).toDouble();
      if (rev > maxRevenue) maxRevenue = rev;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Event Revenue Breakdown")),
      body: eventData.isEmpty
          ? const Center(child: Text("No event revenue data available."))
          : Column(
              children: [
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Revenue per Event",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 32),
                // Chart Section
                SizedBox(
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 100,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${eventData[groupIndex]["event"]}\n\$${rod.toY.toStringAsFixed(2)}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= eventData.length) return const SizedBox.shrink();
                                String title = eventData[index]['event'] ?? '';
                                if (title.length > 10) {
                                  title = "${title.substring(0, 8)}...";
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                );
                              },
                              reservedSize: 32,
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(eventData.length, (index) {
                          final data = eventData[index];
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: (data['revenue'] ?? 0).toDouble(),
                                color: FfigTheme.primaryBrown,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // List View Section
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: eventData.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = eventData[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: FfigTheme.primaryBrown.withOpacity(0.1),
                          child: const Icon(Icons.event, color: FfigTheme.primaryBrown),
                        ),
                        title: Text(item['event'] ?? 'Unknown Event'),
                        trailing: Text(
                          "\$${(item['revenue'] ?? 0).toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
