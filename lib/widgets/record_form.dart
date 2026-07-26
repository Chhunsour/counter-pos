import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../models/backend_test_item.dart';

typedef RecordSubmit = Future<void> Function(
  String title,
  String description,
  String status,
  String? imageName,
  String? imageData,
);

class RecordForm extends StatefulWidget {
  const RecordForm({
    required this.onSubmit,
    this.initialItem,
    super.key,
  });

  final RecordSubmit onSubmit;
  final BackendTestItem? initialItem;

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _pasteFocusNode = FocusNode();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageNameController;
  late String _status;
  Uint8List? _imageBytes;
  String? _imageMimeType;
  ProductImageSize? _imageSize;
  bool _saving = false;
  String? _error;

  static const statuses = ['pending', 'active', 'inactive'];
  static const maxImageBytes = 2 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialItem?.title);
    _descriptionController =
        TextEditingController(text: widget.initialItem?.description);
    _imageNameController =
        TextEditingController(text: widget.initialItem?.imageName);
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
      final size = await inspectSquareProductImage(bytes);
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
        _descriptionController.text.trim(),
        _status,
        _imageBytes == null ? null : _imageNameController.text.trim(),
        _imageBytes == null
            ? null
            : 'data:$_imageMimeType;base64,${base64Encode(_imageBytes!)}',
      );
      if (mounted && widget.initialItem == null) {
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        _imageNameController.clear();
        setState(() {
          _status = statuses.first;
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
              hintText: r'$4.50 · Iced · 16 oz',
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
                    'Paste from clipboard · Ctrl/⌘V',
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
                height: 160,
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Text('Image preview unavailable')),
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
                    '${_imageSize!.width}×${_imageSize!.height} · 1:1 square',
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
              'Square image required · 1080×1080 recommended · maximum 2 MB',
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

Future<ProductImageSize> inspectSquareProductImage(Uint8List bytes) async {
  if (bytes.length > _RecordFormState.maxImageBytes) {
    throw const FormatException('Choose an image smaller than 2 MB.');
  }

  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;
    if (image.width != image.height) {
      throw FormatException(
        'Use a square image (1:1). This image is '
        '${image.width}×${image.height}.',
      );
    }
    return ProductImageSize(image.width, image.height);
  } catch (error) {
    if (error is FormatException) rethrow;
    throw const FormatException('The image could not be decoded.');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
