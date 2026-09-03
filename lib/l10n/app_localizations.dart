import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Comprehensive bilingual (Arabic and English) localization engine for OncoRepurpose.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // App Identity & Header
  String get appTitle => isArabic ? 'أونكو ريبيربوس' : 'OncoRepurpose';
  String get appSubtitle => isArabic
      ? 'منصة إعادة توظيف أدوية الأورام عبر البصمات الجينومية'
      : 'Gene-Drug Interactions for Cancer Transcriptomics';
  String get researchOnlyBadge =>
      isArabic ? 'لأغراض البحث فقط' : 'Research use only';
  String get researchOnlyNotice => isArabic
      ? 'أداة بحثية لدراسة التفاعلات الجزيئية للأدوية. لا تقدم استشارات طبية أو توصيات علاجية سريرية.'
      : 'A research tool for browsing recorded gene-drug interactions. Not clinical advice or efficacy prediction.';

  // Tabs / Navigation Deck
  String get tabSignatures => isArabic ? 'بصمات الأورام' : 'Signatures';
  String get tabCustomGenes => isArabic ? 'جينات مخصصة' : 'Custom Genes';
  String get tabDrugSearch => isArabic ? 'بحث عن دواء' : 'Drug Search';
  String get tabMyStudies => isArabic ? 'دراساتي المخبرية' : 'My Studies';

  // Home Screen & Inputs
  String get selectSignature =>
      isArabic ? 'اختر بصمة الورم الجينومية' : 'Select a reference signature';
  String get manualGeneTitle =>
      isArabic ? 'أو أدخل قائمة جينات مخصصة' : 'Or enter a custom gene list';
  String get geneInputHint =>
      isArabic ? 'رموز الجينات مفصولة بفواصل (مثال: TP53, BRCA1)' : 'Comma-separated gene symbols (e.g. TP53, BRCA1)';
  String get searchDrugHint =>
      isArabic ? 'ابحث باسم الدواء (مثال: Tamoxifen)...' : 'Search drug name (e.g. Tamoxifen)...';
  String get clearGeneInput => isArabic ? 'مسح الجينات' : 'Clear gene list';
  String get viewSignatureGenes =>
      isArabic ? 'عرض جينات البصمة' : 'View signature genes';
  String get runLookup =>
      isArabic ? 'البحث عن تفاعلات الأدوية' : 'Run interaction lookup';
  String get searching => isArabic ? 'جاري البحث...' : 'Searching...';
  String get uploadStudy =>
      isArabic ? 'رفع دراسة تعبير جيني' : 'Upload study file';
  String get uploadStudySubtitle => isArabic
      ? 'تحليل ملف CSV/TSV لبيانات RNA-seq وحساب إحصاء Benjamini-Hochberg'
      : 'Parse differential expression tables (CSV/TSV) with FDR correction';

  // Candidate Results Screen
  String get resultsTitle => isArabic ? 'المرشحات الدوائية' : 'Candidate Drugs';
  String get candidatesFound => isArabic ? 'دواء مرشح' : 'candidates';
  String get activeDiseaseContext =>
      isArabic ? 'السياق المرضي:' : 'Disease context:';
  String get changeDisease => isArabic ? 'تغيير المرض' : 'Change';
  String get emptyResultsTitle =>
      isArabic ? 'لا توجد أدوية متفاعلة مباشرة' : 'No interacting drugs found';
  String get emptyResultsDetail => isArabic
      ? 'معظم جينات التعبير التفريقي الشديد تقع خارج الأهداف الدوائية الموثقة في قواعد البيانات العامة.'
      : 'Differential-expression outliers and documented druggable targets are largely disjoint sets.';
  String get failedLookupTitle =>
      isArabic ? 'تعذر استرجاع التفاعلات' : 'Could not query interactions';
  String get filterButton => isArabic ? 'تصفية وترتيب' : 'Filters & Sort';
  String get viewProfile => isArabic ? 'عرض الملف الدوائي' : 'View Profile';

  // Directional Verdicts
  String get directionalVerdict =>
      isArabic ? 'التوافق الاتجاهي' : 'Directional consistency';
  String get opposes => isArabic ? 'يعاكس الورم (مرشح)' : 'Opposes signature';
  String get reinforces => isArabic ? 'يعزز الورم (تحذير)' : 'Reinforces signature';
  String get neutral => isArabic ? 'محايد / غير محدد' : 'Neutral / mixed';
  String get mechanismUnknown =>
      isArabic ? 'الآلية غير مسجلة' : 'Mechanism not reported';

  // Evidence Tiers (Open Targets & LINCS)
  String get openTargetsEvidence =>
      isArabic ? 'أدلة Open Targets' : 'Open Targets Evidence';
  String get lincsConnectivity =>
      isArabic ? 'معاكسة LINCS L1000' : 'LINCS L1000 Reversal';
  String get strongReversal => isArabic ? 'معاكسة قوية' : 'Strong Reversal';
  String get moderateReversal => isArabic ? 'معاكسة متوسطة' : 'Moderate Reversal';
  String get nominalReversal => isArabic ? 'معاكسة اسمية' : 'Nominal Reversal';
  String get mimicWarning => isArabic ? 'محاكاة للورم (خطر)' : 'Mimic (Warning)';
  String get notTested => isArabic ? 'غير مجرب' : 'Untested';

  // Drug Approval Status
  String get approvedFda => isArabic ? 'معتمد FDA' : 'FDA-approved';
  String get notApproved => isArabic ? 'غير معتمد / بحثي' : 'Not FDA-approved';
  String get targetsCount => isArabic ? 'أهداف' : 'targets';
  String get interactionsCount => isArabic ? 'تفاعلات' : 'interactions';

  // Drug Profile Screen
  String get drugDetailsTitle => isArabic ? 'الملف الدوائي' : 'Drug Profile';
  String get primaryTargets => isArabic ? 'الأهداف الجزيئية' : 'Primary Targets';
  String get externalEvidenceTitle =>
      isArabic ? 'الأدلة الخارجية' : 'External Biological Evidence';
  String get databaseSources =>
      isArabic ? 'قواعد البيانات الموثقة' : 'Database Sources';
  String get clinicalAdvisory => isArabic
      ? 'تنبيه: التوافق الاتجاهي واختبارات الخلايا المخبرية لا تغني عن التجارب السريرية.'
      : 'Caveat: Cell-line transcriptomic reversal does not establish in vivo efficacy.';

  // Settings Screen
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get appearance => isArabic ? 'المظهر والثيم' : 'Appearance';
  String get themeSystem => isArabic ? 'تلقائي' : 'System';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن (OLED)' : 'Dark (OLED)';
  String get languageSection => isArabic ? 'لغة التطبيق' : 'Language';
  String get langArabic => isArabic ? 'العربية' : 'Arabic';
  String get langEnglish => isArabic ? 'English' : 'English';
  String get networkConsentTitle =>
      isArabic ? 'أذونات الاتصال الخارجي' : 'External Lookups';
  String get networkConsentSubtitle => isArabic
      ? 'استرجاع أدلة Open Targets و LINCS L1000. مغلق افتراضياً لخصوصية أبحاثك.'
      : 'Open Targets & LINCS L1000 lookups. Off by default to protect unpublished gene lists.';
  String get cacheTitle => isArabic ? 'الذاكرة المؤقتة' : 'Response Cache';
  String get clearCache => isArabic ? 'مسح الذاكرة' : 'Clear Cache';
  String get creditsTitle =>
      isArabic ? 'المصادر والاعتمادات' : 'Credits & Provenance';

  // Dialogs & Actions
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get discard => isArabic ? 'تجاهل' : 'Discard';
  String get offlineStaleNotice =>
      isArabic ? 'نسخة محفوظة دون اتصال' : 'Offline cached copy';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
