import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';

class AppErrorPresenter {
  const AppErrorPresenter._();

  static bool isUnauthorized(Object error) {
    return _unwrap(error) is UnauthorizedApiException;
  }

  static void showSnackBar(
    BuildContext context,
    Object error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = friendlyMessage(error);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static Future<void> showBottomSheet(
    BuildContext context,
    Object error, {
    String? title,
  }) {
    final effectiveTitle = title ?? friendlyTitle(error);
    final message = friendlyMessage(error);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      effectiveTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String friendlyMessage(Object error) {
    error = _unwrap(error);

    if (error is String) {
      return error;
    }

    if (error is UnauthorizedApiException) {
      return 'Please sign in again, or check that your email and password are correct.';
    }

    if (error is ForbiddenApiException) {
      return 'You do not have access to this hotel or operation.';
    }

    if (error is BadRequestApiException) {
      return error.message;
    }

    if (error is ConflictApiException) {
      return error.message;
    }

    if (error is LockedApiException) {
      return error.message;
    }

    if (error is NotFoundApiException) {
      return error.message;
    }

    if (error is ServerApiException) {
      return 'The server is temporarily unavailable. Please try again shortly.';
    }

    if (error is NetworkApiException) {
      return 'Unable to connect. Please check your network and API address.';
    }

    if (error is ApiException) {
      return error.message;
    }

    return 'The request could not be completed. Please try again.';
  }

  static String friendlyTitle(Object error) {
    error = _unwrap(error);

    if (error is String) {
      return 'Check this information';
    }

    if (error is UnauthorizedApiException) {
      return 'Sign-in failed';
    }

    if (error is ForbiddenApiException) {
      return 'Access denied';
    }

    if (error is BadRequestApiException || error is ConflictApiException) {
      return 'Action needed';
    }

    if (error is LockedApiException) {
      return 'Please try again';
    }

    if (error is NotFoundApiException) {
      return 'Not found';
    }

    if (error is ServerApiException) {
      return 'Server unavailable';
    }

    if (error is NetworkApiException) {
      return 'Connection problem';
    }

    if (error is ApiException) {
      return 'Request failed';
    }

    return 'Request failed';
  }

  static Object _unwrap(Object error) {
    var current = error;

    while (current is DioException && current.error != null) {
      current = current.error!;
    }

    return current;
  }
}
