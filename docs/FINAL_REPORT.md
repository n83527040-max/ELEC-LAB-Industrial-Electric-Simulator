# تقرير التسليم النهائي — ELEC LAB 0.5.1

تاريخ النشر والتحقق: **2026-10-28**. الأرقام والروابط أدناه مأخوذة من GitHub Actions وGitHub Release الفعليين، وليست توقعاً لنجاح البناء أو اختباراً على هاتف مادي.

## 1. الإصدار والتحميل

- **الحالة:** نُشرت **v0.5.1** بعد نجاح Format الصارم وStatic analysis و**99/99 اختباراً** وبناء Release APK وفحص ZIP وzipalign والتوقيع والحزمة.
- **CI run للنشر:** [40774148989](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40774148989).
- **commit المنشور:** `0fcc662b4ed155a04335674810a557d8610a04c4`.
- **Release:** [ELEC LAB v0.5.1](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.5.1).
- **تحميل APK مباشرة:** [app-release.apk](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/app-release.apk).
- **SHA-256:** [apk-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/apk-sha256.txt).
- **نتيجة آلية قابلة للتدقيق:** [verification.json](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/verification.json).
- **تقرير التوقيع وبصمة الشهادة:** [signature.log](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/signature.log) و[signing-cert-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/signing-cert-sha256.txt).
- **Artifact بديل لمدة 30 يوماً:** `elec-lab-release-apk` في CI run أعلاه، وقد يتطلب تنزيله تسجيل الدخول إلى GitHub.

كشف تدقيق الإصدارين المنشورين في run [40772218267](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40772218267) أن v0.4.0 وv0.5.0 كانا **v2 فقط** (`v1=false`) مع سلامة ZIP وzipalign. هذا يفسر رفض Android 6 للحزمة رغم نجاح تحقق v2 العام. أعيد البناء في v0.5.1 بتفعيل v1 وv2 صراحة، وأصبح CI يرفض النشر إذا لم يثبت `apksigner` كليهما لـminSdk 23.

## 2. بيانات APK المتحقق منها

| البيان | القيمة |
|---|---|
| إصدار التطبيق | `0.5.1+6` |
| Package | `com.eleclab.simulator` |
| نوع البناء | Flutter **Release** |
| حجم أصل APK في GitHub | **72,168,659 bytes** — **68.83 MiB** (72.17 MB عشرياً) |
| SHA-256 | `379bb06d09700072844fb24a31d781d101363c78952b5edc78bcd7b2fc19b1a6` |
| الحد الأدنى | Android 6.0 / API 23 |
| التوقيع | `v1=true` و`v2=true` عبر `apksigner --min-sdk-version 23`؛ مفتاح **debug** للتقييم |
| بصمة شهادة التوقيع SHA-256 | `137c8ec8e3b69a009d94ae4940bad70bbc7310d496fe7d733ce5c72319fb205a` |
| سلامة الأرشيف والمحاذاة | نجح `unzip -tqq` و`zipalign -c 4` |
| فحص الحزمة | نجح `aapt dump badging` |

الحجم وdigest أعلاه من GitHub Release API للأصل المنشور، ويُنشئ CI ملف الهاش و`verification.json` من APK نفسه قبل الرفع. **لم تتم تجربة التثبيت أو اللمس أو قياس الأداء على هاتف Android مادي داخل هذه البيئة.**

## 3. الفحوص المنفذة

| الفحص | النتيجة في run النشر |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | ناجح؛ أي فرق formatting يوقف CI |
| `flutter analyze` | ناجح |
| `flutter test --coverage --timeout=45s --concurrency=1` | **99/99 اختباراً ناجحاً** |
| `flutter build apk --release` | ناجح |
| `unzip -tqq` و`zipalign -c 4` | ناجحان |
| `apksigner verify --min-sdk-version 23 --verbose --print-certs` | ناجح؛ **v1=true وv2=true** مع استخراج بصمة الشهادة |
| `aapt dump badging` | ناجح |
| رفع APK وcoverage وSHA-256 وتقرير التوقيع و`verification.json` | ناجح |
| نشر GitHub Release | ناجح |

تعمل Flutter test shells بالتتابع للحد من ضغط الذاكرة دون حذف suites. فحص GLB يمر على الملفات والمثلثات والفهارس، لكنه يجمع صحة مثلثات كل ملف في expectation واحد لتجنب مئات الآلاف من allocations؛ نطاق الفحص لم يُخفّض.

