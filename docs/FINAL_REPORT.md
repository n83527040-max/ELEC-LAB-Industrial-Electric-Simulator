# تقرير التسليم النهائي — ELEC LAB 0.2.0

تاريخ التحقق: **2026-10-27**. هذه النتائج مأخوذة من GitHub Actions وGitHub Release الفعليين بعد اكتمال البناء والنشر، وليست توقعاً لنجاحهما.

## 1. نتيجة التسليم

- **الحالة:** نجح Format وStatic analysis وجميع الاختبارات وبناء Release APK والتحقق من توقيعه وحزمته ونشره.
- **CI run:** [40582791684](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40582791684).
- **commit التطبيق:** `e7328c36242dd14726a9ec5e850e33eb79f29afd`.
- **Release:** [ELEC LAB v0.2.0](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.2.0).
- **تحميل APK مباشرة:** [app-release.apk](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.2.0/app-release.apk).
- **ملف SHA-256:** [apk-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.2.0/apk-sha256.txt).
- **Artifact بديل:** `elec-lab-release-apk` في CI run أعلاه؛ مدة الاحتفاظ 30 يوماً وقد يتطلب التنزيل تسجيل الدخول إلى GitHub.

## 2. بيانات APK المتحقق منها

| البيان | القيمة |
|---|---|
| اسم الأصل في Release | `app-release.apk` — بعنوان `ELEC-LAB-0.2.0-android.apk` |
| إصدار التطبيق | `0.2.0+2` |
| Package | `com.eleclab.simulator` |
| نوع البناء | Flutter **Release** |
| الحجم | **67,149,922 bytes** — **64.04 MiB** (67.15 MB عشرياً) |
| SHA-256 | `b5c3417af502ac4a867d8845d1ef1fc900ae50ada9bcad1d5b98a9a3d69ba20c` |
| الحد الأدنى | Android 6.0 / API 23 |
| التوقيع | نجح `apksigner verify`؛ مفتاح **debug** لنسخة تقييم قابلة للتثبيت |
| فحص الحزمة | نجح `aapt dump badging` |

الحجم والهاش أعلاه من metadata التي يسجلها GitHub لأصل APK المنشور، وRelease يشير إلى commit التطبيق المذكور. لم تتم تجربة التثبيت على هاتف مادي داخل هذه البيئة؛ التحقق المؤتمت يثبت نجاح البناء والحزمة والتوقيع، ولا يُدّعى أنه اختبار أجهزة فعلية.

## 3. الفحوص المنفذة في CI

| الفحص | النتيجة |
|---|---|
| `dart format lib test` | ناجح |
| `flutter analyze` | ناجح |
| `flutter test --coverage` | **59/59 اختباراً ناجحاً** |
| `flutter build apk --release` | ناجح |
| `apksigner verify` و`aapt dump badging` | ناجحان |
| رفع APK وcoverage وSHA-256 | ناجح |
| نشر GitHub Release | ناجح |

تغطي الاختبارات MNA والأعداد المركبة، DC والقياسات الصحيحة والخاطئة، Contacteur والتعشيق الذاتي وStop NC وCoil open وON-delay، MCB/Fusible/Relais thermique، المحرك ثلاثي الطور واتجاهه وفقدان الطور، التحرير وUndo/Redo والطبقات والأسلاك، التخزين الذري وإعادة الفتح و`.bak` وChecksum والنسخ الاحتياطي وpath traversal، وPNG/PDF والتحديات والواجهات الصغيرة وPlay/Stop.

أضاف هذا الإصدار تحققاً من اختلاف هندسات الأجهزة وLOD لكل الأنواع الـ18، وتطابق أطراف meshes مع الكتالوج، وهامش شفاف فعلي حول كل preview بفحص RGBA pixels لمنع القص. كما يغطي اختبار اللوحة إخفاء الأطراف ثم إظهارها، والضغط الحقيقي على زر الطرف وبدء السلك، وبقاء التفاعل بعد التحجيم والتدوير. التفاصيل في [`TESTING.md`](TESTING.md).

## 4. أهم تحسينات 0.2.0

