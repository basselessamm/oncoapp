import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/evidence_widgets.dart';

/// About page: scope of the app, where its data comes from, and credits.
///
/// The data-provenance and limitations sections are the substance here. A
/// research tool has to state what its numbers are and are not, and this
/// information previously existed nowhere in the app.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const String _dgidbUrl = 'https://www.dgidb.org';
  static const String _openTargetsUrl = 'https://www.opentargets.org';

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'عن التطبيق والمصادر' : 'About'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIdentity(context, isAr),
                  const SizedBox(height: 28),
                  const ResearchUseBanner(),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'دليل الأطباء والباحثين: ماذا تقدم المنصة؟' : 'Clinical & Research Overview',
                    icon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDoctorGuide(context, isAr),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'مصادر البيانات وقواعد المعرفة' : 'Where the data comes from',
                    icon: Icons.storage_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDataSources(context, isAr),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'حدود ونطاق عمل التطبيق' : 'What this app does not do',
                    icon: Icons.report_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildLimitations(isAr),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'الاعتمادات وفريق العمل' : 'Credits',
                    icon: Icons.people_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildCredits(context, isAr),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentity(BuildContext context, bool isAr) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/icon.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isAr ? 'أونكو-ريبوربوز' : 'OncoRepurpose',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAr
              ? 'مستعرض التفاعلات الجزيئية بين الجينات والأدوية لأبحاث الأورام'
              : 'A gene-drug interaction browser for cancer research',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorGuide(BuildContext context, bool isAr) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillars = [
      (
        Icons.biotech_outlined,
        isAr ? 'إعادة توظيف الأدوية في الأورام (Oncology Drug Repurposing)' : 'Oncology Drug Repurposing',
        isAr
            ? 'تطوير دواء جديد للسرطان يستغرق 10-15 سنة ويكلف مليارات. تتيح المنصة للطبيب والباحث اكتشاف إمكانية استخدام أدوية معتمدة حالياً لأمراض أخرى لعلاج الأورام المستعصية استناداً لبصمتها الوراثية.'
            : 'Developing a new oncology drug takes 10-15 years. OncoRepurpose enables oncologists and researchers to discover repurposing opportunities for approved drugs based on tumor transcriptomic signatures.',
      ),
      (
        Icons.swap_vert,
        isAr ? 'فحص التوافق الاتجاهي (Directional Concordance)' : 'Directional Concordance Check',
        isAr
            ? 'لا نكتفي بوجود تفاعل بين الدواء والجين؛ بل يتحقق التطبيق من اتجاه التأثير: هل الدواء يثبط (Inhibits) الجين المفرط في الورم، أم يعززه (Activates)؟ مما يمنع اقتراح أدوية قد تغذي الورم.'
            : 'The engine tests whether a drug\'s pharmacological mechanism opposes tumor dysregulation (downregulating overexpressed targets) rather than inadvertently reinforcing disease.',
      ),
      (
        Icons.hub_outlined,
        isAr ? 'ربط الهدف بالمرض وقابلية الاستهداف (Open Targets 26.06)' : 'Target-Disease Evidence (Open Targets)',
        isAr
            ? 'يربط التطبيق الجينات المستهدفة بقاعدة Open Targets للتحقق من أن الجين محرك للمرض (Driver) وليس مجرد طفرة ثانوية عابرة (Passenger)، مع توضيح مدى قابلية الهدف للاستهداف الدوائي (Tractability).'
            : 'Integrates Open Targets genetic association scores, somatic evidence, and druggability tractability tiers to separate driver targets from passenger bystanders.',
      ),
      (
        Icons.graphic_eq,
        isAr ? 'المعاكسة النسخية الخلوية (NIH LINCS L1000)' : 'In Vitro Transcriptomic Reversal (LINCS)',
        isAr
            ? 'يحسب التطبيق درجة الاتصال النسخي (Connectivity Score) بمكتبة NIH LINCS، للتأكد مخبرياً من أن تعريض الخلايا السرطانية للدواء يعاكس البصمة الجينية الكلية للورم نحو النمط السليم.'
            : 'Calculates transcriptomic connectivity scores against 16,000+ perturbational signatures to confirm that drug exposure reverses the overall tumor expression profile.',
      ),
      (
        Icons.lock_outline,
        isAr ? 'خصوصية كاملة ومختبر لتحليل بيانات المرضى' : 'Offline Privacy & Patient Lab',
        isAr
            ? 'يحتوي التطبيق على مختبر مدمج (Lab Screen) لرفع ملفات RNA-seq أو Microarray الخاصة بمرضاك مع حساب تصحيح FDR ورسم Volcano Plots محلياً دون إرسال أي بيانات للمخدمات الخارجية.'
            : 'Includes a local lab screen to analyze custom patient expression files with Benjamini-Hochberg FDR correction and Volcano plots running completely on-device for total patient privacy.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital_outlined,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'رسالة المنصة للأطباء والباحثين' : 'Clinical Significance & Features',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAr
                ? 'محرك استخباراتي حوسبي يربط بصمات الأورام الجزيئية بقواعد البيانات الدوائية العالمية المعتمدة لتقديم فرضيات علاجية مدعومة بالأدلة التجريبية وبشفافية كاملة (Zero Hallucination).'
                : 'A computational intelligence engine connecting tumor molecular signatures to verified global drug databases to formulate empirical, reproducible therapeutic hypotheses.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          for (final (icon, title, desc) in pillars)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataSources(BuildContext context, bool isAr) {
    return Column(
      children: [
        DetailCard(
          icon: Icons.medication_outlined,
          title: isAr ? 'تفاعلات الجينات والأدوية (DGIdb)' : 'Gene-drug interactions',
          footnote: isAr
              ? 'تجمع DGIdb قواعد ChEMBL و DTC و Guide to Pharmacology و TTD و NCI و PharmGKB وغيرها. تقيس درجات التفاعل مدى التوثيق وليس الفعالية السريرية.'
              : 'DGIdb aggregates ChEMBL, DTC, Guide to Pharmacology, TTD, NCI, PharmGKB and others. Interaction scores measure how well documented a claim is, not how effective a drug is.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'قاعدة بيانات DGIdb\n98,239 سجلاً تغطي 5,012 جين و 18,854 دواء.'
                    : 'DGIdb (Drug Gene Interaction Database)\n98,239 records covering 5,012 genes and 18,854 drugs.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _open(context, _dgidbUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('dgidb.org'),
              ),
            ],
          ),
        ),
        DetailCard(
          icon: Icons.biotech_outlined,
          title: isAr ? 'بصمات التعبير الجيني المرجعية' : 'Reference gene signatures',
          footnote: isAr
              ? 'البصمات المدمجة هي قوائم جينات منشورة في دراسات TCGA لأورام الثدي. صُمم التطبيق أيضاً لاستقبال ملفات دراساتك الخاصة.'
              : 'Bundled signatures are fixed top-N gene lists published with each study. They are provided as examples; your own study files are the intended input.',
          child: Text(
            isAr
                ? 'بيانات أطلس سرطان الثدي الارتشاحي (TCGA PanCancer) وثلاث مقارنات لأنماط سرطان الثدي ثلاثي السلبية (TNBC).'
                : 'TCGA Breast Invasive Carcinoma (PanCancer Atlas) and three triple-negative breast cancer subtype comparisons.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        DetailCard(
          icon: Icons.public,
          title: isAr ? 'أدلة ارتباط الهدف بالمرض وقابلية الاستهداف' : 'Target-disease evidence & tractability',
          footnote: isAr
              ? 'منصة Open Targets (إصدار البيانات 26.06، واجهة برمجة 26.6.3). متاحة بترخيص CC0 العام.'
              : 'Open Targets Platform (Data version 26.06, API 26.6.3). Freely accessible under CC0 (Creative Commons Public Domain Dedication).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'منصة Open Targets Platform\nتجمع الارتباطات الوراثية، الطفرات الجسدية، الأسبقية السريرية، والمسارات الحيوية وقابلية الاستهداف عبر أكثر من 20 قاعدة بيانات عامة.'
                    : 'Open Targets Platform\nAggregates genetic associations, somatic mutations, clinical precedence, affected pathways, and drug tractability across 20+ public databases.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _open(context, _openTargetsUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('opentargets.org'),
              ),
            ],
          ),
        ),
        DetailCard(
          icon: Icons.graphic_eq_outlined,
          title: isAr ? 'بصمات الاضطراب النسخي الخلوي (LINCS)' : 'Transcriptomic perturbation signatures',
          footnote: isAr
              ? 'اتحاد NIH LINCS ومختبر معيان (L1000FWD). تسجل L1000 تغيرات تعبير الجينات الخلوية عبر آلاف المركبات الدوائية.'
              : 'NIH LINCS Consortium and Ma\'ayan Laboratory (L1000FWD). L1000 profiles cellular gene expression changes across thousands of drug perturbations.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'مبادرة NIH LINCS L1000 / L1000FWD\nأكثر من 16,000 بصمة نسخية ناجمة عن أدوية لحساب درجات المعاكسة الاتصالية (Connectivity Scores).'
                    : 'NIH LINCS L1000 / L1000FWD\nOver 16,000 drug-induced transcriptomic signatures used to compute signature reversal connectivity scores.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    _open(context, 'https://maayanlab.cloud/l1000fwd/'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('maayanlab.cloud/l1000fwd'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Explicit statement of the app's limits.
  Widget _buildLimitations(bool isAr) {
    final limitations = [
      (
        Icons.psychology_outlined,
        isAr ? 'لا وجود لذكاء اصطناعي تخميني غير موثق' : 'No machine learning',
        isAr
            ? 'النتائج مستخلصة بدقة من استعلامات SQL عبر قواعد بيانات تجريبية موثقة، وفحص توافق اتجاهي واضح. لا توجد تنبؤات سوداء غير مبررة.'
            : 'Results come from SQL queries over a fixed database, plus a directional consistency check. There is no model, no training, and no prediction.',
      ),
      (
        Icons.swap_vert,
        isAr ? 'فحص الاتجاه فحص توافق وليس تنبؤاً سريرياً حتمياً' : 'Direction is a check, not a prediction',
        isAr
            ? 'يقارن التطبيق اتجاه عمل الدواء باتجاه تغير التعبير الجيني في الورم. مستويات mRNA لا تعكس حتماً نشاط البروتين، والجين قد يكون ثانوياً (passenger) لا مسبباً.'
            : 'The app compares a drug\'s reported direction of action against the direction each gene moved in the study. But mRNA level is not protein activity, and a dysregulated gene may be a passenger rather than a driver of the tumour.',
      ),
      (
        Icons.public,
        isAr ? 'درجات الأدلة تعبر عن عمق التوثيق لا اليقين العلاجي' : 'Evidence measures research depth, not therapeutic certainty',
        isAr
            ? 'درجات Open Targets تلخص المنشورات العلمية والربط الوراثي والتجارب السريرية. الجينات الأكثر دراسة تحصل على درجات أعلى لتوافر أبحاث أكثر عنها.'
            : 'Open Targets scores synthesize published literature, genetic links, and trial records. Well-studied genes receive higher scores simply because more studies exist.',
      ),
      (
        Icons.graphic_eq,
        isAr ? 'نماذج المعاكسة الخلوية في المختبر (LINCS L1000)' : 'Cellular perturbation models in vitro',
        isAr
            ? 'تختبر منصة LINCS L1000 تعبير الجينات في خطوط خلوية مستزرعة بجرعات وأزمنة محددة، وهي مؤشر للتطابق الجزيئي ولا تضمن الحركية الدوائية الحيوية.'
            : 'LINCS L1000 assays measure gene expression in specific cultured cancer cell lines. In vitro signature reversal indicates molecular concordance, but does not guarantee in vivo pharmacokinetic delivery.',
      ),
      (
        Icons.help_outline,
        isAr ? 'معظم الآليات غير مسجلة في المصادر الأصلية' : 'Most mechanisms are unreported',
        isAr
            ? '64% من السجلات في قاعدة البيانات المجمعة لا تذكر نوع التفاعل، لذلك تُصنف كغير محددة بدلاً من افتراض اتجاه إيجابي وهمي.'
            : '64% of records in the bundled database name no interaction type, so no direction can be inferred for them. Those candidates are labelled undetermined rather than assumed favourable.',
      ),
    ];

    return Column(
      children: [
        for (final (icon, title, body) in limitations)
          DetailCard(
            icon: icon,
            title: title,
            child: Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
          ),
      ],
    );
  }

  Widget _buildCredits(BuildContext context, bool isAr) {
    final theme = Theme.of(context);
    const founders = [
      'Dr. Salma Kamal Ahmed',
      'Dr. Laila Ahmed Mohamed',
      'Dr. Rawan Ashraf Elkhelaly',
      'Dr. Yasmin Reda Mohamed',
      'Dr. Naira Mohamed Ismail',
      'Dr. Mariam Nabil Abdalla',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'فكرة المشروع والبحث العلمي' : 'Project idea and research',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (final name in founders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 28),
          Text(
            isAr ? 'التطوير البرمجي والهندسي' : 'Development',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr ? 'م. باسل عصام' : 'Eng. Bassel Essam',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}
