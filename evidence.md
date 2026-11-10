Device/OS:  Pixel 9a Android 16.0 API 36.1   Permission status: Authorized
T4 change:  asset=unknown

Test | Expected handler/result | Observed result | Pass/fail/blocked | Evidence
T1   | onMessage + UI update   | receipt count increased, title and image changed| pass|T1 screenshot in word file
T2   | onMessageOpenedApp + UI | clicking the notification opens the app; onMessageOpenedApp appears on screen; receipt count increases by 1, title and image change|pass| T2 screenshot in word file
T3   | getInitialMessage + UI  | clicking the notification opens the app; getInitialMessage appears on screen; receipt count set to 1, title and image change|pass| T3 screenshot in word file
T4   | onMessage + rejection   | Receipt count increases by 1, onMessage handler appears but no changes to title or image, rejected payload message also appears. No app crash|pass| T4 screenshot in word file