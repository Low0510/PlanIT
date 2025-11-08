import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ErrorToast {
  static void show(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      alignment: Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      icon: const Icon(Icons.error_outline, color: Colors.white),
      primaryColor: Colors.red,
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 16,
          offset: Offset(0, 8),
          spreadRadius: 0,
        )
      ],
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.always,
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      callbacks: ToastificationCallbacks(
        onTap: (toastItem) => print('Error toast ${toastItem.id} tapped'),
        onCloseButtonTap: (toastItem) => print('Error toast ${toastItem.id} close button tapped'),
        onAutoCompleteCompleted: (toastItem) => print('Error toast ${toastItem.id} auto complete completed'),
        onDismissed: (toastItem) => print('Error toast ${toastItem.id} dismissed'),
      ),
    );
  }
}

class SuccessToast {
  static void show(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text('Success', style: TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      alignment: Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      primaryColor: Colors.green,
      backgroundColor: Colors.green.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 16,
          offset: Offset(0, 8),
          spreadRadius: 0,
        )
      ],
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.always,
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      callbacks: ToastificationCallbacks(
        onTap: (toastItem) => print('Success toast ${toastItem.id} tapped'),
        onCloseButtonTap: (toastItem) => print('Success toast ${toastItem.id} close button tapped'),
        onAutoCompleteCompleted: (toastItem) => print('Success toast ${toastItem.id} auto complete completed'),
        onDismissed: (toastItem) => print('Success toast ${toastItem.id} dismissed'),
      ),
    );
  }
}