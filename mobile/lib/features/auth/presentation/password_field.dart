import 'package:flutter/material.dart';

import '../../../shared/widgets/app_text_form_field.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.labelText = 'Password',
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.externalLabel = false,
    this.showVisibilityToggle = true,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final String labelText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool externalLabel;
  final bool showVisibilityToggle;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      labelText: widget.labelText,
      externalLabel: widget.externalLabel,
      required: true,
      suffixIcon: widget.showVisibilityToggle
          ? IconButton(
              tooltip: _obscureText ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
              icon: Icon(
                _obscureText
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            )
          : null,
    );
  }
}
