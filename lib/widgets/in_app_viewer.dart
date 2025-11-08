import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class InAppViewer extends StatefulWidget {
  final String url;
  final String type;
  final String title;

  const InAppViewer({
    Key? key,
    required this.url,
    required this.type,
    required this.title,
  }) : super(key: key);

  @override
  State<InAppViewer> createState() => _InAppViewerState();
}

class _InAppViewerState extends State<InAppViewer> {
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    _pdfViewerController = PdfViewerController();
    super.initState();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: widget.type == 'pdf'
            ? [
                IconButton(
                  icon: Icon(Icons.zoom_in),
                  onPressed: () {
                    _pdfViewerController.zoomLevel++;
                  },
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out),
                  onPressed: () {
                    _pdfViewerController.zoomLevel--;
                  },
                ),
              ]
            : null,
      ),
      body: _buildViewer(),
    );
  }

  Widget _buildViewer() {
    switch (widget.type) {
      case 'image':
        return Container(
          child: PhotoView(
            imageProvider: NetworkImage(widget.url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: BoxDecoration(
              color: Colors.black,
            ),
          ),
        );
      case 'pdf':
        return SfPdfViewer.network(
          widget.url,
          controller: _pdfViewerController,
          canShowScrollHead: true,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading PDF: ${details.error}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF loaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      default:
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));
        
        return WebViewWidget(
          controller: controller,
        );
    }
  }
}