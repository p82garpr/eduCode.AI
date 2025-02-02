import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return ElevatedButton(
          onPressed: authProvider.isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: authProvider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(text),
        );
      },
    );
  }
} 