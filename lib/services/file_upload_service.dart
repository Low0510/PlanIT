import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:planit_schedule_manager/models/task_file.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class FileUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload a single file and return its download URL
  Future<String> uploadFile(File file, String taskId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create a unique filename
    String fileExtension = path.extension(file.path);
    String fileName = '${const Uuid().v4()}$fileExtension';
    
    // Create reference to the file location
    String filePath = 'users/${user.uid}/tasks/$taskId/$fileName';
    Reference storageRef = _storage.ref().child(filePath);

    try {
      // Upload the file
      await storageRef.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get and return the download URL
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload multiple files and return their download URLs
  Future<List<TaskFile>> uploadFiles(List<File> files, String taskId) async {
    List<TaskFile> uploadedFiles = [];

    for (File file in files) {
      String downloadUrl = await uploadFile(file, taskId);
      uploadedFiles.add(
        TaskFile(
          id: const Uuid().v4(),
          name: path.basename(file.path),
          url: downloadUrl,
          type: _getFileType(file.path),
          uploadedAt: DateTime.now(),
        ),
      );
    }

    return uploadedFiles;
  }

  // Delete a file from storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // Helper method to determine content type
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.doc':
      case '.docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  // Helper method to determine file type category
  String _getFileType(String filePath) {
    String ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) {
      return 'image';
    } else if (ext == '.pdf') {
      return 'pdf';
    } else if (['.doc', '.docx'].contains(ext)) {
      return 'document';
    } else {
      return 'other';
    }
  }
}