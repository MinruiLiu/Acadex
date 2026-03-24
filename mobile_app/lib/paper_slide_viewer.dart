import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'acadex_constants.dart';
import 'paper.dart';

/// One page in a batch preview: downloads and shows a single paper file.
class PaperSlideViewer extends StatefulWidget {
  const PaperSlideViewer({super.key, required this.paper});

  final Paper paper;

  @override
  State<PaperSlideViewer> createState() => _PaperSlideViewerState();
}

class _PaperSlideViewerState extends State<PaperSlideViewer> {
  bool _loading = true;
  String? _error;
  Uint8List? _bytes;
  PdfControllerPinch? _pdfController;

  bool get _isPdf {
    if (paperContentTypeIsPdf(widget.paper.contentType)) return true;
    return paperStoragePathLooksLikePdf(widget.paper.storagePath);
  }

  bool get _isImage {
    if (paperContentTypeIsImage(widget.paper.contentType)) return true;
    final ext = p.extension(widget.paper.storagePath).toLowerCase();
    return ext == '.png' || ext == '.jpg' || ext == '.jpeg';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _pdfController?.dispose();
      _pdfController = null;
      _bytes = null;
    });
    try {
      final data = await Supabase.instance.client.storage
          .from(kExamPapersBucket)
          .download(widget.paper.storagePath);
      if (!mounted) return;

      PdfControllerPinch? pdfCtrl;
      if (_isPdf) {
        pdfCtrl = PdfControllerPinch(
          document: PdfDocument.openData(data),
        );
      }

      setState(() {
        _bytes = data;
        _pdfController = pdfCtrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: Text('No data'));
    }

    if (_isPdf) {
      final ctrl = _pdfController;
      if (ctrl == null) {
        return const Center(child: Text('Could not open PDF'));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PdfViewPinch(
          controller: ctrl,
          backgroundDecoration: BoxDecoration(color: bg),
          padding: 8,
        ),
      );
    }

    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('Could not decode image'),
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This file type cannot be previewed here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      ),
    );
  }
}
