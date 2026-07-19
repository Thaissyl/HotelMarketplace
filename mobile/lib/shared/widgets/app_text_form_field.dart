import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextFormField extends StatefulWidget {
  const AppTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final int maxLines;

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _showKeyboard();
    }
  }

  void _showKeyboard() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }

      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      obscureText: widget.obscureText,
      enableSuggestions: widget.enableSuggestions,
      autocorrect: widget.autocorrect,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      onTap: _showKeyboard,
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}
