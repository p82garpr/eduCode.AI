import 'package:flutter/material.dart';

class EnrollmentDialog extends StatefulWidget {
  final String subjectName;

  const EnrollmentDialog({
    super.key,
    required this.subjectName,
  });

  @override
  State<EnrollmentDialog> createState() => _EnrollmentDialogState();
}

class _EnrollmentDialogState extends State<EnrollmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Inscribirse en ${widget.subjectName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _accessCodeController,
          decoration: InputDecoration(
            labelText: 'Código de acceso',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
          obscureText: _obscureText,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese el código de acceso';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _accessCodeController.text);
            }
          },
          child: const Text('Inscribirse'),
        ),
      ],
    );
  }
} 