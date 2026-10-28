# تقرير التسليم النهائي — ELEC LAB 0.4.0

تاريخ التحقق: **2026-10-28**. هذه النتائج مأخوذة من GitHub Actions وGitHub Release الفعليين بعد اكتمال البناء والنشر، وليست توقعاً لنجاحهما.

## 1. نتيجة التسليم

- **الحالة:** نجح Format وStatic analysis وجميع الاختبارات وبناء Release APK والتحقق من توقيعه وحزمته ونشره.
- **CI run:** [40618977368](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40618977368).
- **commit التطبيق والإصدار:** `53fad6f3d28e374f4c5aaf85836446d6153bb1b9`.
- **Release:** [ELEC LAB v0.4.0](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.4.0).
- **تحميل APK مباشرة:** [app-release.apk](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.4.0/app-release.apk).
- **ملف SHA-256:** [apk-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.4.0/apk-sha256.txt).
- **Artifact بديل:** `elec-lab-release-apk` في CI run أعلاه؛ مدة الاحتفاظ 30 يوماً وقد يتطلب التنزيل تسجيل الدخول إلى GitHub.

## 2. بيانات APK المتحقق منها

| البيان | القيمة |
|---|---|
| اسم الملف في Release | `app-release.apk` — بعنوان `ELEC-LAB-0.4.0-android.apk` |
| إصدار التطبيق | `0.4.0+4` |
| Package | `com.eleclab.simulator` |
| نوع البناء | Flutter **Release** |
| الحجم | **69,119,205 bytes** — **65.92 MiB** (69.12 MB عشرياً) |
| SHA-256 | `46ec36fc28f6ba60563f330d3e606d6f61adc0bcbbb4250cfb7718e1469f8859` |
| الحد الأدنى | Android 6.0 / API 23 |
| التوقيع | نجح `apksigner verify`؛ مفتاح **debug** لنسخة تقييم قابلة للتثبيت |
| فحص الحزمة | نجح `aapt dump badging` |

الحجم والهاش أعلاه من metadata التي يسجلها GitHub لأصل APK المنشور، ونفذ CI أيضاً `sha256sum` قبل رفع الملف. يشير Release إلى commit التطبيق المذكور. لم تتم تجربة التثبيت على هاتف مادي داخل هذه البيئة؛ التحقق المؤتمت يثبت نجاح البناء والحزمة والتوقيع، ولا يُدّعى أنه اختبار أجهزة فعلية.

## 3. الفحوص المنفذة في CI

| الفحص | النتيجة |
|---|---|
| `dart format lib test` | ناجح |
| `flutter analyze` | ناجح |
| `flutter test --coverage --timeout=45s --concurrency=1` | **75/75 اختباراً ناجحاً** |
| `flutter build apk --release` | ناجح |
| `apksigner verify` و`aapt dump badging` | ناجحان |
| رفع APK وcoverage وSHA-256 | ناجح |
| نشر GitHub Release | ناجح |

تعمل اختبارات Flutter shells المتخصصة بالتتابع في CI للحد من ضغط الذاكرة، مع بقاء جميع الحالات فعالة. فحص GLB يمر على كل مثلث لكنه يجمع النتيجة في expectation واحد لكل ملف بدل إنشاء مئات الآلاف من matchers؛ هذا لا يقلل نطاق التحقق.

تغطي الاختبارات MNA والأعداد المركبة، DC وAC والقياسات الصحيحة والخاطئة، Contacteur والتعشيق الذاتي وStop NC وCoil open وON/OFF-delay، وMCB/RCD/Disjoncteur moteur/Fusible/Relais thermique. كما تغطي المحول المقترن، المحركين ثلاثي وأحادي الطور، الأطوار والاتجاه وفقدان الطور، العداد وkWh، الحساسات وFin de course وEmergency وCommutateur، ودائرة Start/Stop كاملة مع PE.

تشمل باقي الحالات Supply Bay الافتراضي OFF، تفرد الأطراف، DIN snap وتثبيت المصادر، schema v2 وmigration وPE roundtrip، التحرير وUndo/Redo والطبقات والأسلاك والمسارات، التخزين الذري وإعادة الفتح و`.bak` وChecksum والنسخ الاحتياطي وpath traversal، وPNG/PDF والتحديات والواجهات الصغيرة وPlay/Stop. يمر اختبار المكتبة على كل الأنواع الـ27 ويجعل البطاقات ظاهرة فعلاً قبل فحصها، وتُختبر أطراف اللوحة باللمس بعد التحجيم والتدوير. التفاصيل في [`TESTING.md`](TESTING.md).

## 4. المجسمات واللوحة المطورة فعلاً في 0.4.0

