import 'package:flutter/material.dart';
import 'auth_ui.dart';

typedef AccountStatusAction = Future<void> Function(BuildContext context);

class AccountStatusPage extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final AccountStatusAction onPrimaryPressed;
  final String? secondaryLabel;
  final AccountStatusAction? onSecondaryPressed;

  const AccountStatusPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  State<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends State<AccountStatusPage> {
  bool _isPrimaryLoading = false;
  bool _isSecondaryLoading = false;

  @override
  Widget build(BuildContext context) {
    return AuthUi.scope(
      context,
      Scaffold(
        backgroundColor: AuthUi.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewPadding.bottom + 56,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 56, color: AuthUi.primary),
                    SizedBox(height: 16),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AuthUi.body,
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPrimaryLoading
                            ? null
                            : () => _runPrimaryAction(context),
                        child: _isPrimaryLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.primaryLabel),
                      ),
                    ),
                    if (widget.secondaryLabel != null &&
                        widget.onSecondaryPressed != null) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isSecondaryLoading
                              ? null
                              : () => _runSecondaryAction(context),
                          child: _isSecondaryLoading
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(widget.secondaryLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runPrimaryAction(BuildContext context) async {
    setState(() => _isPrimaryLoading = true);
    try {
      await widget.onPrimaryPressed(context);
    } finally {
      if (mounted) {
        setState(() => _isPrimaryLoading = false);
      }
    }
  }

  Future<void> _runSecondaryAction(BuildContext context) async {
    setState(() => _isSecondaryLoading = true);
    try {
      await widget.onSecondaryPressed!(context);
    } finally {
      if (mounted) {
        setState(() => _isSecondaryLoading = false);
      }
    }
  }
}
