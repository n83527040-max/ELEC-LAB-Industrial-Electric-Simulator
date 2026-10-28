# ELEC LAB — 3D Component Starter Asset Pack

This pack contains 30 separate GLB component models, a component catalogue, starter terminal-point metadata, and integration guidance for the ELEC LAB Flutter application.

## Important quality note
These are original procedural 3D starter models made from meshes and PBR-style materials. They are more structured than flat icons, but they are **not manufacturer-certified CAD models or photorealistic replicas**. Terminal coordinates are starter metadata and must be calibrated against each model before being used for electrical calculations. Do not present the pack as validated industrial CAD.

## Contents
- `models/*.glb`: individual 3D meshes suitable for glTF-compatible viewers.
- `metadata/components.json`: names, categories, descriptions and starter terminal coordinates.
- `docs/BOARD_AND_INTEGRATION_SPEC.md`: fixed board and Flutter integration requirements.
- `docs/AGENT_PROMPT_AR.txt`: Arabic instructions to integrate the assets and fix the board.

## Suggested Flutter integration
1. Copy `models/` into `assets/models/` and `metadata/components.json` into the app assets.
2. Register asset paths in `pubspec.yaml`.
3. Use a glTF/GLB-capable renderer for the detailed 3D preview. For the 2D workspace, use lightweight thumbnails or a carefully controlled embedded 3D viewport.
4. Keep the canvas coordinate system independent from screen pixels. Transform model positions through the camera/viewport scale.
5. Store component id, position, rotation, scale, terminal definitions, wires and layer id in project JSON.
6. Calibrate terminal coordinates per model and verify each terminal by tapping it in the app.
7. Keep power source rails fixed in a dedicated header/side region of the workspace, not as freely movable components.

## Models
- `mcb.glb` — Disjoncteur MCB / قاطع كهربائي MCB
- `rcd.glb` — Disjoncteur différentiel / قاطع تفاضلي
- `motor_breaker.glb` — Disjoncteur moteur / قاطع حماية المحرك
- `contactor.glb` — Contacteur 3P + Aux / كونتاكتور ثلاثي الطور
- `thermal_relay.glb` — Relais thermique / مرحل حراري
- `aux_relay.glb` — Relais auxiliaire / ريليه مساعد
- `motor_3ph.glb` — Moteur triphasé / محرك ثلاثي الطور
- `motor_1ph.glb` — Moteur monophasé / محرك أحادي الطور
- `pushbutton_green.glb` — Bouton poussoir NO / زر تشغيل أخضر NO
- `pushbutton_red.glb` — Bouton poussoir NC / زر توقف أحمر NC
- `emergency_stop.glb` — Arrêt d’urgence / زر توقف اضطراري
- `selector.glb` — Sélecteur / مفتاح اختيار
- `pilot_red.glb` — Voyant rouge / مصباح إشارة أحمر
- `pilot_green.glb` — Voyant vert / مصباح إشارة أخضر
- `pilot_amber.glb` — Voyant orange / مصباح إشارة برتقالي
- `timer_on.glb` — Temporisateur ON-delay / مؤقت زمني ON-delay
- `timer_off.glb` — Temporisateur OFF-delay / مؤقت زمني OFF-delay
- `psu_single.glb` — Alimentation monophasée / مصدر تغذية أحادي الطور
- `psu_three.glb` — Alimentation triphasée / مصدر تغذية ثلاثي الطور
- `psu_dc.glb` — Alimentation DC / مصدر تغذية DC
- `terminal_block.glb` — Bornier / كتلة توصيل
- `fuse_holder.glb` — Porte-fusible / حامل فيوز
- `transformer.glb` — Transformateur / محول كهربائي
- `current_transformer.glb` — Transformateur de courant / محول تيار
- `limit_switch.glb` — Fin de course / مفتاح نهاية مشوار
- `sensor.glb` — Capteur de proximité / حساس اقتراب
- `voltmeter.glb` — Voltmètre / فولتميتر
- `ammeter.glb` — Ampèremètre / أمبيرمتر
- `digital_meter.glb` — Compteur numérique / عداد رقمي
- `wire_bundle.glb` — Câbles électriques / أسلاك كهربائية
