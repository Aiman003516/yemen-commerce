# تدقيق مركز المزامنة وتسعير B2B وعمليات POS

## نطاق التدقيق

أُجري هذا التدقيق على فرع `migration/flutter-supabase-foundation` بعد إضافة replay مشفّر واعٍ بالاتصال، وجدولة محلية best-effort، وتحليلات وتصدير لتشغيل B2B وPOS. يظل Supabase هو المصدر authoritative، بينما يظل التنفيذ المالي خارج صندوق الأوامر: لا تُحفظ إثباتات الدفع، ولا تسوية الأموال، ولا تأكيد الدفع، ولا تحويل الأموال داخل replay المحلي.

تستخدم جدولة الهاتف عزل Dart في الخلفية، وهو النموذج الذي توضحه وثائق Flutter، مع WorkManager للمهام المستمرة عبر إعادة تشغيل التطبيق وإعادة تشغيل النظام [1] [3]. أما `connectivity_plus` فيُستخدم كإشارة لتحفيز محاولة، وليس كدليل على أن الإنترنت قابل للاستخدام؛ فتوثيقه يحذر من أن نوع الشبكة لا يضمن الوصول الفعلي أو اجتياز captive portal [2].

## القرارات المنفذة

| المجال | التنفيذ | الحد الأمني أو التشغيلي |
|---|---|---|
| نطاق صندوق الأوامر | مفتاح Secure Storage مستقل لكل `auth.uid`، مع ترميز محلي للنطاق | لا يمكن لحساب لاحق على الجهاز قراءة أو replay طابور الحساب السابق؛ الطابور القديم غير المعرّف لا يُنقل تلقائياً |
| قائمة replay | `checkout_create_orders` و`apply_order_promotion` فقط | لا توجد payment proof أو payment finalization أو fund movement ضمن allowlist |
| التزامن | قفل process-wide keyed by `userScope` داخل `OutboxReplayWorker`، مع تسلسل عمليات Secure Storage للنطاق نفسه | يمنع تداخل lifecycle وmanual sync داخل حساب واحد؛ وتغطي idempotency في RPC سباقات OS/foreground المنفصلة |
| الفشل | حد أقصى خمس محاولات، ثم blocked مع retry/discard يدوي | لا توجد إعادة لا نهائية أو إعادة مالية تلقائية |
| الاتصال | listener في foreground + WorkManager periodic/one-off بقيود network connected | إشارة الشبكة لا تعني reachability؛ RPC والمهلات يقرران النجاح |
| Web | session/auth events وmanual sync وnetwork behavior المعتاد | لا يوجد OS job أصلي في متصفح عادي؛ لا يُدّعى replay بعد إغلاق المتصفح |
| iOS/Android | إعداد WorkManager وInfo.plist للجدولة الخلفية | النظام يقرر التوقيت؛ iOS قد يؤجل أو يخنق أو ينهي المهمة، ولا يوجد ضمان لحظة عودة الاتصال |

## تدقيق أمني

### مركز المزامنة

أصبح إنشاء `SecureCommandOutbox` يتطلب `userScope` غير فارغ. جميع نقاط الاستخدام الحالية تمرر هوية الجلسة، والـ background callback يهيئ Supabase ثم يتوقف بنجاح دون قراءة الطابور إذا لم توجد جلسة مصادق عليها. لا يتم ترحيل المفتاح القديم المشترك؛ وهذا مقصود لأن نسبته إلى مستخدم بعينه غير آمنة.

يعمل replay على أوامر غير مالية محددة بالاسم. مسار checkout يستدعي RPC idempotent، ولا يحاول تقديم إثبات دفع أو اعتماد الدفع. أخطاء الطابور تُخزن بحد أقصى 240 حرفاً في طبقة worker، بينما يعرض مركز المزامنة إسقاطاً تشخيصياً لا يحتوي على payload، ويخفي المفتاح الكامل ويعرض منه بداية ونهاية محدودتين فقط. لا يعرض مركز المزامنة payload أو بيانات الدفع أو المستندات الخاصة. عند تبديل المستخدم أو المتجر تُبطل Future والحالة القديمة، وتظهر نافذة تأكيد قبل حذف أمر مشفر.

