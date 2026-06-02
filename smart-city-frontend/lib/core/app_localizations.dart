import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_category.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isAr => locale.languageCode == 'ar';

  // ── Language toggle ──────────────────────────────────────────────────────────
  String get languageLabel => isAr ? 'EN' : 'AR';

  // ── Map / Navigation ─────────────────────────────────────────────────────────
  String get searchPlaceholder =>
      isAr ? 'ابحث في الأردن...' : 'Search in Jordan...';
  String get goTo => isAr ? 'اذهب إلى' : 'Go To';
  String get cancelRoute => isAr ? 'إلغاء المسار' : 'Cancel Route';
  String get goToNearest =>
      isAr ? 'اذهب إلى الأقرب...' : 'Go To Nearest...';
  String get findNearestAvailable =>
      isAr ? 'العثور على أقرب موقع متاح' : 'Find nearest available location';
  String nPlaces(int n) => isAr ? '$n أماكن' : '$n places';

  // ── Category names ────────────────────────────────────────────────────────────
  String catDisplayName(AppCategory cat) =>
      isAr ? _categoryNameAr(cat.backendValue) : cat.displayName;

  String _categoryNameAr(String v) {
    const ar = <String, String>{
      'pothole': 'حفرة في الطريق',
      'brokenRoad': 'طريق مكسور',
      'treeInRoad': 'شجرة في الطريق',
      'unpavedStreet': 'شارع غير معبد',
      'manhole': 'غطاء بئر صرف',
      'lamppost': 'عمود إنارة',
      'speedBump': 'مطب سرعة',
      'other': 'أخرى',
      'RESTAURANT': 'مطعم',
      'FUEL': 'محطة وقود',
      'PARK': 'حديقة',
      'PARKING': 'موقف سيارات',
      'SUPERMARKET': 'سوبرماركت',
      'MOSQUE': 'مسجد',
    };
    return ar[v] ?? v;
  }

  // ── Report statuses ───────────────────────────────────────────────────────────
  String get underProcessing => isAr ? 'قيد المعالجة' : 'Under Processing';
  String get resolved => isAr ? 'تم الحل' : 'Resolved';
  String get rejected => isAr ? 'مرفوض' : 'Rejected';
  String get underReview => isAr ? 'قيد المراجعة' : 'Under Review';

  String reportStatusLabel(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'RESOLVED': return resolved;
      case 'REJECTED': return rejected;
      case 'PENDING':  return underReview;
      default:         return underProcessing;
    }
  }

  // ── Reports screen ────────────────────────────────────────────────────────────
  String get myReports => isAr ? 'تقاريري' : 'My Reports';
  String get tapToSeeAnalysis =>
      isAr ? 'اضغط لرؤية تحليل الذكاء الاصطناعي والتصويتات'
           : 'Tap to see AI analysis & live votes';
  String get noReports =>
      isAr ? 'لا توجد تقارير بعد.' : 'You have no reports yet.';
  String get somethingWentWrong =>
      isAr ? 'حدث خطأ ما!' : 'Something went wrong!';
  String get tryAgain => isAr ? 'حاول مجددًا' : 'Try Again';

  // ── AI section ────────────────────────────────────────────────────────────────
  String get aiSmartAnalysis =>
      isAr ? 'تحليل الذكاء الاصطناعي' : 'AI Smart Analysis';
  String get aiInProgress =>
      isAr ? 'جاري تحليل الذكاء الاصطناعي...' : 'AI analysis is in progress…';
  String aiRunCount(int n) => isAr ? 'تم التشغيل $n×' : 'Run $n×';
  String get aiConfidenceLabel =>
      isAr ? 'ثقة الذكاء الاصطناعي' : 'AI Confidence';
  String aiHistoryLabel(int n) =>
      isAr ? 'سجل الذكاء الاصطناعي ($n تشغيل)'
           : 'AI History ($n run${n == 1 ? '' : 's'})';
  String get initialAnalysis =>
      isAr ? 'التحليل الأولي' : 'Initial analysis';
  String get reanalyzed3 =>
      isAr ? '↑ إعادة تحليل · 3 تصويتات' : '↑ Re-analyzed · 3 community votes';
  String get reanalyzed5 =>
      isAr ? '↑ إعادة تحليل · 5 تصويتات' : '↑ Re-analyzed · 5 community votes';
  String get validLabel => isAr ? '✓ صالح' : '✓ Valid';
  String get invalidLabel => isAr ? '✗ غير صالح' : '✗ Invalid';
  String get setByAdmin =>
      isAr ? 'تم التعيين بواسطة المشرف' : 'Set by Admin';
  String get setByAi =>
      isAr ? 'تم التعيين بواسطة الذكاء الاصطناعي' : 'Set by AI';
  String aiConfidenceNote(int pct) =>
      isAr ? 'ثقة الذكاء الاصطناعي: $pct%' : 'AI confidence: $pct%';
  String get noReasonProvided =>
      isAr ? 'لم يقدم الذكاء الاصطناعي سببًا.' : 'No reason provided by AI.';

  String priorityLabel(String p) {
    if (!isAr) return p;
    switch (p.toUpperCase()) {
      case 'CRITICAL': return 'حرج';
      case 'HIGH':     return 'عالٍ';
      case 'MEDIUM':   return 'متوسط';
      case 'LOW':      return 'منخفض';
      default:         return p;
    }
  }

  String priorityFull(String p) {
    final lbl = priorityLabel(p);
    return isAr ? 'الأولوية: $lbl' : 'Priority: $lbl';
  }

  // ── Votes ─────────────────────────────────────────────────────────────────────
  String get communityVotes =>
      isAr ? 'تصويتات المجتمع' : 'Community votes';
  String get cannotVoteOwn =>
      isAr ? 'لا يمكنك التصويت على تقريرك الخاص.'
           : 'You cannot vote on your own report.';
  String get stillThere => isAr ? 'لا يزال هناك' : 'Still There';
  String get fixed => isAr ? 'تم الإصلاح' : 'Fixed';
  String get isIssueStillThere =>
      isAr ? 'هل المشكلة لا تزال موجودة؟' : 'Is this issue still there?';
  String get alreadyVotedMsg =>
      isAr ? '⚠️ لقد صوّتت بالفعل. يمكنك تغيير تصويتك مرة كل 24 ساعة.'
           : '⚠️ You already voted. You can change your vote once every 24 hours.';
  String get confirmVote => isAr ? 'تأكيد التصويت' : 'Confirm Vote';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get confirm => isAr ? 'تأكيد' : 'Confirm';

  String confirmVoteStillThere(bool alreadyVoted) => alreadyVoted
      ? (isAr
          ? 'تغيير تصويتك إلى "لا يزال هناك"؟ لن تتمكن من تغييره مجددًا خلال 24 ساعة.'
          : 'Change your vote to "Still There"? You won\'t be able to change it again for 24 hours.')
      : (isAr
          ? 'تقديم تصويتك كـ "لا يزال هناك"؟ يمكنك تغييره مرة كل 24 ساعة.'
          : 'Submit your vote as "Still There"? You can change it once every 24 hours.');

  String confirmVoteFixed(bool alreadyVoted) => alreadyVoted
      ? (isAr
          ? 'تغيير تصويتك إلى "تم الإصلاح"؟ لن تتمكن من تغييره مجددًا خلال 24 ساعة.'
          : 'Change your vote to "Fixed"? You won\'t be able to change it again for 24 hours.')
      : (isAr
          ? 'تقديم تصويتك كـ "تم الإصلاح"؟ يمكنك تغييره مرة كل 24 ساعة.'
          : 'Submit your vote as "Fixed"? You can change it once every 24 hours.');

  String get successfullySubmitted =>
      isAr ? 'تم التقديم بنجاح' : 'Successfully Submitted';
  String get voteSubmittedStillThere =>
      isAr ? 'تم تقديم تصويتك بنجاح: لا يزال هناك.'
           : 'Your vote was submitted successfully as: Still there.';
  String get voteSubmittedFixed =>
      isAr ? 'تم تقديم تصويتك بنجاح: تم الإصلاح.'
           : 'Your vote was submitted successfully as: Fixed.';

  // ── Report form ───────────────────────────────────────────────────────────────
  String get selectIssueType =>
      isAr ? 'اختر نوع المشكلة' : 'Select Issue Type';
  String get otherIssue => isAr ? 'مشكلة أخرى' : 'Other Issue';
  String get cantFindIssueType =>
      isAr ? 'لم تجد نوع مشكلتك؟ صفها هنا'
           : "Can't find your issue type? Describe it here";
  String get whatsSpecificIssue =>
      isAr ? 'ما هي المشكلة تحديدًا؟ *' : "What's the specific issue? *";
  String get describeIssue =>
      isAr ? 'صف المشكلة *' : 'Describe the issue *';
  String get noteForStaff =>
      isAr ? 'ملاحظة للموظفين (اختياري) 🔒' : 'Note for staff (optional) 🔒';
  String get notReviewedByAi =>
      isAr ? 'لا يراجعها الذكاء الاصطناعي — مرئية للموظفين فقط'
           : 'Not reviewed by AI — only visible to staff/admin';
  String get photosRequired =>
      isAr ? 'الصور (مطلوبة، حتى 5 صور)' : 'Photos (required, up to 5)';
  String photosSelected(int n) =>
      isAr ? '$n/5 صور محددة' : '$n/5 photo(s) selected';
  String get reportPinnedHint =>
      isAr ? 'سيتم تثبيت التقرير في موقعك الحالي'
           : 'Report will be pinned at your current location';
  String get takePhoto => isAr ? 'التقط صورة' : 'Take Photo';
  String get maxPhotos =>
      isAr ? 'تم الوصول إلى الحد الأقصى (5 صور)' : 'Maximum 5 photos reached';
  String get submitReport => isAr ? 'إرسال التقرير' : 'Submit Report';
  String get otherNotInList =>
      isAr ? 'أخرى (غير موجودة في القائمة)' : 'Other (not in list)';
  String get pleaseSelectIssue =>
      isAr ? 'يرجى اختيار خيار المشكلة.' : 'Please select an issue option.';
  String get pleaseDescribe =>
      isAr ? 'يرجى وصف المشكلة قبل الإرسال.'
           : 'Please describe the issue before submitting.';
  String get atLeastOnePhoto =>
      isAr ? 'مطلوبة صورة واحدة على الأقل قبل الإرسال.'
           : 'At least one photo is required before submitting.';
  String get describeInDetail =>
      isAr ? 'صف المشكلة بالتفصيل...' : 'Describe the issue in detail...';
  String get extraContext =>
      isAr ? 'سياق إضافي للموظفين (الموقع، الشدة...)'
           : 'Extra context for staff (location details, severity...)';

  // ── Place details ─────────────────────────────────────────────────────────────
  String routeTo(String name) =>
      isAr ? 'الطريق إلى $name' : 'Route to $name';

  // ── Success dialog / snacks ───────────────────────────────────────────────────
  String get done => isAr ? 'تم' : 'Done';
  String get reportSubmittedTitle =>
      isAr ? 'تم إرسال التقرير!' : 'Report Submitted!';
  String reportPinnedMsg(String categoryName) =>
      isAr ? 'تم تثبيت تقرير $categoryName في موقعك الحالي.'
           : 'Your $categoryName report has been pinned at your current location.';
  String get navigationStartedTitle =>
      isAr ? 'بدء الملاحة' : 'Navigation Started';
  String routingToMsg(String name) =>
      isAr ? 'التوجيه إلى $name. اتبع الاتجاهات على الخريطة.'
           : 'Routing to $name. Follow the directions on the map.';

  // ── Snack messages ────────────────────────────────────────────────────────────
  String get gpsOff =>
      isAr ? 'نظام GPS متوقف. يرجى تفعيل خدمات الموقع.'
           : 'GPS is off. Please enable Location Services.';
  String get locationPermRequired =>
      isAr ? 'مطلوب إذن الموقع. فعّله من إعدادات التطبيق.'
           : 'Location permission is required. Enable it in App Settings.';
  String get locationPermDenied =>
      isAr ? 'تم رفض إذن الموقع. فعّله من إعدادات التطبيق.'
           : 'Location permission denied. Enable it in App Settings.';
  String get unableToGetLocation =>
      isAr ? 'تعذر الحصول على الموقع. تحقق من إعدادات GPS.'
           : 'Unable to get location. Check GPS settings.';
  String get settingsLabel => isAr ? 'الإعدادات' : 'Settings';
  String get locationUnavailable =>
      isAr ? 'الموقع غير متاح.' : 'Location unavailable.';
  String get locationUnavailableAllow =>
      isAr ? 'الموقع غير متاح. اسمح بالوصول إلى الموقع.'
           : 'Location unavailable. Allow location access.';
  String get locationUnavailableAllow2 =>
      isAr ? 'الموقع غير متاح. اسمح بالوصول إلى الموقع أولًا.'
           : 'Location unavailable. Allow location access first.';
  String noPlacesFoundCategory(String categoryName) =>
      isAr ? 'لا توجد $categoryName بالقرب.'
           : 'No $categoryName found nearby.';
  String get couldNotCalculateRoute =>
      isAr ? 'تعذر حساب المسار.' : 'Could not calculate route.';
  String get couldNotSubmitReport =>
      isAr ? 'تعذر إرسال التقرير.' : 'Could not submit report.';
  String get couldNotSubmitVote =>
      isAr ? 'تعذر تقديم التصويت.' : 'Could not submit vote.';
  String get failedToLoadMapSummary =>
      isAr ? 'فشل تحميل ملخص الخريطة.' : 'Failed to load map summary.';
  String get failedToLoadMapReports =>
      isAr ? 'فشل تحميل تقارير الخريطة.' : 'Failed to load map reports.';

  // ── Location row in report details ────────────────────────────────────────────
  String get photos => isAr ? 'الصور' : 'Photos';
  String get tapToViewOnMap =>
      isAr ? 'اضغط للعرض على الخريطة' : 'Tap to view on map';

  // ── Distance ──────────────────────────────────────────────────────────────────
  String formatDistance(double meters) {
    if (meters < 1000) {
      return isAr ? '${meters.round()} م' : '${meters.round()} m away';
    }
    final km = (meters / 1000).toStringAsFixed(1);
    return isAr ? '$km كم' : '$km km away';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'ar';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
