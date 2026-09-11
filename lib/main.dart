import 'dart:math';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const RetailAI());

class RetailAI extends StatelessWidget {
  const RetailAI({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RetailAI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const DashboardPage(),
      );
}

class Sale {
  final String date, sku, product, category;
  final double units, price, margin, stock;
  Sale(this.date, this.sku, this.product, this.category, this.units, this.price,
      this.margin, this.stock);
  double get revenue => units * price;
  double get profit => revenue * margin;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Sale> sales = [];
  String status = 'Load a CSV to begin.';
  bool loading = false;

  double get revenue => sales.fold(0, (a, b) => a + b.revenue);
  double get profit => sales.fold(0, (a, b) => a + b.profit);
  double get units => sales.fold(0, (a, b) => a + b.units);
  int get skus => sales.map((e) => e.sku).toSet().length;

  Future<void> pickCsv() async {
    setState(() => loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Could not read the CSV file.');
      final text = String.fromCharCodes(bytes);
      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(text);
      if (rows.isEmpty) throw Exception('CSV is empty.');
      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      const required = [
        'date','sku','product','category','units_sold',
        'selling_price','profit_margin','stock'
      ];
      final missing = required.where((h) => !headers.contains(h)).toList();
      if (missing.isNotEmpty) {
        throw Exception('Missing required columns: ${missing.join(', ')}');
      }
      int idx(String h) => headers.indexOf(h);
      double num(dynamic v) => double.parse(v.toString().trim());
      final parsed = <Sale>[];
      for (final row in rows.skip(1)) {
        if (row.length < headers.length) continue;
        parsed.add(Sale(
          row[idx('date')].toString(),
          row[idx('sku')].toString(),
          row[idx('product')].toString(),
          row[idx('category')].toString(),
          num(row[idx('units_sold')]),
          num(row[idx('selling_price')]),
          num(row[idx('profit_margin')]),
          num(row[idx('stock')]),
        ));
      }
      if (parsed.isEmpty) throw Exception('No usable rows found.');
      setState(() {
        sales = parsed;
        status = '${parsed.length} rows analyzed from your CSV.';
      });
    } catch (e) {
      setState(() => status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => loading = false);
    }
  }

  void clear() => setState(() {
        sales = [];
        status = 'Load a CSV to begin.';
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 RETAILAI', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: sales.isEmpty ? null : clear, icon: const Icon(Icons.refresh))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Retail business intelligence',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Upload your retail CSV and get instant business insights.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : pickCsv,
                  icon: const Icon(Icons.upload_file),
                  label: Text(loading ? 'Analyzing…' : 'Upload CSV'),
                ),
                const SizedBox(height: 8),
                Text(status, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (sales.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              children: [
                Metric('Revenue', '₹${revenue.toStringAsFixed(0)}', Icons.payments),
                Metric('Gross Profit', '₹${profit.toStringAsFixed(0)}', Icons.trending_up),
                Metric('Units Sold', units.toStringAsFixed(0), Icons.shopping_cart),
                Metric('Active SKUs', '$skus', Icons.inventory_2),
              ],
            ),
            const SizedBox(height: 12),
            const Text('AI Priority Queue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...priorityRows().map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(e.$1),
                    subtitle: Text('${e.$2} • ${e.$3.toStringAsFixed(1)} units/day'),
                    trailing: Text('${e.$4.toStringAsFixed(1)} days'),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  List<(String, String, double, double)> priorityRows() {
    final bySku = <String, List<Sale>>{};
    for (final s in sales) {
      bySku.putIfAbsent(s.sku, () => []).add(s);
    }
    final result = <(String, String, double, double)>[];
    for (final list in bySku.values) {
      final s = list.first;
      final avg = list.fold(0.0, (a, b) => a + b.units) / max(1, list.length);
      final days = s.stock / max(avg, 0.01);
      result.add((s.product, s.category, avg, days));
    }
    result.sort((a, b) => a.$4.compareTo(b.$4));
    return result.take(10).toList();
  }
}

class Metric extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const Metric(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}