- **27 نوعاً × 3 LOD = 81 ملف GLB مستقلاً** داخل `assets/models/{board,preview,detailed}/`. الحجم الكلي للملفات هو **6,089,340 bytes (5.81 MiB)**، وأكبر ملف 256,496 bytes. `manifest.json` يسجل المسارات والأحجام والأبعاد وSHA-256.
- فُكّت الملفات الـ81 فعلياً في Flutter Test وقورنت بالـmanifest وعدد الرؤوس والمثلثات والفهارس والأطراف. الاختبار يغطي أيضاً تغير خامة المصباح ورفض GLB غير الصالح بدل استبداله بشكل وهمي.
- الأصول أصلية brand-free منشأة خصوصاً للتطبيق، وليست screenshots أو مجرد أشكال موحدة بتغيير اللون. تشمل حسب العائلة هياكل DIN ومشابك وبراغي وفتحات أسلاك وقواعد عازلة وشاشات وأقراص ضبط، وزعانف وعموداً وصندوق أطراف للمحرك، وقلباً وملفات للمحول.
- decoder مخصص لـGLB 2.0 الثنائي الداخلي يقرأ JSON/BIN وVEC3 float وtriangle indices وPBR base colors. التحميل كسول ومخزن حسب النوع وLOD ولون المصباح؛ لا تُفك كل النماذج المفصلة عند فتح التطبيق.
- اللوحة والمكتبة والعارض المفصل وthumbnails وPNG/PDF تستعمل الأصول نفسها. `ComponentCatalog` يبقى مصدر معرف الطرف ونوعه وموقعه، ويغذي MeshTerminal والأسلاك وعقد MNA؛ L1/T1 وA1/A2 والأطراف المساعدة لا تُخلط.
- **اللوحة كاملة وثابتة:** Fit يشمل `boardWidth × boardHeight` والإطار وDIN وSupply Bay. سحب الخلفية بإصبع واحد معطل، والأجهزة والأسلاك وwaypoints وحدها قابلة للتحرير. التكبير محدود ولا يسمح بإخراج اللوحة من الحدود، وشريط الأزرار له مساحة منفصلة.
- أُصلح Fit على الهاتف بقياس X/Y للمصفوفة بدل `getMaxScaleOnAxis()` الذي كان يرى Z=1 ويعيد 100% عندما يكون المقياس المطلوب أصغر. اختُبر Fit وZoom ومنع السحب وتغير الاتجاه على أحجام اختبار portrait وlandscape.
- الصور المصغرة تُعيد تحميل meshes عند تغير المشروع ولا ترسم جهازاً قبل وصول هندسته؛ أُصلح سباق إضافة جهاز مع بقاء `updatedAt` نفسه.
- اختبار العارض التفاعلي منفصل عن raster async الخاص بالتصدير، ويستخدم GLB المفصل الفعلي ويتحقق من السحب والتدوير دون إسقاط assertions.

## 5. مصدر الأصول وما لم يُنفذ

- حزمة `ELEC_LAB_3D_PRO_ASSET_PACK.zip` المذكورة في الطلب **لم تكن موجودة في مساحة العمل أو المرفقات المتاحة**، ولم توجد GLB مرجعية داخلها يمكن فحصها. لذلك لم تُنسب أي أصول لتلك الحزمة؛ الملفات الحالية مولدة محلياً وموثقة في [`ASSETS_3D.md`](ASSETS_3D.md).
- المجسمات تعليمية مخصصة وليست CAD photorealistic أو مطابقة لأبعاد وترتيب أطراف منتج تجاري محدد. العارض software renderer بخامات وإضاءة وdepth sorting، وليس PBR/OpenGL. decoder ليس عارض glTF عاماً ولا يدعم textures أو external buffers أو skins أو animations.
- لم تُجرَ معاينة يدوية أو قياس أداء ولمس على مجموعة هواتف Android مادية متوسطة وضعيفة. اختبارات أحجام الشاشة والاتجاه آلية ولا تغني عن هذا التحقق.
- التطبيق تعليمي؛ **ليس أداة اعتماد لتنفيذ دوائر حقيقية**، ولا يجب تجربة القصر أو الأعطال على معدات فعلية.
- DC وAC جيبي خطي في steady-state؛ لا توجد عابرات كهرومغناطيسية أو harmonics أو قوس كهربائي أو نموذج تسخين ملف. المحرك نموذج معاوقة مكافئ، والمحول AC مثالي مع مقاومتي الملفات فقط.
- RCD ثنائي القطب يحسب ΔI من L+N؛ لا يحاكي منحنيات المصنعين أو كل أشكال أعطال الأرضي. VFD وPLC غير منفذين ولا يظهران كمكونات محاكاة مدعومة.
- قواعد MCB/Fusible/Relais thermique/Disjoncteur moteur واقتراح مقطع السلك تعليمية مبسطة، وليست منحنيات مصنعين أو اعتماداً معيارياً.
- التسليم الحالي Android؛ لم يُبنَ أو يُختبر إصدار iOS/Desktop/Web. توقيع debug مناسب للتقييم فقط، والنشر الرسمي يتطلب مفتاح upload خاصاً لا يُودع في Git.

## 6. التثبيت والتحقق

1. نزّل `app-release.apk` من الرابط المباشر أعلاه على Android 6.0 أو أحدث.
2. اسمح بتثبيت التطبيقات من هذا المصدر عندما يطلب Android ذلك.
3. إذا كانت هناك نسخة تقييم سابقة موقعة بمفتاح مختلف، قد يلزم حذفها أولاً؛ انسخ مشاريعك احتياطياً قبل الحذف.
4. تحقق من الملف قبل التثبيت:

```bash
sha256sum app-release.apk
# 46ec36fc28f6ba60563f330d3e606d6f61adc0bcbbb4250cfb7718e1469f8859
```

تفاصيل نطاق الحساب في [`SIMULATION.md`](SIMULATION.md)، وصيغة المشاريع في [`PROJECT_FORMAT.md`](PROJECT_FORMAT.md)، والأصول في [`ASSETS_3D.md`](ASSETS_3D.md)، والمكتبة واللوحة في [`UI_WORKSPACE.md`](UI_WORKSPACE.md).
