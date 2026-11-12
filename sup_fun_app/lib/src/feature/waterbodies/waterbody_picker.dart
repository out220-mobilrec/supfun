import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';

class WaterbodyPickerSheet extends StatefulWidget {
  const WaterbodyPickerSheet({super.key});

  @override
  State<WaterbodyPickerSheet> createState() => _WaterbodyPickerSheetState();
}

class _WaterbodyPickerSheetState extends State<WaterbodyPickerSheet> {
  final _query = TextEditingController();
  List<WaterBody> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.instance.getList('/waterbodies', query: {
        if (q.isNotEmpty) 'q': q,
        'limit': 50,
      });
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => WaterBody.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(hintText: 'Поиск водоёма'),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoading2()
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final wb = _items[i];
                      return ListTile(
                        leading: const Icon(Icons.water, color: AppColors.sea),
                        title: Text(wb.name),
                        subtitle: wb.region != null ? Text(wb.region!) : null,
                        onTap: () => Navigator.pop(context, wb),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AppLoading2 extends StatelessWidget {
  const AppLoading2({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}