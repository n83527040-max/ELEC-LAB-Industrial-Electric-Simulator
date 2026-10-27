# ELEC LAB — Industrial Electric Simulator

تطبيق Android مبني بـFlutter لمختبر كهرباء صناعية تعليمي يعمل دون إنترنت. يتيح بناء مخطط بمكونات وأطراف حقيقية داخل نموذج البيانات، ثم حل الدائرة وقراءة التيار والجهد وسلوك الحمايات.

> **تنبيه:** المحاكاة تعليمية فقط، وليست اعتماداً لتصميم أو تنفيذ دائرة حقيقية. لا تجرب القصر أو الأعطال على معدات فعلية.

## ما هو منفذ في المصدر

- واجهة عربية RTL بمصطلحات فرنسية، وضع داكن/فاتح محفوظ محلياً، وتصميم متجاوب للهاتف والدوران.
- مشاريع محلية: إنشاء من لوحة فارغة أو قوالب، فتح، بحث، إعادة تسمية، نسخ، حذف بتأكيد، وحفظ تلقائي ذري.
- لوحة Pan/Zoom، شبكة وSnap، تحريك/تدوير/نسخ/حذف/تحجيم، طبقات قابلة للتسمية والإخفاء والقفل، وUndo/Redo.
- توصيل Terminal-to-Terminal مع تحقق، مسارات Straight/90°/Curved، ألوان ومقاطع وأنواع وعزل، ونقاط انحناء قابلة للتحريك.
- محرك MNA مستقل بأعداد مركبة لـDC وAC RMS، Contacteur وRelais وTemporisateur وتعشيق ذاتي، حمايات وأعطال وقياسات.
- محرك ثلاثي الطور مكافئ مع حساب فقدان الطور وعدم التوازن واتجاه التسلسل.
- مجسمات صناعية polygon meshes مخصصة لكل عائلة، مع LOD خفيف للوحة وpreview للمكتبة ونموذج مفصل قابل للتدوير والتكبير؛ أطرافها من تعريف المحاكاة نفسه.
- مكتبة متجاوبة بلا قص، ولوحة تركيب/شبكة قابلة للتبديل، Fit وتحريك سلس، أطراف تظهر عند التحديد ومسارات تتفادى الأجهزة قدر الإمكان.
- Voltmètre وAmpèremètre وتيارات الأسلاك والرسائل التشخيصية والمساعدة المحلية والتحديات.
- مشاركة مشروع بChecksum واستيراده، نسخة احتياطية واستعادتها، وتصدير PNG وPDF فعليين.

## نطاق وقيود مهمة

هذا الإصدار **ليس محللاً عاماً لكل دوائر الكهرباء الصناعية**:

- DC وAC جيبي خطي فقط؛ لا عابرات كهرومغناطيسية ولا harmonics.
- المحرك نموذج معاوقة steady-state، وليس نموذج إقلاع/عزم/انزلاق ميكانيكي.
- المحول وVFD وPLC وRCD غير منفذة، ولذلك لا تظهر كمكونات محاكاة مدعومة.
- منحنيات الحماية واقتراح مقطع السلك تعليمية مبسطة وليست مطابقة لمعايير أو كتالوجات مصنعين.
- meshes مبسطة وليست نماذج CAD photorealistic بأبعاد مصنع.

التفاصيل والمعادلات في [`docs/SIMULATION.md`](docs/SIMULATION.md)، وصيغة الحفظ في [`docs/PROJECT_FORMAT.md`](docs/PROJECT_FORMAT.md)، والأصول في [`docs/ASSETS_3D.md`](docs/ASSETS_3D.md)، وتحسينات المكتبة واللوحة في [`docs/UI_WORKSPACE.md`](docs/UI_WORKSPACE.md).

## المكونات المدعومة حالياً

Alimentation DC، Alimentation monophasée، Alimentation triphasée، Disjoncteur MCB، Contacteur 3P + aux، Relais thermique، Relais auxiliaire، Boutons NO/NC، Sélecteur، Temporisateur ON-delay، Capteur NO، Voyant، Moteur triphasé، Bornier، Voltmètre، Ampèremètre وFusible.

## التشغيل والبناء

المتطلبات: Flutter stable، Android SDK وJava 17. الحد الأدنى للتطبيق Android 6.0 (API 23).

```bash
flutter pub get
dart format lib test
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

النسخة المتحقق منها **v0.2.0** نجحت في Format وAnalyze و**59/59 اختباراً** وبناء APK وفحص التوقيع والحزمة ونشر Release. يمكن تنزيلها مباشرة من [GitHub Release](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.2.0/app-release.apk). الحجم **67,149,922 bytes (64.04 MiB)** وSHA-256 هو `b5c3417af502ac4a867d8845d1ef1fc900ae50ada9bcad1d5b98a9a3d69ba20c`. روابط CI والقيود الكاملة موثقة في [`docs/FINAL_REPORT.md`](docs/FINAL_REPORT.md).

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
