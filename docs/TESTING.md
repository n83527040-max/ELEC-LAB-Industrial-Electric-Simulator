# التحقق والاختبارات

## الأوامر

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test --coverage
flutter build apk --release
```

وعلى Android SDK يمكن التحقق من التوقيع بـ`apksigner verify` ومن الحزمة بـ`aapt dump badging`. هذه الخطوات مؤتمتة في workflow.

## التغطية الوظيفية للاختبارات

| المجال | ملف الاختبار | الحالات |
|---|---|---|
| الأطراف والمشاريع | `test/models/project_model_test.dart` | تفرد الأطراف، الدوران، schema، migration، المراجع، القوالب، routing وsizing |
| الحل العددي | `test/simulation/linear_solver_test.dart` | أعداد مركبة، حل صحيح، رفض النظام المتفرد |
| DC والقياس | `test/simulation/dc_control_test.dart` | زر ومصباح، Voltmètre/Ampèremètre، التوصيل الخاطئ، Open fault |
| الملفات والزمن | `test/simulation/dc_control_test.dart` | Contacteur، تعشيق بعد تحرير Start، Stop NC، Coil open، ON-delay |
| الحماية والمحرك | `test/simulation/protection_and_motor_test.dart` | MCB، Fuse، Relais thermique، الأطوار، الاتجاه، فقدان الطور وإعادة النتائج |
| المحرر | `test/state/editor_controller_test.dart` | الإضافة والسحب والتوصيل والمسارات والطبقات والحفظ وUndo/Redo |
| التخزين | `test/storage/project_repository_test.dart` | ملفات حقيقية، فتح بعد الإغلاق، .bak، checksum، backup وpath traversal |
| 3D والتصدير | `test/export/export_and_mesh_test.dart` | هندسة وأطراف meshes، تدوير المجسم، PNG وPDF |
| التحديات | `test/learning/challenges_test.dart` | النجاح مرتبط بالحالة الكهربائية وتحرير Start |
| الواجهة | `test/widget/app_widget_test.dart` | RTL، dark/light، إنشاء مشروع وإضافة جهاز، هاتف صغير/landscape، Play/Stop |

الاختبارات لا تستبدل تجربة يدوية على عدة أجهزة Android فعلية، ولا تثبت سلامة دوائر حقيقية. النتائج التي تم الحصول عليها فعلاً في البيئة تُسجل في `docs/FINAL_REPORT.md` مع رقم CI run.
