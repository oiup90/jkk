import 'package:flutter/material.dart';

// Flutter's debug error widget can include exception details in the UI.
Widget safeErrorWidget(FlutterErrorDetails _) => Builder(
  builder: (context) {
    final isMalayalam =
        Localizations.maybeLocaleOf(context)?.languageCode == 'ml';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text(
          isMalayalam
              ? 'പ്രശ്നം സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കുക.'
              : 'Something went wrong. Please try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff333333), fontSize: 14),
        ),
      ),
    );
  },
);
