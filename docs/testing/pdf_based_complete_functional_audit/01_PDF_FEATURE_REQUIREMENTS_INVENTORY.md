# PDF Feature Requirements Inventory

**Benchmark:** `AirDroid_Parental_Control_Complete_Feature_Guide_Hinglish.pdf` (seven pages, prepared 26 November 2026).  
**Method:** complete `pdftotext -layout` extraction of all seven pages; no device interaction and no runtime verification performed for this inventory.  
**Scope:** atomic functional requirements, dependencies, limitations, setup/privacy safeguards, and availability qualifications on PDF pages 2–7. Page 1 is context only.  
**Requirement count:** **104** (`PDF-R001`–`PDF-R104`).  
**Interpretation:** the PDF is a benchmark, not a HAVEN specification or proof of HAVEN support. “Listed” and “Product-listed” are PDF classifications only. No requirement is runtime-verified by this document.

## Reading and qualification rules

1. Every bullet, caveat, dependency, exclusion, and availability qualification that changes expected behavior is retained below. A test must not reduce a qualified PDF statement to an unconditional promise.
2. Requirements repeated in the page 7 availability snapshot retain the detailed page 2–6 qualifications. Page 7 adds the `Listed` / `Product-listed` classification and its condition.
3. “Where supported,” “may,” “can,” “depending on,” “verify live UI,” and plan/version/region/OS/app/sensor qualifications are part of the requirement, not optional commentary.
4. Android is the child-device scope. iOS parity, AirDroid Personal file transfer, and remote-device operation are outside this benchmark.
5. Source absence is not runtime proof; a source path, button, API record, acknowledgement, or service notification is not a runtime pass.
6. All planned test IDs refer to `03_COMPLETE_RUNTIME_TEST_CASES.md`. Every planned test starts `NOT TESTED`.

## Atomic PDF requirements

