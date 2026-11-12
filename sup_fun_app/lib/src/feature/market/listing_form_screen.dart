import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import 'marketplace_screen.dart';

class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listing});

  final Listing? listing;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  String _category = 'boards';
  String _currency = 'RUB';
  late final TextEditingController _title =
      TextEditingController(text: widget.listing?.title ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.listing?.description ?? '');
  late final TextEditingController _price =
      TextEditingController(text: widget.listing?.price?.toStringAsFixed(0) ?? '');
  late final TextEditingController _city =
      TextEditingController(text: widget.listing?.city ?? '');
  List<String> _photos = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) _category = widget.listing!.category;
    _photos = widget.listing?.photos ?? const [];
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Максимум 6 фото')));
      return;
    }
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final url = await ApiClient.instance.uploadImage('files', file.path);
      if (url.isNotEmpty) setState(() => _photos = [..._photos, url]);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название: минимум 3 символа')));
      return;
    }
    if (_city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите город')));
      return;
    }
    if (_price.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите цену')));
      return;
    }
    setState(() => _loading = true);
    final data = <String, dynamic>{
      'category': _category,
      'title': _title.text.trim(),
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      if (_price.text.isNotEmpty) 'price': double.tryParse(_price.text),
      'currency': _currency,
      'city': _city.text.trim(),
      'photos': _photos,
    };
    try {
      if (widget.listing == null) {
        await ApiClient.instance.post('/marketplace/listings', data: data);
      } else {
        await ApiClient.instance
            .patch('/marketplace/listings/${widget.listing!.id}', data: data);
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
          title:
              Text(widget.listing == null ? 'Новое объявление' : 'Редактировать')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: kListingCategories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'boards'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(hintText: 'Описание'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: const [
              DropdownMenuItem(value: 'RUB', child: Text('RUB ₽')),
              DropdownMenuItem(value: 'USD', child: Text('USD \$')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR €')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'RUB'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(hintText: 'Цена'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(hintText: 'Город'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Фото',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(AppConfig.absUrl(_photos[i]),
                          width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(
                            () => _photos.removeAt(i)),
                        child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.listing == null ? 'Опубликовать' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}