تشمل الاختبارات MNA وDC/AC والقياسات الصحيحة والخاطئة، Start/Stop والتعشيق الذاتي والمؤقتات والحمايات، المحركات والمحولات، الحساسات والأحمال والكابل والبارات، المشاريع وschema v2 والحفظ الذري والاستيراد والنسخ الاحتياطي، Undo/Redo والطبقات ومسارات الأسلاك، الواجهات الصغيرة وFit/Zoom والمكتبة والتصدير. توجد اختبارات مستقلة لـDOL وÉtoile-triangle وفرض تعارض الملفين، واختبار واجهة يربط زوج التعشيق ويفكه فعلياً.

## 4. وظائف 0.5.0 وإصلاح التثبيت في 0.5.1

### إصلاح حزمة Android

- لم تتغير وظائف المحاكاة أو المشاريع أو الأصول في هذا الإصلاح؛ التغيير محصور في إصدار التطبيق وتوقيع Release وفحوص CI.
- فُعّل **JAR/v1** للتوافق مع Android 6 و**whole-APK/v2** لنظام Android 7 وأحدث. لا يكفي نجاح `flutter build apk`؛ يفحص CI المخططين صراحة قبل الرفع.
- ما زال المفتاح debug مؤقتاً للتقييم وليس مفتاح upload ثابتاً. اختلاف الشهادة عن نسخة قديمة يمنع التحديث فوقها؛ انسخ المشاريع أولاً ثم احذف النسخة القديمة عند الحاجة.

### Catalog والأصول

- **68 نوعاً، منها 41 نوعاً جديداً**، مع **204 ملفات GLB = 68 × 3 LODs**.
- حُفظت الحزمة المرجعية في `tool/asset_pack/`، واستُعملت **كل ملفات GLB المصدرية الثلاثين**. يسجل manifest مصدر كل نموذج وhash و`sourcePack.allUsed = true`.
- لكل نوع ملف مستقل في `board` و`preview` و`detailed`؛ التحميل كسول حسب النوع وLOD، ولا تُفك كل النماذج الثقيلة عند فتح التطبيق.
- فُكّت الملفات الـ204 داخل Flutter Test وقورنت بالـmanifest والأحجام والرؤوس والمثلثات والفهارس والأطراف. هذا تحقق بنيوي/برمجي، وليس ادعاء معاينة بصرية على هاتف مادي.

### اللوحة والتحرير

- Supply Bay ثابت أعلى اللوحة: 3~ مع L1/L2/L3/N/PE، و1~ مع L/N، وDC مع +/0V؛ المصادر مكونات كهربائية محفوظة وليست أجهزة حرة قابلة للنقل أو الحذف.
- Fit يشمل الإطار وDIN والتغذية، والتكبير محدود؛ سحب الخلفية لا يحرك اللوحة. الأجهزة والأسلاك وwaypoints وحدها قابلة للتحرير.
- لون السلك ونوعه ومقطعه mm² وعزله ومساره ونقاط انحنائه محفوظة. الحفظ التلقائي والمشاريع والطبقات وUndo/Redo والمشاركة والتصدير بقيت ضمن الاختبارات.
- نافذة المشروع الجديد تُبقي زر الإنشاء خارج منطقة التمرير، وتدعم ستة قوالب بما فيها DOL وÉtoile-triangle.

### المحاكاة والأجهزة

- **Démarrage direct:** قاطع محرك وContacteur وRelais thermique ومحرك six bornes موصل Triangle، مع Start/Stop وتعشيق ذاتي وحساب تيار وجهد من MNA.
- **Étoile-triangle:** ثلاثة Contacteurs ومؤقت changeover وNC متقاطع ونقاط قدرة وتوقيت star → delta. الاختبار يثبت اختلاف تيار النجمة عن المثلث ثم النقل والإيقاف وفقدان الطور.
- التعشيق الميكانيكي **per-instance**: لا ترثه كل الأجهزة من النوع نفسه. لا تُقبل إلا مجموعة من جهازين بدورَي `star` و`delta`. محرر الخصائص يحفظ الطرفين في Undo واحد، ويعالج النسخ والحذف وإعادة الإسناد دون مجموعة معلّقة.
- عند تغذية ملفَي star وdelta معاً، تُفتح **نقاط القدرة أثناء MNA stamping** ويظهر `interlock_conflict`. يوجد اختبار يفرض الحالتين معاً ويتحقق من بقاء المصابيح مفصولة، ثم يزيل التعشيق للطرفين ويثبت عملهما المستقل.
- أُضيفت واختُبرت عائلات MCB/RCCB وContacteur 4P ومفاتيح البناء وحساسات PNP والمرحل النبضي والثرموستات ومرحل الأطوار وCT/VT وWattmètre/Fréquencemètre والكابل والبارات. يوجد isolated MNA smoke test لكل الأنواع الـ68، إضافة إلى اختبارات سلوك مفصلة للعائلات المذكورة.

