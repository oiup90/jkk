import 'package:flutter/material.dart';

import 'user_localization.dart';

// Flutter's debug error widget can include exception details in the UI.
Widget safeErrorWidget(FlutterErrorDetails _) => Builder(
  builder: (context) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Center(
        child: Text(
          userText(
            context,
            'Something went wrong. Please try again.',
            'പ്രശ്നം സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കുക.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff333333), fontSize: 14),
        ),
      ),
    );
  },
);
