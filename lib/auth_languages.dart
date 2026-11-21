import 'package:flutter/material.dart';

const authLanguages = <String, String>{
  'en': 'English',
  'hi': 'हिन्दी',
  'ta': 'தமிழ்',
  'ar': 'العربية',
  'ml': 'മലയാളം',
};

// Authentication-specific translations; other user pages use user_translations.dart.
const authTranslations = <String, Map<String, String>>{
  'hi': {
    'accountBlocked':
        'आपकी ऐप पहुँच रोक दी गई है। ग्राहक सहायता से संपर्क करें।',
    'confirmationRequired':
        'पंजीकरण से पहले ऐप स्वामी को ईमेल सत्यापन चालू करना होगा।',
    'emailNotAuthorized': 'ईमेल भेजना प्रतिबंधित है। ऐप स्वामी से संपर्क करें।',
    'signupUnavailable': 'पंजीकरण उपलब्ध नहीं है। ऐप स्वामी से संपर्क करें।',
    'confirmationEmailFailed': 'सत्यापन ईमेल नहीं भेजा जा सका। बाद में प्रयास करें या सहायता से संपर्क करें।',
    'accountCreationFailed':
        'खाता नहीं बन सका। बाद में प्रयास करें या सहायता से संपर्क करें।',
    'securityCheck': 'सुरक्षा जाँच',
    'securityFailed': 'सुरक्षा जाँच लोड नहीं हुई। बंद करके पुनः प्रयास करें।',
    'cancel': 'रद्द करें',
    'official': 'आधिकारिक',
    'openFailed': 'लिंक नहीं खुल सका।',

    'authWelcome': 'वापस स्वागत है',
    'authWelcomeDesc': 'आगे बढ़ने के लिए साइन इन करें।',
    'register': 'खाता बनाएँ',
    'authSignupDesc': 'आज अपने समुदाय से जुड़ें।',
    'authName': 'नाम · वैकल्पिक',
    'authNameHint': 'आपका नाम',
    'email': 'ईमेल',
    'password': 'पासवर्ड',
    'authPasswordHint': 'अपना पासवर्ड दर्ज करें',
    'authNewPasswordHint': 'कम से कम 12 अक्षर',
    'weakPassword': 'कम से कम 12 अक्षर (अधिकतम 72 UTF-8 बाइट), बड़े और छोटे अंग्रेज़ी अक्षर, एक अंक और एक चिह्न डालें।',
    'passwordRequirements': 'कम से कम 12 अक्षर (अधिकतम 72 UTF-8 बाइट), बड़े और छोटे अंग्रेज़ी अक्षर, एक अंक और एक चिह्न डालें।',
    'login': 'साइन इन करें',
    'forgot': 'पासवर्ड भूल गए?',
    'noAccount': 'नए हैं? खाता बनाएँ',
    'haveAccount': 'पहले से खाता है? साइन इन करें',
    'authSignupHelp':
        '6 अंकों के कोड से ईमेल सत्यापित करें, फिर पासवर्ड से साइन इन करें।',
    'showPassword': 'पासवर्ड दिखाएँ',
    'hidePassword': 'पासवर्ड छिपाएँ',
    'otpTitle': 'अपना ईमेल सत्यापित करें',
    'otpHint': '6 अंकों का कोड भेजा गया:',
    'otp': '6 अंकों का कोड',
    'verifyOtp': 'ईमेल सत्यापित करें',
    'resendOtp': 'कोड फिर भेजें',
    'receivedOtp': 'कोड मिल गया? ईमेल सत्यापित करें',
    'changeEmail': 'ईमेल बदलें / साइन इन पर लौटें',
    'invalidOtp': 'सही 6 अंकों का कोड दर्ज करें।',
    'expiredOtp': 'कोड गलत है या समाप्त हो गया है। नया कोड माँगें।',
    'signupComplete': 'ईमेल सत्यापित हुआ। पासवर्ड से साइन इन करें।',
    'enterEmail': 'पहले सही ईमेल दर्ज करें।',
    'required': 'यह जानकारी आवश्यक है।',
    'resetSent': 'पासवर्ड रीसेट ईमेल भेजा गया।',
    'invalidLogin': 'ईमेल या पासवर्ड गलत है।',
    'emailNotConfirmed': 'साइन इन से पहले ईमेल सत्यापित करें।',
    'emailInUse': 'यह ईमेल पहले से पंजीकृत है।',
    'tooManyRequests': 'बहुत अधिक प्रयास हुए। कुछ देर बाद पुनः प्रयास करें।',
    'error': 'कुछ गलत हुआ। फिर प्रयास करें।',
    'connectionError': 'इंटरनेट कनेक्शन जाँचें और फिर प्रयास करें।',
    'serviceUnavailable': 'सेवा अभी उपलब्ध नहीं है। बाद में प्रयास करें।',
  },
  'ta': {
    'accountBlocked': 'உங்கள் அணுகல் தடுக்கப்பட்டுள்ளது. வாடிக்கையாளர் ஆதரவைத் தொடர்புகொள்ளவும்.',
    'confirmationRequired': 'பதிவு செய்வதற்கு முன் மின்னஞ்சல் உறுதிப்படுத்தலை ஆப் உரிமையாளர் இயக்க வேண்டும்.',
    'emailNotAuthorized': 'மின்னஞ்சல் அனுப்புவது தடைசெய்யப்பட்டுள்ளது. ஆப் உரிமையாளரைத் தொடர்புகொள்ளவும்.',
    'signupUnavailable':
        'பதிவு செய்ய முடியவில்லை. ஆப் உரிமையாளரைத் தொடர்புகொள்ளவும்.',
    'confirmationEmailFailed': 'உறுதிப்படுத்தல் மின்னஞ்சலை அனுப்ப முடியவில்லை. பின்னர் முயற்சிக்கவும் அல்லது உதவியை அணுகவும்.',
    'accountCreationFailed': 'கணக்கை உருவாக்க முடியவில்லை. பின்னர் முயற்சிக்கவும் அல்லது உதவியை அணுகவும்.',
    'securityCheck': 'பாதுகாப்பு சோதனை',
    'securityFailed':
        'பாதுகாப்பு சோதனை ஏற்றப்படவில்லை. மூடிவிட்டு மீண்டும் முயற்சிக்கவும்.',
    'cancel': 'ரத்துசெய்',
    'official': 'அதிகாரப்பூர்வம்',
    'openFailed': 'இணைப்பைத் திறக்க முடியவில்லை.',

    'authWelcome': 'மீண்டும் வரவேற்கிறோம்',
    'authWelcomeDesc': 'தொடர உள்நுழையவும்.',
    'register': 'கணக்கை உருவாக்கு',
    'authSignupDesc': 'இன்றே உங்கள் சமூகத்தில் இணையுங்கள்.',
    'authName': 'பெயர் · விருப்பமானது',
    'authNameHint': 'உங்கள் பெயர்',
    'email': 'மின்னஞ்சல்',
    'password': 'கடவுச்சொல்',
    'authPasswordHint': 'கடவுச்சொல்லை உள்ளிடவும்',
    'authNewPasswordHint': 'குறைந்தது 12 எழுத்துகள்',
    'weakPassword': 'குறைந்தது 12 எழுத்துகள் (அதிகபட்சம் 72 UTF-8 பைட்டுகள்), பெரிய மற்றும் சிறிய ஆங்கில எழுத்துகள், ஒரு எண் மற்றும் ஒரு குறியீடு சேர்க்கவும்.',
    'passwordRequirements': 'குறைந்தது 12 எழுத்துகள் (அதிகபட்சம் 72 UTF-8 பைட்டுகள்), பெரிய மற்றும் சிறிய ஆங்கில எழுத்துகள், ஒரு எண் மற்றும் ஒரு குறியீடு சேர்க்கவும்.',
    'login': 'உள்நுழை',
    'forgot': 'கடவுச்சொல் மறந்துவிட்டதா?',
    'noAccount': 'புதியவரா? கணக்கை உருவாக்கு',
    'haveAccount': 'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழை',
    'authSignupHelp': '6 இலக்கக் குறியீட்டால் மின்னஞ்சலை உறுதிசெய்து கடவுச்சொல்லால் உள்நுழையவும்.',
    'showPassword': 'கடவுச்சொல்லைக் காட்டு',
    'hidePassword': 'கடவுச்சொல்லை மறை',
    'otpTitle': 'மின்னஞ்சலை உறுதிசெய்க',
    'otpHint': '6 இலக்கக் குறியீடு அனுப்பப்பட்டது:',
    'otp': '6 இலக்கக் குறியீடு',
    'verifyOtp': 'மின்னஞ்சலை உறுதிசெய்',
    'resendOtp': 'குறியீட்டை மீண்டும் அனுப்பு',
    'receivedOtp': 'குறியீடு கிடைத்ததா? மின்னஞ்சலை உறுதிசெய்',
    'changeEmail': 'மின்னஞ்சலை மாற்று / உள்நுழைவுக்குத் திரும்பு',
    'invalidOtp': 'சரியான 6 இலக்கக் குறியீட்டை உள்ளிடவும்.',
    'expiredOtp':
        'குறியீடு தவறானது அல்லது காலாவதியானது. புதிய குறியீட்டைக் கோரவும்.',
    'signupComplete':
        'மின்னஞ்சல் உறுதிசெய்யப்பட்டது. கடவுச்சொல்லால் உள்நுழையவும்.',
    'enterEmail': 'முதலில் சரியான மின்னஞ்சலை உள்ளிடவும்.',
    'required': 'இந்த விவரம் தேவை.',
    'resetSent': 'கடவுச்சொல் மீட்டமைப்பு மின்னஞ்சல் அனுப்பப்பட்டது.',
    'invalidLogin': 'மின்னஞ்சல் அல்லது கடவுச்சொல் தவறானது.',
    'emailNotConfirmed': 'உள்நுழைவதற்கு முன் மின்னஞ்சலை உறுதிசெய்யவும்.',
    'emailInUse': 'இந்த மின்னஞ்சல் ஏற்கனவே பதிவு செய்யப்பட்டுள்ளது.',
    'tooManyRequests': 'அதிக முயற்சிகள். சிறிது நேரம் கழித்து முயற்சிக்கவும்.',
    'error': 'ஏதோ தவறு ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.',
    'connectionError': 'இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
    'serviceUnavailable': 'சேவை தற்போது கிடைக்கவில்லை. பின்னர் முயற்சிக்கவும்.',
  },
  'ar': {
    'accountBlocked': 'تم حظر وصولك إلى التطبيق. تواصل مع دعم العملاء.',
    'confirmationRequired':
        'يجب أن يفعّل مالك التطبيق تأكيد البريد قبل التسجيل.',
    'emailNotAuthorized': 'إرسال البريد مقيد. تواصل مع مالك التطبيق.',
    'signupUnavailable': 'التسجيل غير متاح. تواصل مع مالك التطبيق.',
    'confirmationEmailFailed':
        'تعذر إرسال رسالة التحقق. حاول لاحقاً أو تواصل مع الدعم.',
    'accountCreationFailed':
        'تعذر إنشاء الحساب. حاول لاحقاً أو تواصل مع الدعم.',
    'securityCheck': 'فحص الأمان',
    'securityFailed': 'تعذر تحميل فحص الأمان. أغلقه وحاول مرة أخرى.',
    'cancel': 'إلغاء',
    'official': 'الرسمي',
    'openFailed': 'تعذر فتح الرابط.',

    'authWelcome': 'مرحباً بعودتك',
    'authWelcomeDesc': 'سجّل الدخول للمتابعة.',
    'register': 'إنشاء حساب',
    'authSignupDesc': 'انضم إلى مجتمعك اليوم.',
    'authName': 'الاسم · اختياري',
    'authNameHint': 'اسمك',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'authPasswordHint': 'أدخل كلمة المرور',
    'authNewPasswordHint': '12 حرفاً على الأقل',
    'weakPassword': 'استخدم 12 حرفاً على الأقل (بحد أقصى 72 بايت UTF-8)، تشمل أحرفاً إنجليزية كبيرة وصغيرة ورقماً ورمزاً.',
    'passwordRequirements': 'استخدم 12 حرفاً على الأقل (بحد أقصى 72 بايت UTF-8)، تشمل أحرفاً إنجليزية كبيرة وصغيرة ورقماً ورمزاً.',
    'login': 'تسجيل الدخول',
    'forgot': 'نسيت كلمة المرور؟',
    'noAccount': 'مستخدم جديد؟ أنشئ حساباً',
    'haveAccount': 'لديك حساب؟ سجّل الدخول',
    'authSignupHelp':
        'تحقق من بريدك برمز من 6 أرقام، ثم سجّل الدخول بكلمة المرور.',
    'showPassword': 'إظهار كلمة المرور',
    'hidePassword': 'إخفاء كلمة المرور',
    'otpTitle': 'تحقق من بريدك الإلكتروني',
    'otpHint': 'أُرسل رمز من 6 أرقام إلى:',
    'otp': 'رمز من 6 أرقام',
    'verifyOtp': 'تحقق من البريد',
    'resendOtp': 'إعادة إرسال الرمز',
    'receivedOtp': 'هل وصل الرمز؟ تحقق من البريد',
    'changeEmail': 'تغيير البريد / العودة لتسجيل الدخول',
    'invalidOtp': 'أدخل رمزاً صحيحاً من 6 أرقام.',
    'expiredOtp': 'الرمز غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.',
    'signupComplete': 'تم التحقق من البريد. سجّل الدخول بكلمة المرور.',
    'enterEmail': 'أدخل بريداً إلكترونياً صحيحاً أولاً.',
    'required': 'هذا الحقل مطلوب.',
    'resetSent': 'تم إرسال رسالة إعادة تعيين كلمة المرور.',
    'invalidLogin': 'البريد أو كلمة المرور غير صحيحين.',
    'emailNotConfirmed': 'تحقق من بريدك قبل تسجيل الدخول.',
    'emailInUse': 'هذا البريد مسجل بالفعل.',
    'tooManyRequests': 'محاولات كثيرة. انتظر وحاول مرة أخرى.',
    'error': 'حدث خطأ. حاول مرة أخرى.',
    'connectionError': 'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
    'serviceUnavailable': 'الخدمة غير متاحة حالياً. حاول لاحقاً.',
  },
};

class AuthLanguagePicker extends StatelessWidget {
  const AuthLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Language',
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (context) => [
      for (final entry in authLanguages.entries)
        PopupMenuItem(
          value: entry.key,
          child: Row(
            children: [
              Icon(
                entry.key == value ? Icons.check_circle : Icons.language,
                size: 19,
                color: const Color(0xff5a36ad),
              ),
              const SizedBox(width: 12),
              Text(entry.value),
            ],
          ),
        ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xfff0e9ff),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffd8c8f1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 18, color: Color(0xff5a36ad)),
          const SizedBox(width: 6),
          Text(
            authLanguages[value] ?? 'English',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xff4d16d5),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    ),
  );
}
