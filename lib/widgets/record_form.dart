import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../models/backend_test_item.dart';
import '../models/pos_category.dart';

typedef RecordSubmit = Future<void> Function(
  String title,
  String description,
  String status,
  String? imageName,
  String? imageData,
  String? barcode,
  Object? categoryId,
);

class RecordForm extends StatefulWidget {
  const RecordForm({
    required this.onSubmit,
    this.initialItem,
    this.categories = const [],
    super.key,
  });

  final RecordSubmit onSubmit;
  final BackendTestItem? initialItem;
  final List<PosCategory> categories;

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _pasteFocusNode = FocusNode();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageNameController;
  late final TextEditingController _barcodeController;
  late String _status;
  Object? _categoryId;
  Uint8List? _imageBytes;
  String? _imageMimeType;
  ProductImageSize? _imageSize;
  bool _saving = false;
  String? _error;

  static const statuses = ['active', 'pending', 'inactive'];
  static const maxImageBytes = 2 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialItem?.title);
    _descriptionController = TextEditingController(
      text: productDetailsForEditing(widget.initialItem?.description),
    );
    _imageNameController =
        TextEditingController(text: widget.initialItem?.imageName);
    _barcodeController =
        TextEditingController(text: widget.initialItem?.barcode);
    _categoryId = widget.initialItem?.categoryId;
    _imageBytes = widget.initialItem?.imageBytes;
    _imageMimeType = _mimeTypeFromData(widget.initialItem?.imageData);
    final initialStatus = widget.initialItem?.status;
    _status =
        statuses.contains(initialStatus) ? initialStatus! : statuses.first;
  }

  @override
  void dispose() {
    _pasteFocusNode.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _imageNameController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        withData: true,
      );
      if (result == null || !mounted) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = 'The selected image could not be read.');
        return;
      }

      final mimeType = _mimeTypeFromExtension(file.extension);
      if (mimeType == null) {
        setState(() => _error = 'Use PNG, JPEG, WebP, or GIF.');
        return;
      }
      await _useImage(bytes, mimeType, file.name);
    } catch (error) {
      if (mounted) setState(() => _error = 'Image picker error: $error');
    }
  }

  Future<void> _pasteImage() async {
    if (_saving) return;
    _pasteFocusNode.requestFocus();
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          setState(() => _error =
              'No image found in the clipboard. Copy an image, then try again.');
        }
        return;
      }
      final mimeType = _mimeTypeFromBytes(bytes);
      if (mimeType == null) {
        if (mounted) {
          setState(() => _error = 'Paste a PNG, JPEG, WebP, or GIF image.');
        }
        return;
      }
      final extension = mimeType == 'image/jpeg'
          ? 'jpg'
          : mimeType.replaceFirst('image/', '');
      await _useImage(
        bytes,
        mimeType,
        'pasted-product-${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Clipboard access failed. Allow clipboard permission and try again.');
      }
    }
  }

  Future<void> _useImage(
    Uint8List bytes,
    String mimeType,
    String name,
  ) async {
    try {
      final size = await inspectProductImage(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageMimeType = mimeType;
        _imageSize = size;
        _imageNameController.text = name;
        _error = null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageMimeType = null;
      _imageSize = null;
      _imageNameController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _titleController.text.trim(),
        productDetailsForStorage(_descriptionController.text),
        _status,
        _imageBytes == null ? null : _imageNameController.text.trim(),
        _imageBytes == null
            ? null
            : 'data:$_imageMimeType;base64,${base64Encode(_imageBytes!)}',
        _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        _categoryId,
      );
      if (mounted && widget.initialItem == null) {
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        _imageNameController.clear();
        _barcodeController.clear();
        setState(() {
          _status = statuses.first;
          _categoryId = null;
          _imageBytes = null;
          _imageMimeType = null;
          _imageSize = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _titleController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Product name',
              hintText: 'Example: Iced latte',
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Product name is required.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Price and details',
              prefixText: r'$ ',
              hintText: '4.50 · Iced · 16 oz',
              helperText: 'Put the price first so the register can read it.',
            ),
            minLines: 2,
            maxLines: 4,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Price and details are required.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Availability'),
            items: statuses
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(switch (status) {
                        'active' => 'Available',
                        'inactive' => 'Hidden',
                        _ => 'Draft',
                      }),
                    ))
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _status = value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcodeController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Barcode',
              hintText: 'Optional',
              suffixIcon: TextButton(
                onPressed: _saving
                    ? null
                    : () => _barcodeController.text = generateEan13(),
                child: const Text('Auto generate'),
              ),
            ),
            validator: (value) {
              final barcode = value?.trim() ?? '';
              if (barcode.isEmpty) return null;
              return barcode.length < 8 || barcode.length > 14
                  ? 'Use 8 to 14 digits.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Object>(
            initialValue: widget.categories.any(
              (category) => category.id == _categoryId,
            )
                ? _categoryId
                : null,
            decoration: InputDecoration(
              labelText: 'Category',
              hintText: widget.categories.isEmpty
                  ? 'Create a category first'
                  : 'No category',
            ),
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem<Object>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged:
                _saving ? null : (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): _pasteImage,
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                meta: true,
              ): _pasteImage,
            },
            child: Focus(
              focusNode: _pasteFocusNode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _imageBytes == null ? 'Upload' : 'Replace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pasteImage,
                          icon: const Icon(Icons.content_paste_rounded),
                          label: const Text('Paste'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Clipboard: Ctrl+V / Cmd+V',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Image preview unavailable'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_imageSize != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: Color(0xFF4E7C60),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_imageSize!.width}×${_imageSize!.height} original · '
                    'card crops to 1:1',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4E7C60),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageNameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Product image name',
                hintText: 'Example: iced-coffee-front.jpg',
              ),
              maxLength: 160,
              validator: (value) =>
                  _imageBytes != null && (value == null || value.trim().isEmpty)
                      ? 'Image name is required.'
                      : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : _removeImage,
                icon: const Icon(Icons.close),
                label: const Text('Remove image'),
              ),
            ),
          ] else
            Text(
              'Any image ratio · auto-cropped to square · maximum 2 MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
                widget.initialItem == null ? 'Add product' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  static String? _mimeTypeFromExtension(String? extension) {
    return switch (extension?.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => null,
    };
  }

  static String? _mimeTypeFromData(String? data) {
    if (data == null || !data.startsWith('data:image/')) return null;
    final end = data.indexOf(';base64,');
    return end < 5 ? null : data.substring(5, end);
  }

  static String? _mimeTypeFromBytes(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 6 &&
        String.fromCharCodes(bytes.sublist(0, 3)) == 'GIF') {
      return 'image/gif';
    }
    return null;
  }
}

class ProductImageSize {
  const ProductImageSize(this.width, this.height);

  final int width;
  final int height;
}

Future<ProductImageSize> inspectProductImage(Uint8List bytes) async {
  if (bytes.length > _RecordFormState.maxImageBytes) {
    throw const FormatException('Choose an image smaller than 2 MB.');
  }

  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;
    return ProductImageSize(image.width, image.height);
  } catch (error) {
    if (error is FormatException) rethrow;
    throw const FormatException('The image could not be decoded.');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

String productDetailsForEditing(String? value) {
  final details = (value ?? '').trim();
  return details.startsWith(r'$') ? details.substring(1).trimLeft() : details;
}

String productDetailsForStorage(String value) {
  final details = value.trim();
  return details.startsWith(r'$') ? details : '\$$details';
}

String generateEan13([Random? random]) {
  final source = random ?? Random.secure();
  final base = '2${List.generate(11, (_) => source.nextInt(10)).join()}';
  var sum = 0;
  for (var index = 0; index < base.length; index++) {
    final digit = int.parse(base[index]);
    sum += index.isEven ? digit : digit * 3;
  }
  return '$base${(10 - sum % 10) % 10}';
}
