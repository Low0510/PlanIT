import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:planit_schedule_manager/services/file_upload_service.dart';

class FileUploadWidget extends StatefulWidget {
  final List<File> selectedFiles;
  final Function(List<File>) onFilesChanged;
  final FileUploadService? fileUploadService;

  const FileUploadWidget({
    Key? key,
    required this.selectedFiles,
    required this.onFilesChanged,
    this.fileUploadService,
  }) : super(key: key);

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attachments (${widget.selectedFiles.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _isGridView = !_isGridView);
                    },
                    icon: Icon(
                      _isGridView ? Icons.list : Icons.grid_view,
                      color: Colors.blue[400],
                    ),
                    tooltip: '${_isGridView ? "List" : "Grid"} View',
                  ),
                  IconButton(
                    onPressed: _pickFiles,
                    icon: Icon(Icons.add_circle_outline, color: Colors.blue[400]),
                    tooltip: 'Add Files',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.selectedFiles.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, 
                    size: 48, 
                    color: Colors.grey[400]
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Drop files here or click to upload',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _isGridView ? _buildGridView() : _buildListView(),
      ],
    );
  }

  Widget _buildListView() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.selectedFiles.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[200],
          height: 1,
        ),
        itemBuilder: (context, index) {
          return _buildFileItem(index, false);
        },
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.selectedFiles.length,
      itemBuilder: (context, index) {
        return _buildFileItem(index, true);
      },
    );
  }

  Widget _buildFileItem(int index, bool isGrid) {
    final file = widget.selectedFiles[index];
    final fileName = file.path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();
    
    final isImage = ['jpg', 'jpeg', 'png'].contains(fileExtension);
    
    Widget filePreview;
    if (isImage) {
      filePreview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.image, color: Colors.grey[400], size: 40),
        ),
      );
    } else {
      IconData fileIcon = fileExtension == 'pdf' 
          ? Icons.picture_as_pdf
          : Icons.insert_drive_file;
      filePreview = Icon(fileIcon, color: Colors.grey[600], size: 40);
    }

    Widget content = InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isImage)
                      Image.file(
                        file,
                        fit: BoxFit.contain,
                      )
                    else
                      Icon(
                        Icons.insert_drive_file,
                        size: 100,
                        color: Colors.grey[600],
                      ),
                    const SizedBox(height: 16),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: isGrid
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: filePreview),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red[300], size: 16),
                        onPressed: () => _removeFile(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListTile(
              leading: SizedBox(
                width: 40,
                height: 40,
                child: filePreview,
              ),
              title: Text(
                fileName,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.close, color: Colors.red[300], size: 20),
                onPressed: () => _removeFile(index),
              ),
            ),
    );

    return content;
  }

  void _removeFile(int index) {
    List<File> updatedFiles = List.from(widget.selectedFiles);
    updatedFiles.removeAt(index);
    widget.onFilesChanged(updatedFiles);
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      allowMultiple: true,
    );
    
    if (result != null) {
      List<File> updatedFiles = List.from(widget.selectedFiles);
      updatedFiles.addAll(result.paths.map((path) => File(path!)).toList());
      widget.onFilesChanged(updatedFiles);
    }
  }
}