# ELEC LAB — Industrial Electric Simulator

تطبيق Android مبني بـFlutter لمختبر كهرباء صناعية تعليمي يعمل دون إنترنت. يتيح بناء مخطط بمكونات وأطراف حقيقية داخل نموذج البيانات، ثم حل الدائرة وقراءة التيار والجهد وسلوك الحمايات.

> **تنبيه:** المحاكاة تعليمية فقط، وليست اعتماداً لتصميم أو تنفيذ دائرة حقيقية. لا تجرب القصر أو الأعطال على معدات فعلية.

## ما هو منفذ في المصدر

- واجهة عربية RTL بمصطلحات فرنسية، وضع داكن/فاتح محفوظ محلياً، وتصميم متجاوب للهاتف والدوران.
- مشاريع محلية: إنشاء من لوحة فارغة أو قوالب، فتح، بحث، إعادة تسمية، نسخ، حذف بتأكيد، وحفظ تلقائي ذري.
- لوحة معدنية بثقوب ومثبتات و**DIN Rails وظيفية** للتركيب والـSnap، مع Fit لكامل الإطار وZoom محدود يمنع ضياع اللوحة؛ سحب الخلفية لا يحركها، والأجهزة والأسلاك تبقى قابلة للتحريك.
- **Supply Bay دائم ومحفوظ داخل المشروع:** 3~ مع L1/L2/L3/N/PE، و1~ مع L/N، وDC مع +/0V؛ لكل مصدر ON/OFF وجهد وتردد حقيقيان في نموذج الدائرة.
- تحريك/تدوير/نسخ/حذف/تحجيم، طبقات قابلة للتسمية والإخفاء والقفل، وUndo/Redo؛ المصادر الدائمة محمية من النقل والحذف والتكرار.
- توصيل Terminal-to-Terminal مع تحقق، مسارات Straight/90°/Curved، ألوان ومقاطع وأنواع وعزل، ونقاط انحناء قابلة للتحريك.
- محرك MNA مستقل بأعداد مركبة لـDC وAC RMS، Contacteur وRelais وTemporisateur ON/OFF-delay وتعشيق ذاتي، حمايات وأعطال وقياسات.
- قالبا **Démarrage direct** و**Étoile-triangle** بمحرك ستة أطراف وتوصيل قدرة حقيقي؛ تتابع المؤقت وNC والتعشيق الميكانيكي يفتح نقاط القدرة عند تعارض الملفين، مع رفض مجموعات التعشيق الناقصة.
- MCB وDisjoncteur différentier وDisjoncteur moteur وRelais thermique وFusible؛ حساب ΔI من L+N وقواعد فصل تعليمية مرتبطة بالحل.
- محرك ثلاثي وأحادي الطور، ومحول AC مثالي مقترن داخل MNA مع مقاومتي الملفات، وعداد يقيس V/I/P ويكامل الطاقة kWh.
- **68 نوعاً × 3 LOD = 204 ملفات GLB**: board خفيف، preview للمكتبة وdetailed قابل للتدوير والتكبير؛ تحميل كسول وأطراف من تعريف المحاكاة نفسه. استُعملت ملفات الحزمة المرجعية الثلاثون كلها وسُجل مصدر كل أصل في manifest.
- مكتبة داكنة متجاوبة بتحميل كسول وبطاقات وأسماء عربية/فرنسية، مع لوحة تركيب/شبكة قابلة للتبديل وأطراف تفاعلية ومسارات تتفادى الأجهزة قدر الإمكان.
- Voltmètre وAmpèremètre وCompteur وتيارات الأسلاك والرسائل التشخيصية والمساعدة المحلية والتحديات.
- مشاركة مشروع بChecksum واستيراده، نسخة احتياطية واستعادتها، وتصدير PNG وPDF فعليين.

## نطاق وقيود مهمة

هذا الإصدار **ليس محللاً عاماً لكل دوائر الكهرباء الصناعية**:

