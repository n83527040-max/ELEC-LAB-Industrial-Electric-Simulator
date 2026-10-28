# التحقق والاختبارات

## الأوامر

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build apk --release
```

وعلى Android SDK يمكن التحقق من التوقيع بـ`apksigner verify` ومن الحزمة بـ`aapt dump badging`. هذه الخطوات مؤتمتة في workflow. يستعمل CI الأمر `flutter test --coverage --timeout=45s --concurrency=1` لتشغيل كل الحالات مع الحد من ذاكرة Flutter shells المتوازية؛ لا تُحذف أي suites. فحص GLB يجمع صحة مثلثات كل ملف في expectation واحد بدل إنشاء matcher مستقل لكل مثلث، مع بقاء المرور على جميع الفهارس.

## التغطية الوظيفية للاختبارات

| المجال | ملف الاختبار | الحالات |
|---|---|---|
| الأطراف والمشاريع | `test/models/project_model_test.dart` | تفرد الأطراف، الدوران، schema، migration، Supply Bay وPE والحفظ، المراجع، القوالب، routing وsizing |
| الحل العددي | `test/simulation/linear_solver_test.dart` | أعداد مركبة، حل صحيح، رفض النظام المتفرد |
| DC والقياس | `test/simulation/dc_control_test.dart` | زر ومصباح، Voltmètre/Ampèremètre، التوصيل الخاطئ، Open fault |
| الملفات والزمن | `test/simulation/dc_control_test.dart` | Contacteur، تعشيق بعد تحرير Start، Stop NC، Coil open، ON-delay |
| الحماية والمحرك | `test/simulation/protection_and_motor_test.dart` | MCB، Fuse، Relais thermique، الأطوار، الاتجاه، فقدان الطور وإعادة النتائج |
| الأجهزة الموسعة | `test/simulation/extended_devices_test.dart` | المحول، OFF-delay، ΔI وRCD، قاطع المحرك، المحرك الأحادي، العداد، Emergency/Rotary، الحساسات، ودائرة محرك Start/Stop مع PE |
| DOL وÉtoile-triangle | `test/simulation/star_delta_test.dart` | التشغيل والتعشيق الذاتي والإيقاف، تيار النجمة والمثلث، النقل بالمؤقت، فقدان الطور، فرض الملفين معاً وفتح القدرة، واستقلال الأنواع غير المعيّنة |
| Catalog والأجهزة الجديدة | `test/models/catalog_extensions_test.dart` و`test/simulation/extended_catalog_devices_test.dart` | 41 امتداداً و68/68 isolated stamps، مفاتيح وحساسات PNP وImpulse/Thermostat/Phase relay وCT وVT وWattmètre/Fréquencemètre وRCCB والكابل والبارات |
| سلامة زوج التعشيق | `test/models/project_model_test.dart` و`test/state/editor_controller_test.dart` | رفض الجهاز الواحد/الثلاثة والأدوار المتماثلة والنوع غير المناسب، الحفظ الذري وUndo/Redo ومنع توريث النسخ والتنظيف عند الحذف |
| المحرر | `test/state/editor_controller_test.dart` | الإضافة والسحب والتوصيل وDIN snap والمصادر الثابتة والمسارات والطبقات والحفظ وUndo/Redo |
| التخزين | `test/storage/project_repository_test.dart` | ملفات حقيقية، فتح بعد الإغلاق، .bak، checksum، backup وpath traversal |
| ملفات GLB | `test/three_d/glb_asset_test.dart` | فك كل الملفات الـ204 من asset bundle، manifest والأحجام والمثلثات والفهارس والأطراف، لون المصباح ورفض الملف غير الصالح |
| 3D والتصدير | `test/export/export_and_mesh_test.dart` | LOD لكل الأنواع، تفرد الهندسة، تطابق الأطراف، هامش بلا قص بعد perspective، PNG وPDF |
| العارض التفاعلي | `test/three_d/interactive_mesh_viewer_test.dart` | تحميل GLB المفصل قبل تركيب الواجهة، السحب والتدوير ودورة حياة الإيماءات في suite مستقلة عن raster async |
| ثبات اللوحة | `test/widget/board_viewport_test.dart` | Fit كامل على الهاتف، منع سحب الخلفية، Zoom وFit، تغيير الاتجاه وثبات المصادر |
| التحديات | `test/learning/challenges_test.dart` | النجاح مرتبط بالحالة الكهربائية وتحرير Start |
| الواجهة | `test/widget/app_widget_test.dart` | RTL، dark/light، إنشاء مشروع وإضافة جهاز، هاتف صغير/landscape، Play/Stop، ربط وفك زوج التعشيق من واجهة الخصائص |
| المكتبة واللوحة | `test/widget/component_library_test.dart` | بحث وتصفية، المرور على كل بطاقات الأنواع الـ68 في landscape، إخفاء/إظهار الأطراف ولمسها بعد التحجيم والتدوير، وتفعيل Supply Bay وبدء سلك من L1 |

الاختبارات لا تستبدل تجربة يدوية على عدة أجهزة Android فعلية، ولا تثبت سلامة دوائر حقيقية. النتائج التي تم الحصول عليها فعلاً في البيئة تُسجل في `docs/FINAL_REPORT.md` مع رقم CI run.