| ID | PDF page / section | Atomic requirement | Mandatory qualification / caveat retained | Verification implication / planned tests |
|---|---|---|---|---|
| PDF-R001 | p2 §1 Product structure | Parent-side app presents reports, rules, location, alerts/requests, and supported live-monitoring initiation. | AirDroid Parental Control is the benchmark product, not AirDroid Personal. | Parent shell and device-detail navigation; `DASH-01`. |
| PDF-R002 | p2 §1 | Child Android companion uses Android permissions/services for usage, notifications, location, and explicitly enabled monitoring. | Companion installation, update, online state, and required permissions affect availability. | Baseline identity, pairing, service and permission checks; `ENV-01`–`ENV-04`. |
| PDF-R003 | p2 §1 Binding | Parent obtains a binding code and Child enters/approves the binding relationship. | PDF states a maximum of 10 child devices per account according to AirDroid terms; actual limits must be verified from plan/product terms. HAVEN is not assumed to share that cap. | Inspect existing relationship only; do not pair again; `ENV-02`. Cap comparison in mapping only. |
| PDF-R004 | p2 §1 Scope | Use Android child-device feature coverage as the benchmark. | Android and iOS feature sets differ; iOS parity is not required. AirDroid Personal is excluded. | Platform applicability recorded in `ENV-01`. |
| PDF-R005 | p2 §2 Daily & Weekly Activity | Report daily and weekly per-app duration, usage pattern, and activity summary. | Report depth depends on OS, app, permission, and product version. | `USG-01`, `USG-02`. |
| PDF-R006 | p2 §2 | Report notification count and supported-app notification activity summary. | Supported apps only; not complete private-message or screen-action transcription. | `NTF-01`; mapping must not equate safety alerts with notification synchronization. |
| PDF-R007 | p2 §2 | Show per-app mobile-data usage as device statistics where supported. | “Where supported”; not a universal Android capability. | `USG-06`; absence must not be disguised by foreground-duration metrics. |
| PDF-R008 | p2 §2 | Show most-used apps and app list to explain usage patterns. | Report depth remains OS/app/permission/version dependent. | `USG-03`. |
| PDF-R009 | p2 §2 Reports caveat | Reports provide an overview, not a complete transcript of every app's private messages or every screen action. | OS, app, permission and product version determine depth. | Privacy/interpretation checks in `USG-01`, `NTF-03`, `PRV-07`. |
| PDF-R010 | p2 §3 App List | Parent can review the Child installed-app list. | Installed-app visibility depends on Child reporting and Android package visibility. | `APP-01`, `APP-02`. |
| PDF-R011 | p2 §3 App List | Parent can set app-wise limits or restrictions on selected apps/categories. | Actual enforcement must be distinguished from saved configuration. | `APP-03`, `POL-01`–`POL-08`; category support is not implied by package selection. |
| PDF-R012 | p2 §3 App List | Parent receives alerts for newly installed apps. | Feature is described as available in the benchmark; actual Android support must be verified. | `APP-13`. |
| PDF-R013 | p2 §3 App List | Supported Android builds can automatically block new apps. | Explicitly qualified by supported Android builds; not equivalent to blocking already installed packages. | `APP-14`; an install mutation requires prior authorization. |
| PDF-R014 | p2 §3 App List | Parent can block and unblock a selected app. | Actual Child/Android enforcement, not dashboard timer or save state, is decisive. | `APP-03`, `APP-04`, `POL-05`. |
| PDF-R015 | p2 §3 App List | Parent can review a Child restricted-app request. | Request and approval/refusal workflow must be end-to-end. | `APP-15`. |
| PDF-R016 | p2 §3 App Limits | Selected apps share one combined daily allowance; reaching the limit can block the group. | Shared selected-app accounting and group block are distinct from a device-wide quota. | `APP-05`. |
| PDF-R017 | p2 §3 App Limits | Each selected app can have its own time budget. | Per-app usage budget is distinct from per-app recurring schedule. | `APP-06`. |
| PDF-R018 | p2 §3 App Limits | Downtime/schedule restricts selected apps during fixed hours such as study time or bedtime. | Time windows and selected-app scope matter; overnight behavior must be explicit where implemented. | `APP-07`, `APP-08`, `POL-03`, `POL-04`. |
| PDF-R019 | p2 §3 App Limits | Parent-selected Always Allowed apps remain available during restrictions. | Parent chooses the allowed set; protected/system apps are a separate implementation concern. | `APP-09`, `POL-06`. |
| PDF-R020 | p2 §3 Instant Block | Parent can immediately restrict supported apps, usually excepting Always Allowed. | “Immediately” requires observed enforcement latency; supported-control qualification applies. | `APP-10`, `POL-02`. |
| PDF-R021 | p2 §3 Instant Block | Instant Block may offer fixed-period, until-midnight, or manual-off duration choices. | Exact choices depend on app version; do not invent an unavailable selector. | `APP-11`, `APP-12`. |
| PDF-R022 | p3 §3 Location-based downtime | A configured area plus active configured time window can restrict non-allowed apps. | PDF says an AirDroid support article lists this for Android AirDroid Kids; it is location-based downtime, not merely geofence alerting. | `APP-16`. |
| PDF-R023 | p3 §3 Enforcement caveat | Evaluate app limits through actual Child/Android enforcement, not a dashboard timer. | Battery kill, permission revocation, uninstall, offline state, or OEM restriction can interrupt enforcement. | `POL-01`, `POL-05`, `POL-07`, `BG-01`, `BG-07`. |
| PDF-R024 | p3 §4 Live Location | Parent views the Child latest/current reported location on a map. | “Reported” location requires freshness/accuracy evidence; HAVEN's presentation may be narrower. | `LOC-01`, `LOC-02`, `BG-02`. |
| PDF-R025 | p3 §4 Live Location | Refresh action can request a location update. | Result depends on GPS/network availability and device state; cached display is not fresh refresh proof. | `LOC-03`, `BG-02`. |
| PDF-R026 | p3 §4 Route History | Parent reviews past movement/location points in timeline or map format. | AirDroid support overview references past 30 days; retention/version/plan conditions may change it. | `LOC-04`–`LOC-06`; test actual HAVEN retention rather than assuming 30 days. |
| PDF-R027 | p3 §4 Geofence | Parent defines a named area and radius such as school/home. | Radius and area must be explicit; manual coordinates may be narrower than a map picker. | `LOC-07`. |
| PDF-R028 | p3 §4 Geofence | Parent can receive entry and exit alerts. | Alerts depend on location sampling and configuration; first-sample baseline is not an entry event. | `LOC-08`–`LOC-11`; safely preserve existing zones. |
| PDF-R029 | p3 §4 Geofence accuracy | Location/geofence behavior accounts for GPS, Wi-Fi, mobile network, indoor signal, battery saver, and background-location effects. | Accuracy is conditional, not a fixed guarantee. | `LOC-12`, `BG-06`. |
| PDF-R030 | p3 §4 Driving Detection | Driving-related trip details, route, speed/duration, speeding, hard braking, and rapid acceleration may be available. | Availability depends on region, app version, device sensors, and supported plan. | `LOC-13`. |
| PDF-R031 | p3 §5 Remote Camera | Parent can remotely request a supported Child Android camera view. | Supported camera and live-session requirements; not silent 24/7 access. | `CAM-01`–`CAM-07`, `BG-03`. |
| PDF-R032 | p3 §5 Remote Camera | Front/rear switching, rotate/full-screen controls, and rear flashlight may be supported. | Each control is qualified by product/device support; no universal control set is implied. | `CAM-05`, `CAM-06`. |
| PDF-R033 | p3 §5 Remote Camera | One-way microphone audio may also be available during a live camera session. | “May” and live-session qualification apply. | `CAM-07`; independently verify microphone media. |
| PDF-R034 | p3 §5 One-Way Audio | Parent hears live surrounding sound from the Child microphone. | Actual audio delivery, not request/signalling state, is required. | `AUD-01`–`AUD-06`, `BG-04`. |
| PDF-R035 | p3 §5 One-Way Audio | Benchmark support material describes recording and Parent-side recording management. | Recording behavior, consent, local law, and product settings must be verified. HAVEN must not be credited with recording absent an implementation. | `AUD-07`, `PRV-07`. |
| PDF-R036 | p3 §5 Screen Mirroring | Parent sees live Child screen content; supported modes may include one-way audio. | Screen content is distinct from camera video; audio is mode-dependent. | `MIR-01`–`MIR-03`, `BG-05`. |
| PDF-R037 | p4 opening caveat | Camera, screen mirroring, and one-way audio are on-demand live features, not 24/7 continuous recording/history. | Do not infer persistent surveillance or historical media. | `CAM-07`, `AUD-07`, `MIR-03`, `PRV-07`. |
| PDF-R038 | p4 opening caveat | Starting a live session requires a responsive/online Child, required permissions, and Android OS approval/availability. | Child interaction or OS consent may be required; do not bypass it. | `CAM-01`, `AUD-01`, `MIR-01`, `BG-03`–`BG-05`. |
| PDF-R039 | p4 opening caveat | Use live monitoring securely and transparently; do not assume hidden surveillance or consent bypass. | Child/OS consent and privacy indicators remain authoritative. | `CAM-04`, `AUD-04`, `MIR-02`, `PRV-07`. |
| PDF-R040 | p4 §6 Notification Sync | Supported incoming app notifications can appear on the Parent dashboard. | Supported apps only. | `NTF-01`. |
| PDF-R041 | p4 §6 Notification Sync | App-wise notification selection/mute controls may be available. | “May be available”; local Parent reminder settings are not Child notification-listener controls. | `NTF-02`. |
| PDF-R042 | p4 §6 Notification Sync | Notification previews/content may be available. | End-to-end encryption, hidden previews, app restrictions, or OS behavior can make content incomplete. | `NTF-03`. |
| PDF-R043 | p4 §6 Social Content Detection | Parent-defined keywords in incoming messages of selected supported social apps can generate alerts. | Supported apps only; notification/message access and permissions matter. | `SOC-01`. |
| PDF-R044 | p4 §6 Social Content Detection | Parent enables supported apps in App Detection Management and manages keywords. | Both configuration surfaces and end-to-end detection are required. | `SOC-02`. |
| PDF-R045 | p4 §6 Social Content Detection | Social detection is not universal chat reading. | Depends on supported apps, versions, language, notification/message access, and permissions. | `SOC-03`; preserve negative-coverage semantics. |
| PDF-R046 | p4 §6 Image Detection | When enabled, scan images saved in Child internal storage/Gallery for detection. | Feature enablement and internal saved images are the stated scope. | `IMG-01`. |
| PDF-R047 | p4 §6 Image Detection exclusions | Image scanning does not automatically cover every disappearing image, encrypted chat media, cloud-only image, or live camera feed. | These are explicit exclusions, not defects in the benchmark. | `IMG-02`. |
| PDF-R048 | p4 §6 Calls/SMS/Web Safe Search/AI Chat | Product pages advertise calls/SMS monitoring, call filtering, web safe search, and AI chat monitoring. | Exact apps, countries, Android versions, account/plan, and rollout vary; not universal every-app access; verify live UI and official compatibility. | `CALL-01`, `CALL-02`, `WEB-04`. |
| PDF-R049 | p4 §7 Website restrictions | Supported browsers/web access can use blacklist/whitelist controls. | Supported browsers/web access only. | `WEB-01`. |
| PDF-R050 | p4 §7 Browsing history | Review supported-browser activity/URLs and blocked attempts. | Supported browser coverage; not all in-app web content. | `WEB-02`. |
| PDF-R051 | p4 §7 Blocked-site alerts | Alert when Child attempts to open a restricted website. | Depends on supported filtering configuration. | `WEB-03`. |
| PDF-R052 | p4 §7 Website limits | Website/time controls are listed for some platforms/modes. | Android/iOS parity is not the same; verify platform/mode. | `WEB-04`. |
| PDF-R053 | p4 §7 Filtering caveat | Browser filtering coverage varies with browser, VPN/private DNS, alternate browsers, in-app webviews, encrypted DNS, and Android network configuration. | “Website filter” does not mean every app's content is filtered. | `WEB-05`. |
| PDF-R054 | p4 §8 Requests | Child can request extra time/access for a blocked app; Parent can approve or refuse. | Both request submission and Parent decision are required. | `APP-15`, `ALT-01`. |
| PDF-R055 | p4 §8 Alerts | Alerts can include geofence entry/exit, blocked-app attempts, newly installed apps, low battery, and device offline. | Supported configuration applies; each producer must be verified separately. | `ALT-02`–`ALT-08`, `LOC-08`–`LOC-11`. |
| PDF-R056 | p5 §8 continuation | Parent can receive status/notice for disabled required permission or needed app update. | Must be an actual generated notice, not only a status tile. | `ALT-09`, `ALT-10`. |
| PDF-R057 | p5 §8 Family tools | Family Chat, Child-triggered SOS, and Focus Mode are product-listed family tools. | Exact availability/version must be checked; product listing is not universal support. | `ALT-11`. |
| PDF-R058 | p5 §9 Background reliability | Child-side background service operation determines reliability. | Android battery management/OEM task managers can suspend/kill apps; no developer guarantee of permanently alive background process. | `BG-01`, `BG-06`, `BG-07`; OEM limitation is not automatically a defect. |
| PDF-R059 | p5 §9 Autostart / Auto-launch | Autostart can launch Child app after phone restart. | Device/OEM permission; audit cannot reboot without approval and cannot change settings. | `ENV-03`, `BG-07`. |
| PDF-R060 | p5 §9 Run in background | OEM app manager can exempt the app from background restriction. | OEM-specific setting; inspect only unless separately authorized. | `ENV-03`, `BG-01`. |
| PDF-R061 | p5 §9 Battery optimization | Unrestricted/Don't optimize can prevent aggressive battery-saver stopping. | No always-on guarantee; inspect current state only. | `ENV-03`, `BG-06`. |
| PDF-R062 | p5 §9 Power saving | Aggressive battery saver may need disabling or an app-specific exception. | Do not change device-wide security/power settings during this audit. | `ENV-03`, `BG-06`. |
| PDF-R063 | p5 §9 Background data | Unrestricted mobile/Wi-Fi background data and Data Saver restrictions affect cloud access. | Network/background-data state is a dependency, not a HAVEN setting assumed to exist. | `ENV-03`, `BG-01`, `BG-07`. |
| PDF-R064 | p5 §9 Wi-Fi always on during sleep | Some devices can keep Wi-Fi on during sleep. | Device-dependent; not universally available. | `ENV-03`, `BG-06`. |
| PDF-R065 | p5 §9 Recent-apps protection | Some OEMs support recent-app lock/cleanup allowlisting. | OEM-dependent task-killer protection. | `ENV-03`, `BG-07`. |
| PDF-R066 | p5 §9 Service & permissions | Child app remains updated and required permissions are not revoked. | App update/permission changes can alter behavior; do not update/revoke during audit. | `ENV-01`, `ENV-04`. |
| PDF-R067 | p5 §9 OEM naming | Follow device-specific keep-alive instructions. | Exact names vary across Samsung, Xiaomi/Redmi, Oppo, Vivo, Realme, OnePlus, Motorola and Android versions. | `ENV-03`; record actual OEM rather than assuming labels. |
| PDF-R068 | p5 §10 Permission table | Usage Access supports app duration and foreground app/activity statistics through UsageStats. | User grants in Settings; denial affects related feature. | `USG-01`, `ENV-04`. |
| PDF-R069 | p5 §10 Permission table | Accessibility Service can support some app/site restriction and UI-level enforcement/detection. | High privilege; transparent disclosure and narrow scope required. HAVEN use must not be assumed. | `ENV-04`, `POL-08`, `WEB-01`. |
| PDF-R070 | p5 §10 Permission table | Notification Access supports Child notification synchronization/detection. | Notification-listener access; previews depend on app settings. | `NTF-01`, `ENV-04`. |
| PDF-R071 | p5 §10 Permission table | Precise plus background/Allow-all-the-time location supports live location, route points, and geofence alerts. | Android version may require separate background grant/notification prompt. | `LOC-01`, `LOC-07`, `BG-02`, `BG-06`, `ENV-04`. |
| PDF-R072 | p5 §10 Permission table | Camera permission supports remote camera sessions. | Android privacy controls/indicators apply; device/OS can deny. | `CAM-01`, `CAM-04`, `ENV-04`. |
| PDF-R073 | p5 §10 Permission table | Microphone permission supports one-way/live ambient audio. | Session-based access; Android mic indicator and privacy toggle apply. | `AUD-01`, `AUD-04`, `CAM-07`, `ENV-04`. |
| PDF-R074 | p5 §10 Permission table | Screen capture/MediaProjection supports live screen mirroring. | Android system consent prompt/session token required; silent permanent capture cannot be assumed. | `MIR-01`, `MIR-02`, `BG-05`. |
| PDF-R075 | p5 §10 Permission table | Background execution/autostart supports responsive scheduled checks and sync. | OEM allowlist; not guaranteed always-on. | `BG-01`, `BG-06`, `BG-07`. |
| PDF-R076 | p5 §10 Permission table | Network/background data supports cloud sync, alerts, location updates, and live-session transport. | Internet and server connectivity required. | `BG-01`, `BG-07`, `CAM-03`, `AUD-03`. |
| PDF-R077 | p6 note after §10 | Treat the permission table as an explanatory model of normal Android permissions and documented AirDroid functions. | AirDroid's exact internal implementation is not public; table is not a reverse-engineered implementation claim. | `PRV-08`; do not infer a specific HAVEN implementation from the PDF table. |
| PDF-R078 | p6 §11 Limitations | Updates/live connection can stop due to power off, uninstall/force-stop, no internet, airplane mode, severe battery restriction, or OEM task killer. | These are expected limitations; audit must not create destructive states to test them. | `BG-07` uses only safe network interruption; other causes are context, `PRV-08`. |
| PDF-R079 | p6 §11 Limitations | Permission revocation can make related features fail or become partial. | Do not revoke permissions in this audit. | `ENV-04`, `PRV-08`. |
| PDF-R080 | p6 §11 Limitations | Background execution can change with Android version, manufacturer policy, battery, network, and app update. | Retest after changes; an OEM limitation alone is not a software defect. | `BG-06`, `BG-07`. |
| PDF-R081 | p6 §11 Limitations | Camera/mic/screen capture is constrained by OS privacy controls and foreground/session requirements. | Developers cannot legitimately bypass those controls. | `CAM-04`, `AUD-04`, `MIR-02`, `BG-03`–`BG-06`. |
| PDF-R082 | p6 §11 Limitations | GPS can be stale/inaccurate indoors, with low battery, weak signal, or location off. | Freshness and accuracy must be reported; stale data must not be called live. | `LOC-02`, `LOC-12`. |
| PDF-R083 | p6 §11 Limitations | Background tasks consume device resources; Android/OEM memory management may stop the app. | Permanent background survival is not guaranteed. | `BG-06`, `BG-07`, `PRV-08`. |
| PDF-R084 | p6 §12 Setup | Parent app is installed and account signed in. | Audit uses existing installed app/account only; no install/sign-in mutation. | `ENV-01`. |
| PDF-R085 | p6 §12 Setup | Child Android app is installed and paired using Parent binding code. | Existing pairing is preserved; no re-pairing or new account. | `ENV-02`. |
| PDF-R086 | p6 §12 Setup | Child/guardian is clearly told which monitoring functions are enabled and why. | Purpose and disclosure must be understandable. | `PRV-01`. |
| PDF-R087 | p6 §12 Setup | Setup wizard grants required permissions and provides feature-wise permission review. | Audit cannot grant missing permissions; review must expose actual state without guessing. | `ENV-04`, `PRV-02`. |
| PDF-R088 | p6 §12 Setup | Verify battery optimization, autostart, background run, Data Saver, and OEM cleanup settings. | Inspect only in this audit. | `ENV-03`. |
| PDF-R089 | p6 §12 Setup validation | Individually test usage update, notification sync, location refresh, geofence alert, downtime/app block, and live features. | Each feature is independent; one pass cannot substitute for another. | `USG-01`, `NTF-01`, `LOC-03`, `LOC-08`, `POL-05`, `CAM-02`, `AUD-02`, `MIR-01`. |
| PDF-R090 | p6 §12 Setup warnings | Parent dashboard shows missing-permission/update warnings and features are retested after OS/app updates. | Warning generation and update state are separate from permission tiles. | `ALT-09`, `ALT-10`, `ENV-01`. |
| PDF-R091 | p6 §13 Privacy | Parental controls require transparent notice, guardian authority, proportional monitoring, data minimization, and secure account access appropriate to age/law. | Legal/authority determination is outside runtime testing; verify observable safeguards only. | `PRV-01`, `PRV-07`. |
| PDF-R092 | p6 §13 Privacy | Use camera/mic/screen in emergency/safety context, clearly disclosed and lawful; avoid unnecessary recording/notification storage or sharing. | No covert use; evidence must be sanitized. | `PRV-07`, `CAM-04`, `AUD-04`, `MIR-02`. |
| PDF-R093 | p6 §13 Security | Parent account uses a strong unique password and available multi-factor security. | Do not expose or change credentials; verify UI/capability only. | `PRV-03`. |
| PDF-R094 | p6 §13 Child transparency | Child device maintains visible app identity and understandable monitoring notice. | Visible service/session state matters independently of Parent UI. | `PRV-01`, `BG-01`, `CAM-04`, `AUD-04`. |
| PDF-R095 | p6 §13 Live-session safeguards | Do not design continuous hidden surveillance; prefer clear session state, access logs, and stop controls. | On-demand sessions and end/stop behavior must be visible and effective. | `CAM-04`, `CAM-07`, `AUD-05`, `MIR-03`, `PRV-04`. |
| PDF-R096 | p6 §13 Product privacy | Verify retention/deletion, encryption, server region, subscription terms, and family-member access from product privacy policy. | Product-policy facts are not established by code presence; destructive deletion is prohibited. | `PRV-05`, `PRV-06`, `PRV-08`. |
| PDF-R097 | p7 §14 snapshot | App usage & reports: **Listed** for Android child device. | Condition: Usage Access plus device reporting. | `USG-01`–`USG-05`. |
| PDF-R098 | p7 §14 snapshot | App limits/downtime/instant block: **Listed**. | Enforcement depends on permissions/background state. | `APP-03`–`APP-12`, `POL-01`–`POL-08`. |
| PDF-R099 | p7 §14 snapshot | Live location/route/geofence: **Listed**. | Location permission plus network plus GPS. | `LOC-01`–`LOC-12`. |
| PDF-R100 | p7 §14 snapshot | Remote camera/one-way audio: **Listed**. | Android Child only; live session and permissions. | `CAM-01`–`CAM-07`, `AUD-01`–`AUD-07`. |
| PDF-R101 | p7 §14 snapshot | Screen mirroring: **Listed**. | Android Child only; OS screen-capture consent/session. | `MIR-01`–`MIR-03`, `BG-05`. |
| PDF-R102 | p7 §14 snapshot | Notifications/social keyword detection: **Listed**. | Supported apps and notification/access configuration. | `NTF-01`–`NTF-04`, `SOC-01`–`SOC-03`. |
| PDF-R103 | p7 §14 snapshot | Image detection/calls-SMS/web filtering: **Product-listed**. | Exact coverage varies by OS, version, region, and plan; not all product-listed capabilities are mandatory HAVEN scope. | `IMG-01`, `IMG-02`, `CALL-01`, `CALL-02`, `WEB-01`–`WEB-05`. |
| PDF-R104 | p7 §15 References / accuracy | Verify live app and official support before implementation/purchase decisions; features, names, platform support, subscription tiers, and Android permissions can change. | Guide summarizes official public material checked for this edition; references include overview, user guide, setup, background help, product/compatibility, and terms. | `PRV-08`; all test results must identify app/OS/version/time. |