تمت إضافة قفل replay process-wide keyed by user scope لمنع السباق بين إعادة تلقائية أثناء auth rebuild أو استئناف التطبيق، وإعادة يدوية من Sync Center، ومهمة OS ضمن الحساب نفسه. كما أصبحت كل عمليات Secure Storage لنفس نطاق المستخدم متسلسلة، بما فيها enqueue وpending وretry وdiscard وmarkFailed وmarkCompleted، حتى لا تفقد عملية متزامنة تحديثاً آخر. ويظل القفل حماية محلية فقط؛ الحماية الأساسية ضد checkout المكرر موجودة في مفتاح idempotency وRPC الخادمي. لا يزال `retry` و`discard` قرارين صريحين للمستخدم، مع نافذة تأكيد قبل الحذف، ولا تتم إعادة blocked تلقائياً.

### تسعير B2B والمراجعة

يتحقق RPC الحالي من ملكية المتجر عبر merchant ids أو صلاحية الإدارة قبل إنشاء أو تحديث قائمة الأسعار. كما يتحقق من أن المنتج يتبع المتجر وأن variant يتبع المنتج، وأن كل تغيير يتطلب سبباً غير فارغ ويسجل audit event. مراجعة طلب B2B لا تطبق قائمة أسعار إلا إذا كانت القائمة active ومقيدة بالمتجر نفسه. لا يوجد في هذا increment تطبيق تلقائي لسعر تفاوضي على checkout، ولا تحويل ائتمان B2B إلى تمويل.

يوجد قيد معروف في واجهة الطلبات القديمة: فهي تعرض للتاجر بيانات تشغيلية لازمة للمراجعة مثل اسم النشاط ورقم التواصل والملاحظة. هذه البيانات لا تدخل في analytics/export الجديد؛ التصدير يعيد معرف الطلب، الحالة، العملة، القيمة التقديرية، ومؤشرات زمنية/قائمة أسعار فقط. ينبغي إبقاء الوصول إلى شاشة المراجعة داخل merchant ownership وعدم تحويل بيانات الاتصال إلى ملفات عامة.

### تحليلات وتصدير POS/B2B

أضيفت migrations `20260826_0024_b2b_pos_analytics_export.sql` و`20260826_0026_export_pagination_guard.sql`. الدوال العامة الأربعة هي `merchant_b2b_analytics` و`export_merchant_b2b` و`merchant_pos_analytics` و`export_merchant_pos`. كل تنفيذ يمر عبر private security-definer ثابت `search_path` مع public security-invoker wrapper ضيق، ويتحقق من auth وملكية المتجر أو صلاحية الإدارة. يرفض backend الآن offset سالباً أو أكبر من 10,000 بدلاً من تصحيح الطلب بصمت، ويتطابق معه guard في Dart.

أضيفت migrations `20260826_0027_promotion_command_idempotency.sql` و`20260826_0028_order_command_keys_deny_policy.sql`. أصبح replay الخاص بتطبيق العرض يرسل command key إلى جدول خادمي فريد ويعيد النتيجة السابقة عند التكرار، ما يحمي من سباق foreground/OS isolates؛ كما أن جدول المفاتيح الداخلي لا يملك client grants وله deny-all RLS policy صريحة.

يُسجل كل تصدير في `audit_events` مع النطاق والحد وعلامة صريحة بأن بيانات الهوية أو بنود line items غير موجودة. يفرض B2B حد 500 صفاً لكل صفحة، ويفرض POS حداً أقصى للنطاق مقداره 366 يوماً وحداً أقصى 500 صف. CSV يُنشأ محلياً من الصفوف المسموح بها ويستخدم quoting/escaping وUTF-8 BOM، ولا يطلب أو يعرض إثباتات دفع أو أرقام هواتف أو ملاحظات العملاء أو line items.

## تدقيق الأداء

تمت إضافة فهارس `wholesale_requests_shop_created_idx` و`pos_sales_shop_created_idx` لتغطي نمطي shop/date المستخدمين في التصدير. بطاقات التحليلات تحفظ Future في state وتعيد التحميل فقط عند refresh، بدلاً من إنشاء طلب جديد مع كل build. كما تُبطل بطاقات B2B وPOS ومركز المزامنة حالتها عند تغير المتجر أو المستخدم، فلا تبقى بيانات نطاق سابق ظاهرة بعد تبديل الجلسة. export محدود إلى 500 صف، ما يمنع بناء ملف غير محدود داخل ذاكرة التطبيق.

تستخدم تحليلات POS نطاقاً افتراضياً لآخر 30 يوماً، وتمنع النطاق الأكبر من 366 يوماً. لا تُقرأ صفوف line items في دالة التصدير، وتُعاد أعمدة session summary الضرورية فقط. تحليلات B2B تُرجع aggregates بلا join إلى business profile في الاستجابة. ما زال من المناسب لاحقاً إضافة cursor-based pagination إذا تطلبت التجارة اليمنية ملفات أكبر من 500 صف.

