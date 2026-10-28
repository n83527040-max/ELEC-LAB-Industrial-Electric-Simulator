# تقرير التسليم النهائي — ELEC LAB 0.5.0

تاريخ النشر والتحقق: **2026-10-28**. الأرقام والروابط أدناه مأخوذة من GitHub Actions وGitHub Release الفعليين، وليست توقعاً لنجاح البناء أو اختباراً على هاتف مادي.

## 1. الإصدار والتحميل

- **الحالة:** نُشرت **v0.5.0** بعد نجاح Format الصارم وStatic analysis و**99/99 اختباراً** وبناء Release APK وفحص التوقيع والحزمة.
- **CI run للنشر:** [40767439321](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40767439321).
- **commit المنشور:** `9893d22e51f81051095103fa1ccc4aa1bea804da`.
- **Release:** [ELEC LAB v0.5.0](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/tag/v0.5.0).
- **تحميل APK مباشرة:** [app-release.apk](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.0/app-release.apk).
- **SHA-256:** [apk-sha256.txt](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.0/apk-sha256.txt).
- **نتيجة آلية قابلة للتدقيق:** [verification.json](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.0/verification.json).
- **Artifact بديل لمدة 30 يوماً:** `elec-lab-release-apk` في CI run أعلاه، وقد يتطلب تنزيله تسجيل الدخول إلى GitHub.

سبق النشر تحقق كامل في run [40766635432](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/actions/runs/40766635432). commit النشر فارغ المحتوى بعده، ولذلك بقيت شجرة التطبيق نفسها دون تغيير بين التحقق والنشر.

## 2. بيانات APK المتحقق منها

| البيان | القيمة |
|---|---|
| إصدار التطبيق | `0.5.0+5` |
| Package | `com.eleclab.simulator` |
| نوع البناء | Flutter **Release** |
| حجم أصل APK في GitHub | **72,105,383 bytes** — **68.77 MiB** (72.11 MB عشرياً) |
| SHA-256 | `090a561c6d3b54f77b212d66524e38f658104c973d243a23d0ea62cc405aa9db` |
| الحد الأدنى | Android 6.0 / API 23 |
| التوقيع | نجح `apksigner verify`؛ مفتاح **debug** لنسخة تقييم قابلة للتثبيت |
| فحص الحزمة | نجح `aapt dump badging` |

الحجم وdigest أعلاه من GitHub Release API للأصل المنشور، ويُنشئ CI ملف الهاش و`verification.json` من APK نفسه قبل الرفع. **لم تتم تجربة التثبيت أو اللمس أو قياس الأداء على هاتف Android مادي داخل هذه البيئة.**

## 3. الفحوص المنفذة

| الفحص | النتيجة في run النشر |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | ناجح؛ أي فرق formatting يوقف CI |
| `flutter analyze` | ناجح |
| `flutter test --coverage --timeout=45s --concurrency=1` | **99/99 اختباراً ناجحاً** |
| `flutter build apk --release` | ناجح |
| `apksigner verify` و`aapt dump badging` | ناجحان |
| رفع APK وcoverage وSHA-256 و`verification.json` | ناجح |
| نشر GitHub Release | ناجح |

تعمل Flutter test shells بالتتابع للحد من ضغط الذاكرة دون حذف suites. فحص GLB يمر على الملفات والمثلثات والفهارس، لكنه يجمع صحة مثلثات كل ملف في expectation واحد لتجنب مئات الآلاف من allocations؛ نطاق الفحص لم يُخفّض.

تشمل الاختبارات MNA وDC/AC والقياسات الصحيحة والخاطئة، Start/Stop والتعشيق الذاتي والمؤقتات والحمايات، المحركات والمحولات، الحساسات والأحمال والكابل والبارات، المشاريع وschema v2 والحفظ الذري والاستيراد والنسخ الاحتياطي، Undo/Redo والطبقات ومسارات الأسلاك، الواجهات الصغيرة وFit/Zoom والمكتبة والتصدير. توجد اختبارات مستقلة لـDOL وÉtoile-triangle وفرض تعارض الملفين، واختبار واجهة يربط زوج التعشيق ويفكه فعلياً.

## 4. ما أُنجز في 0.5.0

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
- التسليم Android فقط، والتوقيع debug للتقييم. النشر الرسمي يتطلب مفتاح upload خاصاً لا يُودع في Git.

## 6. التثبيت والتحقق

1. نزّل [`app-release.apk`](https://github.com/n83527040-max/ELEC-LAB-Industrial-Electric-Simulator/releases/download/v0.5.0/app-release.apk) على Android 6.0 أو أحدث.
2. اسمح بتثبيت التطبيقات من هذا المصدر عندما يطلب Android ذلك.
3. انسخ مشاريعك احتياطياً قبل إزالة أي نسخة سابقة موقعة بمفتاح مختلف.
4. تحقق من الملف:

```bash
sha256sum app-release.apk
# 090a561c6d3b54f77b212d66524e38f658104c973d243a23d0ea62cc405aa9db
```

التفاصيل التقنية في [`SIMULATION.md`](SIMULATION.md) و[`PROJECT_FORMAT.md`](PROJECT_FORMAT.md) و[`ASSETS_3D.md`](ASSETS_3D.md) و[`UI_WORKSPACE.md`](UI_WORKSPACE.md) و[`TESTING.md`](TESTING.md).

> **تنبيه:** التطبيق تعليمي، وليس اعتماداً لتنفيذ دائرة حقيقية. لا تجرّب القصر أو الأعطال على معدات فعلية.