## Official benchmark references retained from page 7

- [AirDroid Parental Control official overview](https://help.airdroid.com/hc/en-us/articles/4677178239131-AirDroid-Parental-Control-Overview) (PDF says updated 8 June 2026).
- [AirDroid Parental Control official user guide](https://www.airdroid.com/guide/parental-control/).
- [What is AirDroid Parental Control and how to start using?](https://help.airdroid.com/hc/en-us/articles/4507395498779-What-is-AirDroid-Parental-Control-and-how-to-start-using).
- [How to keep AirDroid Kids running in the background on Android devices](https://help.airdroid.com/hc/en-us/articles/4406503673627-How-to-keep-AirDroid-Kids-running-in-the-background-on-Android-devices).
- [AirDroid Parental Control product page / compatibility](https://www.airdroid.com/parental-control/).
- [AirDroid Terms of Service](https://webparent.airdroid.com/terms.html).

## Coverage accounting

- Requirements by PDF page: p2 = **21**, p3 = **15**, p4 = **21**, p5 = **19**, p6 = **20**, p7 = **8**; total **104**.
- Availability snapshot: **6 Listed groups** and **1 Product-listed group**, plus **1 accuracy/reference requirement**.
- Runtime status: **all 104 requirements remain unverified** until their mapped test evidence is executed and reviewed.
- Source mapping is supplementary and is provided separately in `02_HAVEN_FEATURE_TO_PDF_MAPPING.md`.
