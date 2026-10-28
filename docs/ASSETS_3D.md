# الأصول ثلاثية الأبعاد والبصرية

## حالة حزمة المستخدم

طلب التطوير يشير إلى `ELEC_LAB_3D_PRO_ASSET_PACK.zip` ومجلد `models/`. عند فحص مساحة العمل والمرفقات المتاحة لم يكن هذا الملف موجوداً، ولم تكن هناك أي ملفات GLB داخل المشروع. ZIP القديم `ELEC_LAB_Developer_Package_v2.zip` يحتوي وثائق وصوراً فقط. لذلك **لم يُدَّع فحص أو نسخ نماذج من الحزمة غير المتاحة**؛ الأصول في هذا الإصدار أُنشئت من جديد اعتماداً على المراجع البصرية والكتالوج الكهربائي.

## مجسمات GLB الأصلية

توجد الآن **27 أصلاً مستقلاً، بثلاث درجات LOD لكل أصل (81 ملف GLB)**:

- `assets/models/board/<ComponentKind>.glb`: هندسة أخف للوحة والتصدير.
- `assets/models/preview/<ComponentKind>.glb`: بطاقات المكتبة الظاهرة.
- `assets/models/detailed/<ComponentKind>.glb`: العارض المفصل عند الطلب.
- `assets/models/manifest.json`: المسارات، الأبعاد، أعداد الرؤوس والمثلثات، الأحجام وSHA-256 لكل ملف.

الأنواع: Disjoncteur MCB/différentiel/moteur، Contacteur، Relais thermique/auxiliaire، Boutons NO/NC وArrêt d'urgence، Sélecteur وCommutateur، Voyant، Temporisateurs ON/OFF، Capteur وFin de course، Moteurs 3~/1~، Alimentations DC/1~/3~، Transformateur، Bornier، Fusible، Voltmètre، Ampèremètre وCompteur.

الهندسة تشمل، حسب العائلة، هياكل DIN متعددة الطبقات ومشابك، فتحات تهوية، براغي وفتحات أسلاك وقواعد عازلة، أقراص ضبط، شاشات وأزرار، زعانف وعمود وصندوق أطراف للمحرك، وقلباً وملفات نحاسية للمحول. التسميات التقنية geometry صغيرة فوق الأسطح، وليست screenshots تُستعمل بديلاً عن الجهاز.

هذه نماذج **أصلية brand-free مخصصة للتعلم**، وليست CAD photorealistic أو مطابقة لأبعاد وترتيب أطراف منتج تجاري محدد. لم تُستخدم نماذج أو شعارات مصنعين، ولا تحتاج الأصول إلى ترخيص نموذج خارجي. لا يُوصف مستواها بأنه «احترافي» قبل المعاينة على أجهزة فعلية.

## إعادة التوليد والمصدر المرجعي للأبعاد

المولّد محفوظ في `tool/generate_glb_assets.py` ويعمل بـPython القياسي فقط:

```bash
python3 tool/generate_glb_assets.py
```

يقرأ المولّد أبعاد الأجهزة وأطرافها من `ComponentCatalog`؛ لذلك لا توجد نسخة مستقلة يمكن أن تنحرف عن مواقع التوصيل. كبّرنا المثلثات العريضة فقط عند الحاجة لتقليل تقاطعات depth sorting في الشاشات والتسميات، من دون مضاعفة هندسة البراغي الصغيرة.

## التحميل داخل التطبيق

- `lib/src/three_d/glb_mesh_loader.dart` يفك GLB 2.0 الثنائي: JSON/BIN داخليان، VEC3 float positions، triangle indices وPBR base colors.
- `lib/src/three_d/asset_mesh_view.dart` يعرض الملف الفعلي ويظهر خطأ واضحاً إذا كان مفقوداً أو غير صالح؛ لا يستبدله بصورة أو مكعب ويخفي الخطأ.
- التخزين المؤقت حسب النوع وLOD ولون المصباح. لا تُفك كل النماذج المفصلة عند فتح التطبيق.
- اللوحة والمكتبة وthumbnails والعارض المفصل وPNG/PDF كلها تستهلك الأصول نفسها.
- الأطراف الكهربائية و`MeshTerminal` ونقاط الأسلاك وعقد MNA تبقى مشتقة من `ComponentCatalog`.

العارض software renderer بخامات وإضاءة وdepth sorting، وليس محرك PBR/OpenGL. decoder مخصص لهذه الأصول المضمّنة، وليس عارض glTF عاماً؛ لا يدعم textures أو external buffers أو skins أو animations.

## الأسلاك والصور المرجعية

الأسلاك مسارات ديناميكية من الطرفين وwaypoints وليست GLB ثابتاً. رسمها يتبع لونها ومقطعها ومسارها، والتأثير الضوئي لا يظهر إلا من تيار `SimulationResult` الفعلي.

- `designs/` صور مرجعية فقط ولا تدخل كبديل عن UI أو meshes.
- `assets/icon/app_icon.png` وأيقونات Android مشتقة من مرجع الأيقونة المرفق.
- `assets/fonts/Amiri-Regular.ttf` و`OFL.txt` من Google Fonts / Amiri برخصة SIL OFL لتضمين العربية في PDF.

## التحقق

`test/three_d/glb_asset_test.dart` يحمّل ويفك **كل ملفات GLB الـ81 من asset bundle** ويقارنها بالـmanifest والكتالوج والمثلثات والفهارس، ويتحقق من تغير خامة المصباح ورفض GLB غير صالح. `test/export/export_and_mesh_test.dart` يفحص LOD وتطابق الأطراف والهوية الهندسية وهامش القص والتدوير والتصدير. نتائج CI الفعلية، وليس مجرد وجود الاختبارات، توثق في `docs/FINAL_REPORT.md` بعد اكتمالها.