أُجريت مراجعة كاملة لنتيجة Performance Advisor: كانت تحتوي على 63 ملاحظة `unindexed_foreign_keys` و8 ملاحظات `multiple_permissive_policies` و64 ملاحظة `unused_index`. عالجت migration `20260826_0025_performance_advisor_remediation.sql` أول مجموعتين بإضافة 63 فهرساً مستهدفاً وتحويل سياسات القراءة إلى سياسة واحدة لكل role/action مع الحفاظ على اتحاد public/owner/admin السابق. بعد التطبيق اختفت ملاحظات المفاتيح غير المفهرسة والسياسات permissive بالكامل. بعد إضافة فهرس جدول command keys أصبح المتبقي 128 ملاحظة `unused_index` معلوماتية، منها الفهارس الجديدة التي لم تستخدمها حركة إنتاجية بعد؛ لا تُحذف قبل قياس query plans وحركة حقيقية. أما فحص Security Advisor بعد migrations 0027 و0028 فأعاد `lints: []`.

## منصة التنفيذ وحدود الضمان

| المنصة | السلوك الفعلي | ما لا نعد به |
|---|---|---|
| Android | WorkManager periodic task بحد أدنى عملي 15 دقيقة، one-off constrained task عند ظهور اتصال في foreground، وreplay في isolate | لا نعد بتنفيذ لحظي بعد قتل التطبيق أو أثناء قيود البطارية |
| iOS | WorkManager/BGAppRefresh مع identifiers وbackground modes في Info.plist | لا نعد بتوقيت ثابت؛ iOS يختار launch window وقد يؤجل أو يخنق المهمة |
| Web | foreground connectivity/session/manual behavior | لا يوجد OS-level background job بعد إغلاق المتصفح في الإصدار الحالي |

يؤكد توثيق WorkManager أن iOS لا يضمن وقت أو تكرار المهمة وقد ينهيها أو يخنقها إذا تجاوزت الميزانية، كما يذكر أن Android يفرض حد 15 دقيقة على المهام الدورية [1]. ويشرح توثيق Flutter أن callback الخلفية يعمل في isolate منفصل [3]. لذلك يعامل التنفيذ مهمة replay قصيرة، idempotent، ومحدودة الفشل، ويترك القرار النهائي للـ RPC وسياق الجلسة.

## الاختبارات والنتائج

| الاختبار | النتيجة |
|---|---|
| تطبيق migrations 0024–0028 على Supabase ref `mtaujfgkqvzwauqiegkl` | نجح |
| Security Advisor بعد migrations 0027/0028 | `0` lint |
| Performance Advisor بعد migration 0028 | `0` unindexed-FK، `0` multiple-permissive-policy، و128 unused-index معلوماتية |
| structural check للدوال العامة الأربع | الدوال الأربع موجودة وتعيد `jsonb` |
| structural check للفهرسين الجديدين | الفهرسان موجودان |
| anonymous protected-RPC runner | `61 passed / 5 skipped` بعد إضافة endpoints الجديدة |
| Flutter customer analyze | نجح بلا issues |
| اختبار الأدوار المصادق عليها | ما زال يحتاج tokens معزولة؛ لا تُنشأ حسابات اختبار في المشروع المشترك |
| Android build فعلي | لم يُشغّل دون Android SDK/device validation |
| iOS archive/device validation | غير متاح على بيئة Linux؛ يحتاج macOS/Xcode |

## الإجراءات اللاحقة الموصى بها

قبل الإنتاج، يجب تشغيل اختبارات RLS مستخدماً tokens معزولة من بيئة اختبار، واختبار session switch على جهاز حقيقي للتأكد من عدم ظهور أي طابور لحساب سابق. كما ينبغي اختبار battery saver وoffline/captive portal وانتهاء الجلسة أثناء replay على Android وiOS. يجب قياس خطط الاستعلام وحركة الفهارس بعد استخدام فعلي، ثم الاحتفاظ أو حذف unused indexes بناءً على دليل؛ لا تُزال الفهارس الجديدة لمجرد أنها لم تُستخدم في بيئة منخفضة البيانات.

## المراجع

[1]: https://pub.dev/packages/workmanager "Workmanager package documentation"
[2]: https://pub.dev/packages/connectivity_plus "connectivity_plus package documentation"
[3]: https://docs.flutter.dev/packages-and-plugins/background-processes "Flutter background processes documentation"