- **18 هندسة polygon مخصصة** مختلفة حسب العائلة، لا مجرد تغيير اسم أو لون: Contacteur وMCB وRelais thermique وMoteur بزعانف وعمود، والأزرار والحساسات وBorniers ومصادر التغذية وأجهزة القياس وغيرها.
- ثلاث درجات `MeshDetail`: **board** خفيفة للوحة والتصدير، **preview** للمكتبة، و**detailed** عند فتح الجهاز؛ مع إنشاء lazy وcache حسب النوع والمستوى.
- Renderer بإضاءة وخامات وdepth sorting وauto-fit **بعد perspective**، ومنظور ثابت المقياس على اللوحة حتى تتطابق مواقع الجهاز والأطراف والأسلاك.
- مكتبة responsive ببطاقات موحدة وأسماء عربية/فرنسية وبحث وتصنيف وتصفية، بلا قص في اختبارات الهاتف الضيق وlandscape.
- سطح لوحة صناعية أو شبكة هادئة، Pan/Zoom وFit، وتحديد وتحريك وتدوير وتحجيم مع بقاء الطبقات وUndo/Redo والحفظ التلقائي.
- الأطراف تظهر عند التحديد أو التوصيل فقط، مع مساحة لمس إضافية مؤقتة للأطراف الواقعة على حدود الجهاز؛ الإحداثيات الكهربائية ونقاط الأسلاك لا تتغير.
- مسارات Orthogonal تفضل قنوات حول الأجهزة الأخرى، مع بقاء waypoints وخصائص الأسلاك وربطها الحقيقي بالمحاكاة.
- لم تتغير صيغة المشاريع أو schema v2، ولم تُحذف وظائف الحفظ أو الاستيراد أو التصدير أو الحساب.

## 5. حدود الاستخدام وما لم يُنفذ

- التطبيق تعليمي؛ **ليس أداة اعتماد لتنفيذ دوائر حقيقية**، ولا يجب تجربة القصر أو الأعطال على معدات فعلية.
- لا توجد عابرات كهرومغناطيسية أو harmonics أو قوس كهربائي أو نموذج تسخين ملف.
- المحرك نموذج معاوقة مستقر، وليس حساب إقلاع أو عزم أو انزلاق ميكانيكي.
- المحول وVFD وPLC وRCD غير منفذة، ولا تظهر كمكونات محاكاة مدعومة؛ لم يُضف Transformateur شكلي بلا نموذج سلوكي.
- قواعد MCB/Fusible/Relais thermique واقتراح مقطع السلك تعليمية مبسطة، وليست منحنيات مصنعين أو اعتماداً معيارياً.
- meshes أصلية مخصصة للتعلم وليست CAD photorealistic أو مطابقة لأبعاد وترتيب أطراف منتج تجاري محدد. العارض software renderer وليس PBR/OpenGL.
- تحسين LOD والـcache والاختبارات الآلية لا يغني عن قياس الأداء واللمس يدوياً على هواتف Android متوسطة وضعيفة متعددة؛ لم يُجرَ ذلك في هذه البيئة.
- التسليم الحالي Android؛ لم يُبنَ أو يُختبر إصدار iOS/Desktop/Web.
- توقيع debug مناسب للتقييم فقط؛ النشر الرسمي يتطلب مفتاح upload خاصاً لا يُودع في Git.

## 6. التثبيت والتحقق

1. نزّل `app-release.apk` من الرابط المباشر أعلاه على Android 6.0 أو أحدث.
2. اسمح بتثبيت التطبيقات من هذا المصدر عندما يطلب Android ذلك.
3. إذا كانت هناك نسخة تقييم سابقة موقعة بمفتاح مختلف، قد يلزم حذفها أولاً؛ انسخ مشاريعك احتياطياً قبل الحذف.
4. تحقق من الملف قبل التثبيت:

```bash
sha256sum app-release.apk
# b5c3417af502ac4a867d8845d1ef1fc900ae50ada9bcad1d5b98a9a3d69ba20c
```

تفاصيل نطاق الحساب في [`SIMULATION.md`](SIMULATION.md)، وصيغة المشاريع في [`PROJECT_FORMAT.md`](PROJECT_FORMAT.md)، والأصول في [`ASSETS_3D.md`](ASSETS_3D.md)، والمكتبة واللوحة في [`UI_WORKSPACE.md`](UI_WORKSPACE.md).
