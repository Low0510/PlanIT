import 'dart:io';
import 'package:flutter/material.dart';

class DialogHelper {
  static Future<bool?> showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Leaving Already?",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        content: const Text(
          "Are you sure you want to exit the app?",
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Stay"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              exit(0);
            },
            child: const Text("Exit"),
          ),
        ],
      ),
    );
  }
}
