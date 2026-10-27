# الأصول ثلاثية الأبعاد والبصرية

## المجسمات

المجسمات **parametric polygon meshes أصلية** مولّدة محلياً:

- `lib/src/three_d/mesh_model.dart`: الرؤوس والأوجه وboxes وchamfered enclosures وcylinders/frusta وspheres.
- `lib/src/three_d/procedural_meshes.dart`: هندسة مميزة لكل جهاز و`board/preview/detailed` LOD مع lazy cache.
- `lib/src/three_d/mesh_view.dart`: تدوير X/Y، منظور، depth sorting وإضاءة وظلال وauto-fit بعد المنظور.

هي هندسة 3D حقيقية وليست صوراً مسطحة. يمكن تدويرها بالسحب وتكبيرها بإصبعين في بطاقة التفاصيل. اللوحة تستعمل LOD خفيفاً بنفس هندسة الجهاز، والمكتبة تنشئ previews للبطاقات الظاهرة فقط.

مواقع `MeshTerminal` مشتقة برمجياً من `ComponentCatalog` نفسه الذي يغذي أطراف اللوحة وعقد MNA. على اللوحة تستعمل وحدة ثابتة `48 × scale` بلا منظور حتى تتطابق أجهزة العرض ومناطق اللمس ونقاط الأسلاك. التفاصيل في [`UI_WORKSPACE.md`](UI_WORKSPACE.md).

المجسمات الـ27 تعليمية مخصصة وليست CAD photorealistic ولا تمثل أبعاد مصنع أو ترتيب أطراف منتج تجاري محدد. لم تُستخدم أسماء أو شعارات مصنعين. المحول والحمايات والمحرك الأحادي والعداد والأنواع الأخرى لها هندسة مستقلة ونموذج كهربائي مرتبط، وليست الاسم أو اللون وحدهما.

## الأيقونة والصور المرجعية

- `designs/` هي الصور التي وفّرها المستخدم كمراجع بصرية.
- `assets/icon/app_icon.png` وأيقونات Android مشتقة من `designs/02_app_icon_reference.png` المرفقة في الحزمة.
- لا تُستخدم صور `designs/` داخل لوحة العمل أو كبديل عن UI أو meshes.

## الخط

`assets/fonts/Amiri-Regular.ttf` و`OFL.txt` من مشروع Google Fonts / Amiri، رخصة SIL Open Font License. يُضمّن الخط في PDF للنص العربي. رخصة الخط محفوظة بجانبه.

كل هندسة meshes البرمجية أُنشئت ضمن هذا المشروع ولا تتطلب تنزيل أصول أو اتصال بالإنترنت.
