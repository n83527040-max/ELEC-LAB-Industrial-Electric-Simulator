# الأصول ثلاثية الأبعاد والبصرية

## المجسمات

المجسمات في هذا الإصدار **parametric polygon meshes أصلية** مولّدة في:

- `lib/src/three_d/mesh_model.dart`: الرؤوس، الأوجه، boxes/cylinders ومواقع الأطراف.
- `lib/src/three_d/procedural_meshes.dart`: هندسة كل نوع جهاز.
- `lib/src/three_d/mesh_view.dart`: تدوير X/Y، منظور، depth sorting وإضاءة flat shading.

هي هندسة 3D حقيقية وليست صوراً مسطحة أو screenshots. يمكن تدويرها بالسحب وتكبيرها بإصبعين في بطاقة التفاصيل. نسخة مبسطة منها تُرسم على اللوحة.

مواقع `MeshTerminal` مشتقة برمجياً من `ComponentCatalog` نفسه الذي يغذي أطراف اللوحة وعقد MNA. لذلك لا يوجد ملف محطات منفصل يمكن أن يتعارض مع المحاكاة.

المجسمات تعليمية مبسطة وليست CAD photorealistic ولا تمثل أبعاد مصنع أو ترتيب أطراف منتج تجاري محدد. لم تُستخدم أسماء أو شعارات مصنعين.

## الأيقونة والصور المرجعية

- `designs/` هي الصور التي وفّرها المستخدم كمراجع بصرية.
- `assets/icon/app_icon.png` وأيقونات Android مشتقة من `designs/02_app_icon_reference.png` المرفقة في الحزمة.
- لا تُستخدم صور `designs/` داخل لوحة العمل أو كبديل عن UI أو meshes.

## الخط

`assets/fonts/Amiri-Regular.ttf` و`OFL.txt` من مشروع Google Fonts / Amiri، رخصة SIL Open Font License. يُضمّن الخط في PDF للنص العربي. رخصة الخط محفوظة بجانبه.

كل هندسة meshes البرمجية أُنشئت ضمن هذا المشروع ولا تتطلب تنزيل أصول أو اتصال بالإنترنت.
