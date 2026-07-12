import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/menu_item.dart';
import '../repository/menu_repository.dart';

/// Add or edit a menu item, including a simple customization-group builder and
/// add-on builder.
class AddEditItemPage extends StatefulWidget {
  final String stallId;
  final MenuItem? item; // null = add

  const AddEditItemPage({super.key, required this.stallId, this.item});

  @override
  State<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends State<AddEditItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MenuRepository();
  final _storage = StorageService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;

  final List<_CustomizationDraft> _customizations = [];
  final List<_AddOnDraft> _addOns = [];

  File? _pickedImage;
  String? _imageUrl;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(
      text: item == null ? '' : (item.price / 100).toStringAsFixed(2),
    );
    _category = TextEditingController(text: item?.category ?? '');
    _imageUrl = item?.imageUrl;
    for (final group in item?.customizations ?? []) {
      _customizations.add(_CustomizationDraft(
        name: group['name']?.toString() ?? '',
        options: (group['options'] as List?)
                ?.map((e) => e.toString())
                .join(', ') ??
            '',
      ));
    }
    for (final addon in item?.addOns ?? []) {
      _addOns.add(_AddOnDraft(
        name: addon['name']?.toString() ?? '',
        price: ((addon['price'] ?? 0) as num) / 100,
      ));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    for (final c in _customizations) {
      c.dispose();
    }
    for (final a in _addOns) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  List<Map<String, dynamic>> _buildCustomizations() {
    return _customizations
        .where((c) => c.nameController.text.trim().isNotEmpty)
        .map((c) => {
              'name': c.nameController.text.trim(),
              'options': c.optionsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            })
        .toList();
  }

  List<Map<String, dynamic>> _buildAddOns() {
    return _addOns
        .where((a) => a.nameController.text.trim().isNotEmpty)
        .map((a) => {
              'name': a.nameController.text.trim(),
              'price': rmToCents(a.priceController.text) ?? 0,
            })
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl;
      if (_pickedImage != null) {
        imageUrl = await _storage.uploadImage(
          _pickedImage!,
          'stalls/${widget.stallId}/menu/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      final priceCents = rmToCents(_price.text) ?? 0;
      if (_isEdit) {
        await _repository.updateItem(
          widget.item!.copyWith(
            name: _name.text.trim(),
            description: _description.text.trim(),
            price: priceCents,
            category: _category.text.trim(),
            imageUrl: imageUrl,
            customizations: _buildCustomizations(),
            addOns: _buildAddOns(),
          ),
        );
      } else {
        await _repository.addItem(
          stallId: widget.stallId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: priceCents,
          category: _category.text.trim(),
          imageUrl: imageUrl,
          customizations: _buildCustomizations(),
          addOns: _buildAddOns(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save item.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit item' : 'Add item')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEdit ? 'Save changes' : 'Add item'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePicker(
              file: _pickedImage,
              url: _imageUrl,
              onTap: _pickImage,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (RM)',
                      prefixText: 'RM ',
                    ),
                    validator: Validators.price,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _category,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Customizations',
              onAdd: () =>
                  setState(() => _customizations.add(_CustomizationDraft())),
            ),
            for (var i = 0; i < _customizations.length; i++)
              _CustomizationTile(
                draft: _customizations[i],
                onRemove: () =>
                    setState(() => _customizations.removeAt(i)),
              ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Add-ons',
              onAdd: () => setState(() => _addOns.add(_AddOnDraft())),
            ),
            for (var i = 0; i < _addOns.length; i++)
              _AddOnTile(
                draft: _addOns[i],
                onRemove: () => setState(() => _addOns.removeAt(i)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final File? file;
  final String? url;
  final VoidCallback onTap;

  const _ImagePicker({this.file, this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (file != null) {
      child = Image.file(file!, fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      child = Image.network(url!, fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.warmGrey),
            SizedBox(height: 8),
            Text('Add photo'),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.title),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _CustomizationTile extends StatelessWidget {
  final _CustomizationDraft draft;
  final VoidCallback onRemove;
  const _CustomizationTile({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: draft.nameController,
              decoration: const InputDecoration(
                labelText: 'Group (e.g. Size)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: draft.optionsController,
              decoration: const InputDecoration(
                labelText: 'Options (comma-separated)',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddOnTile extends StatelessWidget {
  final _AddOnDraft draft;
  final VoidCallback onRemove;
  const _AddOnTile({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: draft.nameController,
              decoration: const InputDecoration(
                labelText: 'Add-on name',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: draft.priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: 'RM ',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _CustomizationDraft {
  final TextEditingController nameController;
  final TextEditingController optionsController;

  _CustomizationDraft({String name = '', String options = ''})
      : nameController = TextEditingController(text: name),
        optionsController = TextEditingController(text: options);

  void dispose() {
    nameController.dispose();
    optionsController.dispose();
  }
}

class _AddOnDraft {
  final TextEditingController nameController;
  final TextEditingController priceController;

  _AddOnDraft({String name = '', double price = 0})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(
          text: price == 0 ? '' : price.toStringAsFixed(2),
        );

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}
