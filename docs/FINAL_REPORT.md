# تقرير التسليم النهائي — ELEC LAB 0.1.0

تاريخ التحقق: **2026-10-27**. هذه النتائج مأخوذة من GitHub Actions وGitHub Release الفعليين، وليست توقعاً لنجاح البناء.

## 1. نتيجة التسليم

- **الحالة:** نجح Format وStatic analysis وجميع الاختبارات وبناء Release APK والتحقق من توقيعه وحزمته ونشره.
- **CI run:** [40575610998](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40575610998).
- **commit التطبيق:** `fdf5876b998f260943daf60e048a669637e37205`.
- **Release:** [ELEC LAB v0.1.0](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.1.0).
- **تحميل APK مباشرة:** [app-release.apk](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.1.0/app-release.apk).
- **ملف SHA-256:** [apk-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.1.0/apk-sha256.txt).
- **Artifact بديل:** `elec-lab-release-apk` في CI run أعلاه؛ مدة الاحتفاظ المضبوطة 30 يوماً وقد يتطلب التنزيل تسجيل الدخول إلى GitHub.

## 2. بيانات APK المتحقق منها

| البيان | القيمة |
|---|---|
| اسم الملف | `app-release.apk` |
| Package | `com.eleclab.simulator` |
| نوع البناء | Flutter **Release** |
| الحجم | **67,018,854 bytes** — **63.91 MiB** (67.02 MB عشرياً) |
| SHA-256 | `8c96c8888e782f20066803c80c9a5ed762066da11038a004cc984bb55380898a` |
| الحد الأدنى | Android 6.0 / API 23 |
| التوقيع | نجح `apksigner verify`؛ مفتاح **debug** لنسخة تقييم قابلة للتثبيت |
| فحص الحزمة | نجح `aapt dump badging` |

تمت مطابقة الحجم والهاش أعلاه مع metadata التي يسجلها GitHub لأصل Release المرفوع. لم تتم تجربة التثبيت على هاتف مادي داخل هذه البيئة؛ فحص قابلية التثبيت المؤتمت هو فحص البناء والحزمة والتوقيع، ولا يُدّعى أنه اختبار أجهزة فعلية.

## 3. الفحوص المنفذة في CI

| الفحص | النتيجة |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | ناجح |
| `flutter analyze` | ناجح |
| `flutter test --coverage` | **50/50 اختباراً ناجحاً** |
| `flutter build apk --release` | ناجح |
| `apksigner verify` و`aapt dump badging` | ناجحان |
| رفع APK وcoverage وSHA-256 | ناجح |
| نشر GitHub Release | ناجح |

تغطي الاختبارات MNA والأعداد المركبة، DC والقياسات الصحيحة والخاطئة، Contacteur والتعشيق الذاتي وStop NC وCoil open وON-delay، MCB/Fusible/Relais thermique، المحرك ثلاثي الطور واتجاهه وفقدان الطور، التحرير وUndo/Redo والطبقات والأسلاك، التخزين الذري وإعادة الفتح و`.bak` وChecksum والنسخ الاحتياطي وpath traversal، meshes وأطراف 3D وتفاعلها، PNG/PDF، التحديات، وإنشاء مشروع وإضافة جهاز والواجهات الصغيرة وPlay/Stop. التفاصيل في [`TESTING.md`](TESTING.md).

## 4. الميزات الموجودة فعلياً

- واجهة عربية RTL بمصطلحات فرنسية، Dark/Light محفوظان، وتصميم متجاوب.
- مشاريع وقوالب محلية، بحث وإعادة تسمية ونسخ وحذف وحفظ تلقائي ذري.
- محرر Pan/Zoom وGrid/Snap وتحريك وتدوير وتحجيم ونسخ وحذف وطبقات وUndo/Redo.
- كتالوج 18 نوعاً له نماذج وأطراف، مع Terminal-to-Terminal wiring ومسارات ونقاط انحناء وتحقق من التوصيل.
- محرك محاكاة مستقل لـDC وAC الجيبي الخطي، ملفات وتعشيق ومؤقتات وحمايات وأعطال وقياسات من الحل العددي نفسه.
- نموذج محرك ثلاثي الطور steady-state واتجاه التسلسل وفقدان الطور وعدم التوازن.
- مجسمات polygon meshes أصلية قابلة للتدوير والتكبير، وأطرافها مشتقة من كتالوج المحاكاة.
- استيراد/مشاركة مشروع بChecksum، نسخ احتياطي واستعادة، وتصدير PNG وPDF فعليين.
- مساعدة وتشخيص وتحديات محلية دون الاعتماد على خادم أو اتصال إنترنت.

## 5. حدود الاستخدام وما لم يُنفذ

- التطبيق تعليمي؛ **ليس أداة اعتماد لتنفيذ دوائر حقيقية**، ولا يجب تجربة القصر أو الأعطال على معدات فعلية.
- لا توجد عابرات كهرومغناطيسية أو harmonics أو قوس كهربائي أو نموذج تسخين ملف.
- المحرك نموذج معاوقة مستقر، وليس حساب إقلاع أو عزم أو انزلاق ميكانيكي.
- المحول وVFD وPLC وRCD غير منفذة، ولا تظهر كمكونات محاكاة مدعومة.
- قواعد MCB/Fusible/Relais thermique واقتراح مقطع السلك تعليمية مبسطة، وليست منحنيات مصنعين أو اعتماداً معيارياً.
- meshes تعليمية مبسطة وليست CAD photorealistic بأبعاد مصنع.
- التسليم الحالي Android؛ لم يُبنَ أو يُختبر إصدار iOS/Desktop/Web.
- اختبارات Flutter والأدوات الآلية لا تلغي الحاجة إلى اختبار يدوي على عدة هواتف Android وإصدارات نظام مختلفة.
- توقيع debug مناسب للتقييم فقط؛ النشر الرسمي يتطلب مفتاح upload خاصاً لا يُودع في Git.

## 6. التثبيت والتحقق

1. نزّل `app-release.apk` من الرابط المباشر أعلاه على Android 6.0 أو أحدث.
2. اسمح بتثبيت التطبيقات من هذا المصدر عندما يطلب Android ذلك.
3. إذا كانت هناك نسخة تقييم سابقة موقعة بمفتاح مختلف، قد يلزم حذفها أولاً؛ انسخ مشاريعك احتياطياً قبل الحذف.
4. تحقق من الملف قبل التثبيت:

```bash
sha256sum app-release.apk
# 8c96c8888e782f20066803c80c9a5ed762066da11038a004cc984bb55380898a
```

تفاصيل نطاق الحساب في [`SIMULATION.md`](SIMULATION.md)، وصيغة المشاريع في [`PROJECT_FORMAT.md`](PROJECT_FORMAT.md).
