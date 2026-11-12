// Create event screen - allows to create sup swimming events
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '10');

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _difficulty = 'Средний';
  bool _isPublic = true;
  bool _requiresEquipment = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите время')),
      );
      return;
    }
    // Здесь будет логика сохранения
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заплыв создан!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Создать заплыв')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  controller: _titleController,
                  label: 'Название',
                  icon: Icons.title,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _descriptionController,
                  label: 'Описание',
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите описание' : null,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _locationController,
                  label: 'Место',
                  icon: Icons.location_on,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Укажите место' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPicker(
                        icon: Icons.calendar_today,
                        label: 'Дата',
                        value: _selectedDate == null
                            ? 'Выбрать'
                            : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}',
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPicker(
                        icon: Icons.access_time,
                        label: 'Время',
                        value: _selectedTime == null
                            ? 'Выбрать'
                            : _selectedTime!.format(context),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _maxParticipantsController,
                  label: 'Максимум участников',
                  icon: Icons.group,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Укажите';
                    if (int.tryParse(v) == null) return 'Число';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Сложность',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Лёгкий', 'Средний', 'Сложный']
                      .map((d) => ChoiceChip(
                            label: Text(d),
                            selected: _difficulty == d,
                            onSelected: (_) =>
                                setState(() => _difficulty = d),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Открытый заплыв'),
                  subtitle: const Text('Виден всем пользователям'),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                SwitchListTile(
                  title: const Text('Требуется снаряжение'),
                  subtitle: const Text('Участники приносят своё'),
                  value: _requiresEquipment,
                  onChanged: (v) =>
                      setState(() => _requiresEquipment = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Создать заплыв'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: maxLines == 1 ? Icon(icon) : null,
      ),
    );
  }

  Widget _buildPicker({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