## 5. ما لم يُنفذ أو لم يُثبت

- **لا يوجد اختبار هاتف مادي** ولا قياس FPS/ذاكرة/حرارة على أجهزة Android متوسطة وضعيفة. التحميل الكسول وLOD واختبارات الواجهة لا تثبت وحدهما زوال الـlag على كل هاتف.
- العارض software renderer بخامات وإضاءة وdepth sorting، وليس PBR/OpenGL أو CAD photorealistic. الأصول تعليمية وليست مطابقة لمنتج تجاري أو اعتماداً معيارياً.
- DC وAC جيبي خطي steady-state فقط؛ لا عابرات كهرومغناطيسية أو harmonics أو قوساً كهربائياً أو نموذج تسخين ملف.
- المحرك نموذج معاوقة مكافئ. Étoile-triangle يحاكي التوصيل والتغذية والحماية والتتابع الكهربائي، **وليس العزم أو السرعة أو الانزلاق أو تسارع الحمل الميكانيكي**.
- CT والمحولات مثالية مع مقاومات وعبء؛ لا تشبع أو فاقد ديناميكي. الحساسات والثرموستات والأحمال وبعض الملحقات سلوكها مبسط، وليس نموذجاً لكل منتج حقيقي.
- قواعد الحماية واقتراح مقطع السلك تعليمية وليست منحنيات مصنعين أو وسيلة لاختيار حماية حقيقية. VFD وPLC غير منفذين ولا يظهران كأجهزة محاكاة مدعومة.
- وجود 68 نوعاً وsmoke test لكل نوع لا يعني اختبار كل توصيلة ممكنة لكل جهاز. الاختبارات السلوكية المفصلة موثقة في [`TESTING.md`](TESTING.md) و[`SIMULATION.md`](SIMULATION.md).
- التسليم Android فقط، والتوقيع debug للتقييم. لا تضمن هذه الهوية تحديثات مستقبلية فوق نسخ موقعة بمفتاح CI آخر؛ النشر الرسمي والتحديث المستقر يتطلبان مفتاح upload خاصاً وثابتاً لا يُودع في Git.

## 6. التثبيت والتحقق

1. صدّر مشاريعك أو انسخها احتياطياً إذا كانت لديك نسخة قديمة مثبتة.
2. احذف النسخة القديمة إذا منع اختلاف شهادة debug التحديث؛ حذف التطبيق قد يحذف بياناته المحلية غير المصدّرة.
3. نزّل [`app-release.apk`](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/app-release.apk) على Android 6.0 أو أحدث، واسمح بتثبيت التطبيقات من هذا المصدر عندما يطلب Android ذلك.
4. تحقق من الملف قبل التثبيت:

```bash
sha256sum app-release.apk
# 379bb06d09700072844fb24a31d781d101363c78952b5edc78bcd7b2fc19b1a6
```

بصمة شهادة APK نفسها، وهي مختلفة عن هاش الملف، موثقة في [`signing-cert-sha256.txt`](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.1/signing-cert-sha256.txt).

التفاصيل التقنية في [`SIMULATION.md`](SIMULATION.md) و[`PROJECT_FORMAT.md`](PROJECT_FORMAT.md) و[`ASSETS_3D.md`](ASSETS_3D.md) و[`UI_WORKSPACE.md`](UI_WORKSPACE.md) و[`TESTING.md`](TESTING.md).

> **تنبيه:** التطبيق تعليمي، وليس اعتماداً لتنفيذ دائرة حقيقية. لا تجرّب القصر أو الأعطال على معدات فعلية.