- DC وAC جيبي خطي فقط؛ لا عابرات كهرومغناطيسية ولا harmonics.
- المحرك نموذج معاوقة steady-state، وليس نموذج إقلاع/عزم/انزلاق ميكانيكي.
- المحول مثالي لـAC مع مقاومات الملفات فقط؛ لا نموذج للتشبع أو DC أو الفاقد الديناميكي.
- RCD ثنائي القطب يحسب ΔI من مجموع L+N؛ لا يحاكي منحنيات المصنعين أو كل أشكال أعطال الأرضي. VFD وPLC غير منفذين.
- منحنيات الحماية واقتراح مقطع السلك تعليمية مبسطة وليست مطابقة لمعايير أو كتالوجات مصنعين.
- meshes تجمع أصول الحزمة المرجعية مع توسعات brand-free حسب العائلة، وليست CAD photorealistic بأبعاد مصنع؛ فُكّت واختُبرت بنيوياً في CI، لكن لم تُختبر جودتها أو أداؤها على مجموعة هواتف مادية.

التفاصيل والمعادلات في [`docs/SIMULATION.md`](docs/SIMULATION.md)، وصيغة الحفظ في [`docs/PROJECT_FORMAT.md`](docs/PROJECT_FORMAT.md)، والأصول في [`docs/ASSETS_3D.md`](docs/ASSETS_3D.md)، وتحسينات المكتبة واللوحة في [`docs/UI_WORKSPACE.md`](docs/UI_WORKSPACE.md).

## المكونات المدعومة حالياً

Alimentation DC/monophasée/triphasée؛ MCB 2P/3P/4P وMCCB وRCCB/RCBO وDisjoncteur moteur وFusible وSectionneur؛ Contacteur 3P/4P + aux وRelais thermique/auxiliaire/impulsion/phase؛ Boutons وArrêt d'urgence ومفاتيح البناء والتبديل؛ Temporisateurs ON/OFF/staircase؛ حساسات NO وPNP وحرارة/ضوء/حركة/ضغط/مستوى/تدفق؛ Voyant/LED/Bell/Buzzer؛ Moteur 3~ ثلاثي أو سداسي الأطراف و1~ وFan/Pump/Solenoid وHeater؛ Transformateurs وCT/VT؛ Borniers وBarres N/PE وDistribution وPrises وCâble؛ Voltmètre/Ampèremètre/Wattmètre/Fréquencemètre/Compteur.

## التشغيل والبناء

المتطلبات: Flutter stable، Android SDK وJava 17. الحد الأدنى للتطبيق Android 6.0 (API 23).

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter run
```

بناء APK:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

إعداد Release في هذا المشروع يوقّع APK بمفتاح **debug** ليكون قابلاً للتثبيت كنسخة تقييم CI. هذا ليس مفتاح نشر رسمي؛ يجب إعداد مفتاح upload خاص وعدم إيداعه في Git قبل النشر على متجر.

## GitHub Actions

Workflow [`.github/workflows/android.yml`](.github/workflows/android.yml) ينفذ formatter وanalyzer وكل الاختبارات، ثم Release APK ويتحقق من التوقيع والحزمة وSHA-256. عند النجاح يرفع Artifact باسم **`elec-lab-release-apk`** من صفحة Actions:

<https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions>

الإصدار المنشور الحالي هو **v0.5.0**؛ نجح في Format الصارم وAnalyze و**99/99 اختباراً** وبناء APK وفحص التوقيع والحزمة ونشر Release في [CI run 40767439321](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40767439321). نزّل [APK مباشرة](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.0/app-release.apk) أو افتح [صفحة Release](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.5.0). الحجم **72,105,383 bytes (68.77 MiB)** وSHA-256 هو `090a561c6d3b54f77b212d66524e38f658104c973d243a23d0ea62cc405aa9db`. يحتوي Release أيضاً `verification.json` و`apk-sha256.txt`. الروابط والوظائف المكتملة والقيود الصريحة موثقة في [`docs/FINAL_REPORT.md`](docs/FINAL_REPORT.md).

## بنية المصدر

```text
lib/src/models/       البيانات، الأطراف، الأسلاك، الطبقات والقوالب
lib/src/simulation/   MNA والحالات والحمايات والقياسات
lib/src/state/        المحرر وUndo/Redo والحفظ التلقائي والإعدادات
lib/src/storage/      JSON المحلي والاستيراد والنسخ الاحتياطي
lib/src/three_d/      meshes والإسقاط والتفاعل 3D
lib/src/export/       رسم المخطط وPNG/PDF
lib/src/ui/           الشاشات واللوحة والمكتبة والنوافذ
test/                 اختبارات النماذج والمحرك والتخزين والتصدير والواجهات
```

## المراجع

المواصفات الأصلية في `docs/MASTER_PROMPT_AR.md` والصور المرجعية في `designs/`. الصور ليست واجهات التطبيق ولا بديلاً عن هندسته الداخلية.
