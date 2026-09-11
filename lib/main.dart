import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const RetailAIApp());
}

class RetailAIApp extends StatelessWidget {
  const RetailAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RETAILAI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      ),
      home: const DashboardPage(),
    );
  }
}

class Sale {
  final String date;
  final String sku;
  final String product;
  final String category;
  final double unitsSold;
  final double sellingPrice;
  final double profitMargin;
  final double stock;

  const Sale({
    required this.date,
    required this.sku,
    required this.product,
    required this.category,
    required this.unitsSold,
    required this.sellingPrice,
    required this.profitMargin,
    required this.stock,
  });

  double get revenue => unitsSold * sellingPrice;

  double get profit => revenue * normalizedMargin;

  double get normalizedMargin {
    if (profitMargin > 1) return profitMargin / 100.0;
    return math.max(0, profitMargin);
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Sale> sales = [];
  String message = 'Upload a retail CSV to begin.';
  bool busy = false;

  double get totalRevenue =>
      sales.fold<double>(0, (sum, item) => sum + item.revenue);

  double get totalProfit =>
      sales.fold<double>(0, (sum, item) => sum + item.profit);

  double get totalUnits =>
      sales.fold<double>(0, (sum, item) => sum + item.unitsSold);

  int get activeSkus => sales.map((e) => e.sku).where((e) => e.isNotEmpty).toSet().length;

  Future<void> uploadCsv() async {
    if (busy) return;

    setState(() {
      busy = true;
      message = 'Selecting CSV…';
    });

    try {
      
      final file = await FilePicker.pickFile(
  type: FileType.custom,
  allowedExtensions: ['csv'],
);

if (file == null) return;

final bytes = await file.readAsBytes();
final text = utf8.decode(bytes);
        type: FileType.custom,
        allowedExtensions: <String>['csv'],
        withData: true,
      );

      if (result == null) {
        setState(() => message = 'No file selected.');
        return;
      }

      final picked = result.files.single;
      final bytes = picked.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('The selected CSV could not be read.');
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      final parsed = _parseCsv(text);

      if (parsed.isEmpty) {
        throw const FormatException('CSV is empty.');
      }

      final headers = parsed.first
          .map((e) => _normaliseHeader(e))
          .toList(growable: false);

      const required = <String>[
        'date',
        'sku',
        'product',
        'category',
        'units_sold',
        'selling_price',
        'profit_margin',
      ];

      final missing = required.where((h) => !headers.contains(h)).toList();

      if (missing.isNotEmpty) {
        throw FormatException(
          'Missing required columns: ${missing.join(', ')}',
        );
      }

      int indexOf(String name) => headers.indexOf(name);

      final stockIndex = _findHeader(headers, <String>[
        'stock_remaining',
        'stock',
        'inventory',
      ]);

      final rows = <Sale>[];

      for (final row in parsed.skip(1)) {
        if (row.length < headers.length) continue;

        final date = _cell(row, indexOf('date'));
        final sku = _cell(row, indexOf('sku'));
        final product = _cell(row, indexOf('product'));
        final category = _cell(row, indexOf('category'));

        final units = _toDouble(_cell(row, indexOf('units_sold')));
        final price = _toDouble(_cell(row, indexOf('selling_price')));
        final margin = _toDouble(_cell(row, indexOf('profit_margin')));
        final stock = stockIndex >= 0
            ? _toDouble(_cell(row, stockIndex))
            : 0.0;

        if (product.isEmpty || sku.isEmpty || units == null || price == null || margin == null) {
          continue;
        }

        rows.add(
          Sale(
            date: date,
            sku: sku,
            product: product,
            category: category.isEmpty ? 'Other' : category,
            unitsSold: math.max(0, units),
            sellingPrice: math.max(0, price),
            profitMargin: margin,
            stock: math.max(0, stock ?? 0),
          ),
        );
      }

      if (rows.isEmpty) {
        throw const FormatException(
          'No usable sales rows were found in the CSV.',
        );
      }

      setState(() {
        sales = rows;
        message = '${rows.length} rows analysed successfully.';
      });
    } catch (e) {
      setState(() {
        message = e.toString().replaceFirst('FormatException: ', '');
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clearData() {
    setState(() {
      sales = [];
      message = 'Upload a retail CSV to begin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final priority = _priorityProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🧠 RETAILAI',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (sales.isNotEmpty)
            IconButton(
              tooltip: 'Clear data',
              onPressed: clearData,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(),
            const SizedBox(height: 14),
            _uploadCard(),
            if (sales.isNotEmpty) ...[
              const SizedBox(height: 14),
              _metrics(),
              const SizedBox(height: 14),
              _overview(),
              const SizedBox(height: 14),
              _priorityQueue(priority),
              const SizedBox(height: 14),
              _insights(priority),
            ],
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'RETAILAI • Results are calculated only from the data supplied.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'RETAILAI',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'AI-powered retail intelligence for smarter inventory, demand and business decisions.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Upload your sales CSV and get instant business metrics and inventory priorities.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: busy ? null : uploadCsv,
              icon: const Icon(Icons.upload_file),
              label: Text(busy ? 'Processing…' : 'Upload CSV'),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: message.toLowerCase().contains('missing') ||
                        message.toLowerCase().contains('error') ||
                        message.toLowerCase().contains('could not')
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Required: date, sku, product, category, units_sold, selling_price, profit_margin. '
              'stock_remaining is recommended.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrics() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _metric('Revenue', '₹${_money(totalRevenue)}', Icons.payments),
        _metric('Gross Profit', '₹${_money(totalProfit)}', Icons.trending_up),
        _metric('Units Sold', _number(totalUnits), Icons.shopping_cart),
        _metric('Active SKUs', '$activeSkus', Icons.inventory_2),
      ],
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _overview() {
    final categories = <String, double>{};
    for (final sale in sales) {
      categories[sale.category] =
          (categories[sale.category] ?? 0) + sale.revenue;
    }

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue by Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...sorted.take(8).map(
              (entry) {
                final maxValue = sorted.isEmpty ? 1.0 : sorted.first.value;
                final fraction =
                    maxValue <= 0 ? 0.0 : entry.value / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text('₹${_money(entry.value)}'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: fraction),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityQueue(List<_Priority> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Priority Queue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No inventory data available.')
            else
              ...items.take(10).map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text('${item.days.toStringAsFixed(0)}'),
                  ),
                  title: Text(item.product),
                  subtitle: Text(
                    '${item.category} • ${item.avgDaily.toStringAsFixed(1)} units/day',
                  ),
                  trailing: Text(
                    item.days.isFinite
                        ? '${item.days.toStringAsFixed(1)} d'
                        : '∞',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _insights(List<_Priority> priority) {
    final topProducts = <String, double>{};
    for (final sale in sales) {
      topProducts[sale.product] =
          (topProducts[sale.product] ?? 0) + sale.unitsSold;
    }
    final top = topProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Insights',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (top.isNotEmpty)
              Text(
                'Top seller: ${top.first.key} (${_number(top.first.value)} units)',
              ),
            if (priority.isNotEmpty)
              Text(
                'Highest inventory priority: ${priority.first.product} '
                '(${priority.first.days.isFinite ? priority.first.days.toStringAsFixed(1) : '∞'} days of stock)',
              ),
            Text(
              'Estimated gross margin: '
              '${totalRevenue > 0 ? (totalProfit / totalRevenue * 100).toStringAsFixed(1) : '0.0'}%',
            ),
          ],
        ),
      ),
    );
  }

  List<_Priority> _priorityProducts() {
    final grouped = <String, List<Sale>>{};

    for (final sale in sales) {
      grouped.putIfAbsent(sale.sku, () => []).add(sale);
    }

    final result = <_Priority>[];

    for (final entry in grouped.entries) {
      final rows = entry.value;
      final first = rows.first;
      final avgDaily =
          rows.fold<double>(0, (sum, row) => sum + row.unitsSold) /
          math.max(1, rows.length);
      final days = avgDaily > 0 ? first.stock / avgDaily : double.infinity;

      result.add(
        _Priority(
          product: first.product,
          category: first.category,
          avgDaily: avgDaily,
          days: days,
        ),
      );
    }

    result.sort((a, b) => a.days.compareTo(b.days));
    return result;
  }
}

class _Priority {
  final String product;
  final String category;
  final double avgDaily;
  final double days;

  const _Priority({
    required this.product,
    required this.category,
    required this.avgDaily,
    required this.days,
  });
}

String _normaliseHeader(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('\uFEFF', '')
      .replaceAll(' ', '_');
}

int _findHeader(List<String> headers, List<String> names) {
  for (final name in names) {
    final index = headers.indexOf(name);
    if (index >= 0) return index;
  }
  return -1;
}

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return row[index].trim();
}

double? _toDouble(String value) {
  if (value.trim().isEmpty) return null;
  final cleaned = value
      .replaceAll(',', '')
      .replaceAll('₹', '')
      .replaceAll('%', '')
      .trim();
  return double.tryParse(cleaned);
}

String _money(double value) {
  return value.toStringAsFixed(0);
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// Small CSV parser supporting commas, quotes and escaped quotes.
List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  bool quoted = false;

  void finishCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void finishRow() {
    finishCell();
    if (row.length > 1 || row.first.trim().isNotEmpty) {
      rows.add(List<String>.from(row));
    }
    row.clear();
  }

  for (int i = 0; i < input.length; i++) {
    final char = input[i];

    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }

    if (!quoted && char == ',') {
      finishCell();
      continue;
    }

    if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++;
      }
      finishRow();
      continue;
    }

    cell.write(char);
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    finishRow();
  }

  return rows;
}
