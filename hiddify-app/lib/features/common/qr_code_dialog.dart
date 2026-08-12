import 'package:flutter/material.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeDialog extends StatelessWidget {
  const QrCodeDialog(this.data, {super.key, this.message, this.width = 268, this.backgroundColor = Colors.white});

  final String data;
  final String? message;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return TechDialog(
      title: message,
      icon: Icons.qr_code_2_rounded,
      width: width + 48,
      scrollable: false,
      showClose: true,
      content: Center(
        child: SizedBox(
          width: width,
          child: QrImageView(data: data, backgroundColor: backgroundColor),
        ),
      ),
      actions: [
        TechDialogActions.ok(context, onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}
