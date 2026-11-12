import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';

class GearScreen extends StatefulWidget {
  const GearScreen({super.key});

  @override
  State<GearScreen> createState() => _GearScreenState();
}

class _GearScreenState extends State<GearScreen> {
  List<GearItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.instance.getList('/gear/mine');
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => GearItem.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  Future<void> _edit(GearItem? item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GearFormScreen(item: item)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(GearItem item) async {
    try {
      await ApiClient.instance.delete('/gear/${item.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Снаряжение'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _edit(null),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items!.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.kayaking,
                              text: 'Добавьте своё снаряжение'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _items!.length,
                          itemBuilder: (_, i) {
                            final g = _items![i];
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.inventory_2,
                                      color: AppColors.primary, size: 22),
                                ),
                                title: Text(g.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_spec(g),
                                        style: const TextStyle(fontSize: 12)),
                                    if (g.notes != null &&
                                        g.notes!.isNotEmpty)
                                      Text(g.notes!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') _edit(g);
                                    if (v == 'del') _delete(g);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Редактировать')),
                                    PopupMenuItem(
                                        value: 'del',
                                        child: Text('Удалить')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  String _spec(GearItem g) {
    final parts = <String>[
      if (g.lengthCm != null) '${g.lengthCm} см',
      if (g.widthCm != null) '${g.widthCm} см',
      if (g.volumeL != null) '${g.volumeL} л',
      if (g.weightKg != null) '${g.weightKg} кг',
    ];
    return parts.isEmpty ? g.category : parts.join(' · ');
  }
}

class GearFormScreen extends StatefulWidget {
  const GearFormScreen({super.key, this.item});

  final GearItem? item;

  @override
  State<GearFormScreen> createState() => _GearFormScreenState();
}

class _GearFormScreenState extends State<GearFormScreen> {
  String _category = 'board';
  late final TextEditingController _brand =
      TextEditingController(text: widget.item?.brand ?? '');
  late final TextEditingController _model =
      TextEditingController(text: widget.item?.model ?? '');
  late final TextEditingController _length =
      TextEditingController(text: widget.item?.lengthCm?.toString() ?? '');
  late final TextEditingController _width =
      TextEditingController(text: widget.item?.widthCm?.toString() ?? '');
  late final TextEditingController _volume =
      TextEditingController(text: widget.item?.volumeL?.toString() ?? '');
  late final TextEditingController _weight =
      TextEditingController(text: widget.item?.weightKg?.toString() ?? '');
  late final TextEditingController _material =
      TextEditingController(text: widget.item?.material ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.item?.notes ?? '');
  bool _loading = false;

  static const _categories = <String, String>{
    'board': 'Доска',
    'paddle': 'Весло',
    'wetsuit': 'Гидрокостюм',
    'vest': 'Жилет',
    'leash': 'Лиш',
    'pump': 'Насос',
    'drybag': 'Сумка',
    'other': 'Другое',
  };

  @override
  void initState() {
    super.initState();
    if (widget.item != null) _category = widget.item!.category;
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _length.dispose();
    _width.dispose();
    _volume.dispose();
    _weight.dispose();
    _material.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final data = <String, dynamic>{
      'category': _category,
      if (_brand.text.trim().isNotEmpty) 'brand': _brand.text.trim(),
      if (_model.text.trim().isNotEmpty) 'model': _model.text.trim(),
      if (_length.text.isNotEmpty) 'lengthCm': int.tryParse(_length.text),
      if (_width.text.isNotEmpty) 'widthCm': int.tryParse(_width.text),
      if (_volume.text.isNotEmpty) 'volumeL': int.tryParse(_volume.text),
      if (_weight.text.isNotEmpty) 'weightKg': double.tryParse(_weight.text),
      if (_material.text.trim().isNotEmpty) 'material': _material.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };
    try {
      if (widget.item == null) {
        await ApiClient.instance.post('/gear', data: data);
      } else {
        await ApiClient.instance.patch('/gear/${widget.item!.id}', data: data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.item == null ? 'Новое снаряжение' : 'Редактировать')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: _categories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'board'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(hintText: 'Бренд'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(hintText: 'Модель'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: _length,
                    decoration: const InputDecoration(hintText: 'Длина, см'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                    controller: _width,
                    decoration: const InputDecoration(hintText: 'Ширина, см'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                    controller: _volume,
                    decoration: const InputDecoration(hintText: 'Объём, л'),
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: _weight,
                    decoration: const InputDecoration(hintText: 'Вес, кг'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                    controller: _material,
                    decoration: const InputDecoration(hintText: 'Материал')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(hintText: 'Заметки'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.item == null ? 'Добавить' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}