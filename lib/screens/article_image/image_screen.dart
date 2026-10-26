import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smb_connect/smb_connect.dart';


final Map<String, Uint8List> _globalImageCache = {};

class ImagePreviewDialog extends StatefulWidget {
  final String host;
  final String username;
  final String password;
  final String fullFilePath;
  final String fileName;

  const ImagePreviewDialog({
    super.key,
    required this.host,
    required this.username,
    required this.password,
    required this.fullFilePath,
    required this.fileName,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  bool _isLoading = true;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPreviewBytes();
  }

  Future<void> _fetchPreviewBytes() async {
    if (_globalImageCache.containsKey(widget.fullFilePath)) {
      setState(() {
        _imageBytes = _globalImageCache[widget.fullFilePath];
        _isLoading = false;
      });
      return;
    }

    SmbConnect? connection;
    try {
      connection = await SmbConnect.connectAuth(
        host: widget.host,
        domain: '',
        username: widget.username,
        password: widget.password,
      );

      final fileObj = await connection.file(widget.fullFilePath);
      final stream = await connection.openRead(fileObj);

      final List<int> bytesList = [];
      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }

      final bytes = Uint8List.fromList(bytesList);
      _globalImageCache[widget.fullFilePath] = bytes;

      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });

      await connection.close();
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل معاينة الصورة';
        _isLoading = false;
      });
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.fileName, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

// ==========================================
// 4. SCREEN: ZOOMABLE FULL IMAGE VIEWER (WITH CACHE)
// ==========================================
class ImageViewerScreen extends StatefulWidget {
  final String host;
  final String username;
  final String password;
  final String fullFilePath;
  final String fileName;

  const ImageViewerScreen({
    super.key,
    required this.host,
    required this.username,
    required this.password,
    required this.fullFilePath,
    required this.fileName,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _isLoading = true;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchImageBytes();
  }

  Future<void> _fetchImageBytes() async {
    if (_globalImageCache.containsKey(widget.fullFilePath)) {
      setState(() {
        _imageBytes = _globalImageCache[widget.fullFilePath];
        _isLoading = false;
      });
      return;
    }

    SmbConnect? connection;
    try {
      connection = await SmbConnect.connectAuth(
        host: widget.host,
        domain: '',
        username: widget.username,
        password: widget.password,
      );

      final fileObj = await connection.file(widget.fullFilePath);
      final stream = await connection.openRead(fileObj);

      final List<int> bytesList = [];
      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }

      final bytes = Uint8List.fromList(bytesList);
      _globalImageCache[widget.fullFilePath] = bytes;

      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });

      await connection.close();
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل بيانات الصورة: $e';
        _isLoading = false;
      });
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: 'إعادة ضبط التكبير',
              onPressed: _resetZoom,
            ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('جاري تحميل الصورة من الخادم...'),
          ],
        )
            : _error != null
            ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        )
            : InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}