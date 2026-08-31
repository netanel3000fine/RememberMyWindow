// this file is in charge of the localization of the app which mean that this is the file where all the translation from English to Hebrew and from Hebrew to English which is cool!
import Foundation
import SwiftUI

// MARK: - Localization helper
// Bi-directional localization helper. 
// Takes the language explicitly to ensure SwiftUI re-renders when it changes.

extension String {
    func localized(_ lang: AppLanguage) -> String {
        let isHebrew: Bool
        switch lang {
        case .hebrew:  isHebrew = true
        case .english: isHebrew = false
        case .auto:    isHebrew = Locale.current.language.languageCode?.identifier == "he"
        }
        
        if isHebrew {
            return translationDict[self] ?? self
        } else {
            return reverseDict[self] ?? self
        }
    }
}

// Global helper that reads from UserDefaults (for non-View contexts)
func lz(_ key: String) -> String {
    let langStr = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    let lang = AppLanguage(rawValue: langStr) ?? .auto
    return key.localized(lang)
}

/// Always returns the English/Stable version of a name, used for generating stable keys.
func normalizeToEnglish(_ name: String) -> String {
    // If it's a Hebrew name in our reverse dict, map it back to English.
    // Also handle prefixes like 'צג Retina מובנה'.
    let target = name
    if target.contains("מובנה") {
        return "Built-in Retina Display"
    }
    return reverseDict[target] ?? target
}

private let translationDict: [String: String] = [
    // Onboarding — slide headlines & bodies (casual tone)
    "Your window manager": "מנהל החלונות שלך",
    "Choose Your Language": "בחר שפה",
    "System Default": "ברירת מחדל של המערכת",
    "Follow System Language": "לפי שפת המערכת",
    "English": "English",
    "Hebrew": "עברית",
    "Continue": "המשך",
    "Next": "הבא",
    "Get Started": "בואו נתחיל",
    // Slide 0
    "Your Windows, Always Where You Left Them": "החלונות שלך, תמיד במקום שהשארת אותם",
    "Save your layout once. It'll be there every time you need it.": "שמור את הסידור פעם אחת. הוא יהיה שם בכל פעם שתזדקק לו.",
    // Slide 1
    "See Everything at Once": "ראה הכל בבת אחת",
    "A live minimap shows every open window across all your screens — no guessing.": "מפה חיה מוקטנת מציגה כל חלון פתוח על פני כל המסכים שלך — בלי ניחושים.",
    // Slide 2
    "Plug In, Pick Up Where You Left Off": "חבר ותמשיך מהיכן שהפסקת",
    "Reconnect a monitor or launch an app and your windows go right back where they belong.": "חבר מסך או פתח יישום והחלונות חוזרים בדיוק למקומם.",
    // Slide 3 — Menu Bar
    "Two Clicks, Two Powers": "שתי לחיצות, שתי יכולות",
    "Left click: restore the current app and open the window list. Right click: restore every app in one shot.": "לחיצה שמאלית: שחזר את היישום הנוכחי ופתח את הרשימה. לחיצה ימנית: שחזר את כל היישומים בבת אחת.",
    // Slide 4 — desktop toggle
    "Hide Everything, Instantly": "הסתר הכל, מיד",
    "Press %@ and every window vanishes — desktop is clean. Press again and they all come back exactly where they were.": "לחץ %@ וכל החלונות נעלמים — שולחן עבודה נקי. לחץ שוב והם חוזרים בדיוק למקומם.",
    // Slide 5 — Cmd+Shift+R
    "Do More After Every Restore": "עשה יותר אחרי כל שחזור",
    "After restoring windows, RememberMyWindows can fire ⌘⇧R in your active app — Reading Mode in Safari, Hard Reload in Chrome, or PiP for a video.": "לאחר שחזור החלונות, RememberMyWindows יכול לשלוח ⌘⇧R ליישום הפעיל שלך — מצב קריאה בספארי, רענון מלא בכרום, או PiP לסרטון.",
    // Slide 6 — Settings
    "Fine-Tune How It Works": "כוונן את האופן שבו זה עובד",
    "Tweak auto-restore, the desktop toggle, notch alerts, and more — all in Settings.": "שנה שחזור אוטומטי, הסתרת חלונות, התראות מגרעת ועוד — הכל בהגדרות.",
    // Slide 7 — Customise
    "Make It Feel Like Home": "גרום לזה להרגיש כמו בית",
    "Pick your accent colour and language in Settings. Small details, big difference.": "בחר את צבע ההדגשה והשפה בהגדרות. פרטים קטנים, שינוי גדול.",
    // Legacy slide strings kept for backward compatibility
    "Remember Every Window": "זכור כל חלון",
    "Save your window layout with one click and restore it in seconds.": "שמור את סידור החלונות שלך בלחיצה אחת ושחזר אותו תוך שניות.",
    "Live Layout Preview": "תצוגה מקדימה חיה",
    "See a real-time minimap of every open window across all your screens.": "ראה מפה חיה של כל חלון פתוח על פני כל המסכים שלך.",
    "Automatic Restoration": "שחזור אוטומטי",
    "Reconnect a monitor or open an app — your layout snaps back instantly.": "חבר מסך או פתח יישום — הסידור חוזר מיידית.",
    "Make It Yours": "התאם אישית",
    "Choose a theme colour and language — all in Settings.": "בחר צבע ערכת נושא ושפה — הכל בהגדרות.",
    // Menu Bar callouts (updated wording)
    "Restores this app\n& opens the list": "משחזר יישום זה\nופותח את הרשימה",
    "Restores all apps\nat once": "משחזר את כל היישומים\nבבת אחת",
    // Cmd+Shift+R badge labels & scene titles
    "Reading Mode": "מצב קריאה",
    "Reader": "קריאה",
    "Hard Reload": "רענון מלא",
    "Reload": "רענון",
    "Picture-in-Picture": "תמונה בתוך תמונה",
    "PiP": "תמונה בתוך תמונה",
    // Misc onboarding
    "Saved": "נשמר",
    "Restored": "שוחזר",
    "Settings": "הגדרות",
    "Toggle Sidebar": "הצג/הסתר סרגל צדדי",
    "Skip for now": "דלג לעת עתה",
    "Categories": "קטגוריות",
    "Select a category to customize settings": "בחר קטגוריה כדי להתאים אישית הגדרות",
    "Appearance & General": "מראה וכללי",
    "Appearance & Notifications": "מראה והתראות",
    "Theme, Liquid Glass, Notch & Notifications": "ערכת נושא, Liquid Glass, מגרעת והתראות",
    "Notification Sound": "צליל התראה",
    "Play a subtle sound when layout restore alerts or notifications appear": "השמע צליל עדין בעת הופעת התראות שחזור סידור או הודעות",
    "Default Sound": "צליל ברירת מחדל",
    "Default notification alert sound when not overridden": "צליל התראה ברירת מחדל כאשר לא הוגדר צליל ייעודי",
    "Select Sound": "בחר צליל",
    "Sound": "צליל",
    "Sound on for this event": "השמעת צליל מופעלת לאירוע זה",
    "Sound off for this event": "השמעת צליל מושתקת לאירוע זה",
    "Preview sound": "השמעת דוגמה",
    // Encore Tones
    "Welcome": "Welcome (ברוכים הבאים)",
    "Droplet": "Droplet (טיפה)",
    "Milestone": "Milestone (אבן דרך)",
    "Cheers": "Cheers (לחיים)",
    "Passage": "Passage (מעבר)",
    "Portal": "Portal (פורטל)",
    "Handoff": "Handoff (העברה חלקה)",
    "Rebound": "Rebound (ריבאונד)",
    "Slide": "Slide (גלישה)",
    // Melodic & Ambient
    "Stargaze": "Stargaze (מבט לכוכבים)",
    "Illuminate": "Illuminate (הארה)",
    "Crystals": "Crystals (קריסטלים)",
    "Cosmic": "Cosmic (קוסמי)",
    // Sound Categories
    "Encore Tones": "צלילי הדרן (Encore)",
    "Melodic & Ambient": "מלודי ואווירתי",
    "Meme & Fun": "ממים ושעשוע 🎭",
    "Classic Alert Sounds": "צלילי התראה קלאסיים",
    "Search sounds...": "חיפוש צלילים...",
    "Preview": "השמעה",
    "Previous sound (‹)": "צליל קודם (‹)",
    "Next sound (›)": "צליל הבא (›)",
    "Random / Shuffle (🔀)": "צליל אקראי (🔀)",
    // Meme Sounds
    "Emotional Damage": "Emotional Damage",
    "Faah": "Faah",
    "Vine Boom": "Vine Boom",
    "Bruh": "Bruh",
    "OOF (Roblox)": "OOF (רובלוקס)",
    "Windows Error": "שגיאת ווינדוס (Windows Error)",
    "What The Dog Doin": "What The Dog Doin",
    "Mario 1-Up": "מריו (Mario 1-Up)",
    "Mario Power-Up": "מריו פטריה (Mario Power-Up)",
    "Mario Jump": "מריו קפיצה (Mario Jump)",
    "Mario Pipe": "מריו צינור (Mario Pipe)",
    "Illuminati (X-Files)": "תיקים באפלה (X-Files)",
    "Directed by (Curb)": "תרגיע (Curb Your Enthusiasm)",
    "Huh? (Cat)": "חתול Huh?",
    "Wilhelm Scream": "צעקת וילהלם (Wilhelm)",
    "Taco Bell Bong": "Taco Bell Bong",
    "Quack": "Quack (ברווז)",
    "Sheesh": "Sheesh",
    "Yeet": "Yeet",
    "Anime Wow": "Anime Wow",
    "Ta-Da": "Ta-Da",
    // Classic Alerts
    "Glass": "Glass (זכוכית)",
    "Hero": "Hero (הירו)",
    "Pop": "Pop (פופ)",
    "Ping": "Ping (פינג)",
    "Tink": "Tink (טינק)",
    "Submarine": "Submarine (צוללת)",
    "Funk": "Funk (פאנק)",
    "Morse": "Morse (מורס)",
    "Purr": "Purr (גרגור)",
    "Frog": "Frog (צפרדע)",
    // Notification Events
    "Desktop toggle": "החלפת מצב שולחן עבודה",
    "When all windows are hidden or restored": "כאשר כל החלונות מוסתרים או משוחזרים",
    "Desktop Clean": "שולחן עבודה נקי",
    "All windows hidden": "כל החלונות הוסתרו",
    "Windows Restored": "החלונות שוחזרו",
    "All windows unhidden": "כל החלונות הוצגו מחדש",
    "Others Saved in your session": "אחרים שנשמרו בסידור",
    "Group other apps in submenu": "קבץ יישומים נוספים בתפריט משני",
    "Keep the menu bar dropdown compact by placing background apps in a submenu": "שמור על תפריט שורת המצב קומפקטי על ידי הצגת יישומי רקע בתפריט משני",
    "Notch Sound": "צליל מגרעת",
    "Play sound when notch alerts appear": "השמע צליל בעת הופעת התראות מגרעת",
    "Configure Notch Events": "הגדר אירועי מגרעת",
    "System Notification Sound": "צליל התראות מערכת",
    "Play sound when Notification Center banners are delivered": "השמע צליל בעת מסירת התראות במרכז ההודעות",
    "Configure System Events": "הגדר אירועי מערכת",
    "Restore Settings": "הגדרות שחזור",
    "Full Restore": "שחזור מלא",
    "Full restore & single app restore controls": "בקרות שחזור מלא ושחזור יישום יחיד",
    "Feature Guide": "מדריך תכונות",
    "Display reconnects, startup & polling": "חיבור מסכים מחדש, הפעלה בדיקה מחזורית",
    "Auto-restore on launch & delays": "שחזור אוטומטי בהפעלה והשהיות",
    "Cmd+Shift+R shortcuts & rules": "קיצורי מקשים ⌘⇧R וחוקים",
    "Desktop toggle (Cmd+D) & unhide restore": "הסתרה/הצגה (Cmd+D) ושחזור",
    "Theme, Liquid Glass, Notch & Language": "נושא, Liquid Glass, התראות מגרעת ושפה",
    "Interactive app capabilities walkthrough": "מדריך אינטראקטיבי ליכולות האפליקציה",
    // Automation
    "General": "כללי",
    "Auto-restore on connect": "שחזר אוטומטית בעת חיבור",
    "Full restore on connect": "שחזור מלא בעת חיבור",
    "Restores layout when displays reconnect": "משחזר סידור חלונות כאשר מסכים מתחברים",
    "Restores all saved windows when displays reconnect": "משחזר את כל החלונות השמורים כאשר מסכים מתחברים",
    "Restores all saved windows to their exact positions automatically when displays reconnect": "משחזר את כל החלונות השמורים למיקומם המדויק באופן אוטומטי בעת חיבור מחדש של מסכים",
    "Auto-restore on app open": "שחזר אוטומטית בפתיחת יישום",
    "Restores an app's saved window when it is launched": "משחזר את החלון השמור של יישום עם פתיחתו",
    "Restores an app's saved window position automatically whenever it is launched": "משחזר את מיקום החלון השמור של יישום באופן אוטומטי בכל פעם שהוא מופעל",
    "App launch restore delay": "השהיית שחזור בפתיחת יישום",
    "Delay before auto-restoring window position when an app opens": "השהייה לפני שחזור אוטומטי של מיקום החלון בעת פתיחת יישום",
    "Delays below 1.0s may cause restore to fail if the app's windows take time to open.": "השהייה מתחת ל-1.0 שניות עלולה לגרום לכשל בשחזור אם חלונות היישום מתעכבים להיפתח.",
    "Animate restoration": "הנפש שחזור",
    "Smoothly move windows to their spots": "הזז חלונות בצורה חלקה למקומם",
    "Smoothly slide and animate windows to their target spots during restoration": "מניע ומחליק חלונות בצורה נעימה וחלקה אל יעד שחזורם",
    "Launch closed apps on full restore": "הפעל יישומים סגורים בשחזור מלא",
    "Automatically launch closed applications saved in your layout session sequentially before restoring": "מפעיל באופן אוטומטי ובטורי יישומים סגורים השמורים בסשן לפני ביצוע השחזור",
    "Launch at login": "הפעל בעת כניסה",
    "Start RememberMyWindows automatically": "הפעל את RememberMyWindows אוטומטית",
    "Start RememberMyWindows automatically in the background whenever you log into macOS": "מפעיל את RememberMyWindows באופן אוטומטי ברקע בכל כניסה למערכת ההפעלה macOS",
    "Activity Log Level": "רמת פירוט לוג",
    "Filter which events appear in the log": "סנן אילו אירועים יופיעו בלוג",
    "Filter which events appear in the real-time activity log": "מסנן אילו אירועים ופעילויות יופיעו בזמן אמת ביומן הפעילות",
    "Use polling mode (legacy)": "השתמש במצב בדיקה מחזורית (מדור קודם)",
    "Checks window positions after 5 s, then backs off while idle": "בודק את מיקומי החלונות לאחר 5 שניות, ואז מצמצם בדיקות במצב סרק",
    "Checks window positions after 5 s, then backs off while idle instead of event notifications": "בודק את מיקומי החלונות כעבור 5 שניות ומפחית בדיקות במצב סרק במקום להשתמש בהתראות אירועים",
    "Higher energy usage": "צריכת אנרגיה גבוהה יותר",
    "Polling checks less often while idle, but event-driven mode uses the least power.": "בדיקה מחזורית פועלת בתדירות נמוכה יותר במצב סרק, אך מצב מונחה־אירועים צורך את כמות האנרגיה הנמוכה ביותר.",
    // Single App Restore
    "Single App Restore": "שחזור יישום בודד",
    // Quick Key Restore (Fn Long-Press & Double-Tap Caps Lock)
    "Quick Key Restore": "שחזור במקש מהיר",
    "Quick key restore": "שחזור במקש מהיר",
    "Trigger window restoration using Fn long-press or double-tap Caps Lock": "שחזר חלונות בלחיצה ארוכה על Fn או בלחיצה כפולה על Caps Lock",
    "Trigger shortcut": "קיצור מקשים להפעלה",
    "Fn Long-Press": "לחיצה ארוכה על Fn",
    "Double-Tap Caps Lock": "לחיצה כפולה על Caps Lock",
    "Both (Fn or Caps Lock)": "שניהם (Fn או Caps Lock)",
    "Hold Fn / Globe (🌐) key to restore": "החזק את מקש ה-Fn / Globe (🌐) לשחזור",
    "Double-tap ⇪ Caps Lock key to restore": "הקש פעמיים על מקש ה-⇪ Caps Lock לשחזור",
    "Hold Fn (🌐) or double-tap ⇪ Caps Lock to restore": "החזק את Fn (🌐) או הקש פעמיים ⇪ Caps Lock לשחזור",
    "Restore mode": "מצב שחזור",
    "Choose what gets restored when the shortcut fires": "בחר מה ישוחזר כאשר הקיצור מופעל",
    "Front App Restore": "שחזור היישום הפעיל",
    "Hold duration": "משך לחיצה",
    "How long to hold Fn before the restore fires": "כמה זמן להחזיק את Fn עד לביצוע השחזור",
    "Short taps on Fn work normally. Only holding it for the duration triggers restore.": "לחיצה קצרה על Fn פועלת כרגיל. רק החזקה ממושכת תפעיל את השחזור.",
    "Single taps on Caps Lock work normally. Double-tapping restores and turns off Caps Lock.": "לחיצה אחת על Caps Lock פועלת כרגיל. לחיצה כפולה משחזרת ומכבה את Caps Lock.",
    "Hold Fn (🌐) for the set duration, or double-tap ⇪ Caps Lock anytime to restore instantly.": "החזק את Fn (🌐) למשך הזמן שהוגדר, או הקש פעמיים על ⇪ Caps Lock בכל עת לשחזור מיידי.",
    "Full restore, single app & Quick Key controls": "בקרות שחזור מלא, שחזור יישום בודד ומקש מהיר",
    // Quick Key Onboarding Slide
    "Hold Fn or Double-Tap ⇪": "החזק Fn או הקש פעמיים על ⇪",
    "Restore your layout instantly by holding the Fn / Globe (🌐) key or double-tapping Caps Lock — customizable in Settings.": "שחזר את הסידור מיידית על ידי לחיצה ארוכה על Fn / Globe (🌐) או לחיצה כפולה על Caps Lock — ניתן להתאמה בהגדרות.",
    "Hold Fn to restore": "החזק Fn לשחזור",
    "Double-tap ⇪ to restore": "הקש פעמיים ⇪ לשחזור",
    "Restored ✓": "שוחזר ✓",
    "Holding...": "...מחזיק",
    "Double Tap": "הקשה כפולה",
    "Front App Restored": "היישום הפעיל שוחזר",
    // macOS System Notifications
    "macOS System Notifications": "התראות מערכת של macOS",
    "Deliver standard Notification Center banners for layout and display events": "הצג באנרים רגילים של מרכז ההתראות עבור אירועי פריסה וצגים",
    "Full layout restores": "שחזור פריסה מלאה",
    "When all windows are restored to their saved layout": "כאשר כל החלונות משוחזרים לפריסה השמורה שלהם",
    "Single app restores": "שחזור יישום בודד",
    "When a single frontmost app or auto-restore fires": "כאשר מופעל שחזור יישום פעיל בודד או שחזור אוטומטי",
    "Display connections & changes": "חיבורים ושינויי צגים",
    "When monitors connect, disconnect, or reconnect": "כאשר צגים מתחברים, מתנתקים או מתחברים מחדש",
    "Snapshot & app updates": "עדכוני מפגשים ויישומים",
    "When apps or layouts are saved, added, or updated": "כאשר יישומים או פריסות נשמרים, מתווספים או מתעדכנים",
    // Front App tooltip
    "Front App": "יישום קדמי",
    "Pin which app comes to the front after a full restore — tap the layers icon on any app row in a saved session.": "נעץ איזה יישום יבוא לקדמת המסך לאחר שחזור מלא — הקש על סמל השכבות בשורת כל יישום במפגש שמור.",
    // Single App Restore relationship hint
    "When either trigger fires, **Trigger Command on Single Restore** in Active App Command Trigger also applies.": "כאשר אחד מהטריגרים מופעל, ההגדרה **הפעל פקודה בשחזור יישום בודד** בטריגר פקודת יישום פעיל חלה גם היא.",
    // Active App Command Trigger
    "Active App Command Trigger": "טריגר פקודת יישום פעיל",
    "Excluded": "הוחרגו",
    "Enabled": "פעיל",
    "Tap the ⌘⇧R button on any app row in a saved session": "הקש על לחצן ה-⌘⇧R בשורת כל יישום במפגש שמור",
    "Trigger Command on Full Restore": "הפעל פקודה בשחזור מלא",
    "Sends Cmd+Shift+R to the front app after restoring all windows": "שולח Cmd+Shift+R ליישום הקדמי לאחר שחזור כל החלונות",
    "Sends Cmd+Shift+R key shortcut to the front app after restoring all windows": "שולח את קיצור המקשים Cmd+Shift+R ליישום הקדמי ביותר לאחר שחזור כל החלונות",
    "Trigger Command on Single Restore": "הפעל פקודה בשחזור בודד",
    "Sends Cmd+Shift+R when a single app is restored or launched": "שולח Cmd+Shift+R כאשר יישום בודד משוחזר או מופעל",
    "Sends Cmd+Shift+R key shortcut when a single app is restored or launched": "שולח את קיצור המקשים Cmd+Shift+R כאשר יישום בודד משוחזר או מופעל",
    "Command delay on single restore": "השהיית פקודה בשחזור בודד",
    "Delay before sending command shortcut on single app restore": "השהייה לפני שליחת קיצור המקשים בשחזור יישום בודד",
    "Delays below 4.3s may send shortcut before the app gains focus.": "השהייה מתחת ל-4.3 שניות עלולה לשלוח את קיצור המקשים לפני שהיישום קיבל פוקוס.",
    "Only when external monitor is active": "רק כאשר מסך חיצוני פעיל",
    "Restricts command to when at least two displays are connected": "מגביל את הפקודה למצב שבו לפחות שני מסכים מחוברים",
    "Restricts sending command shortcut to times when at least two displays are connected": "מגביל את שליחת קיצור המקשים לזמנים שבהם מחוברים לפחות שני מסכים לפחות",
    "Animate Command+Shift+R overlay": "הנפש חלונית Command+Shift+R",
    "Displays a floating visual HUD badge over the target window when the command is triggered": "מציג תגית ויזואלית צפה מעל החלון המיועד בעת הפעלת הפקודה",
    "Update '%@' position": "עדכן מיקום עבור '%@'",
    "Add '%@' to '%@'": "הוספת %@ אל '%@'",
    "Update Full Layout '%@'": "עדכן פריסה מלאה '%@'",
    "Update Full Layout": "עדכן פריסה מלאה",
    "Full Restore '%@'": "שחזור מלא '%@'",
    "Full Restore Default Layout": "שחזור מלא של פריסת ברירת מחדל",
    "Already In Place": "כבר במקום",
    "Quiet when already in place": "שקט כאשר החלון כבר במקום",
    "Silent banner without sound when window is already in position": "התראה שקטה ללא צליל כאשר החלון כבר נמצא במיקומו",
    "How it works": "איך זה עובד",
    "After restoring windows, the app sends **⌘⇧R** to the frontmost application. Open each saved session and tap the **⌘⇧R button** on any app row to exclude that app from receiving the keystroke.": "לאחר שחזור החלונות, האפליקציה שולחת **⌘⇧R** ליישום הקדמי ביותר. פתח כל מפגש שמור והקש על **לחצן ה-⌘⇧R** בשורת כל יישום כדי להחריג יישום זה מקבלת צירוף המקשים.",
    // Experimental
    "Experimental": "ניסיוני",
    "Quickly hide/show all windows (disabled for Safari)": "הסתר/הצג במהירות את כל החלונות (מושבת עבור Safari)",
    "Quickly hide/show all windows across your desktop (disabled for Safari browser)": "מסתיר ומציג במהירות את כל החלונות בשולחן העבודה (מושבת עבור דפדפן Safari)",
    "Automatically run layout restore when showing windows": "הפעל שחזור אוטומטי של חלונות בעת חזרתם",
    "Focus configured app on unhide": "התמקדות ביישום שהוגדר בעת ביטול הסתרה",
    "Bring the snapshot's frontmost app to focus when unhiding": "הבא לקדמת הבמה את היישום הראשי של הסידור בעת ביטול הסתרה",
    "Bring the snapshot's configured frontmost app back into focus when unhiding desktop": "מחזיר את התמקדות המצלם ליישום הקדמי שהוגדר בסידור בעת ביטול הסתרת שולחן העבודה",
    // Appearance
    "Appearance": "מראה",
    "Notch Notification": "התראות מגרעת",
    "Show layout restore alerts from the notch": "הצג התראות שחזור מהמגרעת",
    "Show layout restore alerts sliding smoothly down from the MacBook notch": "מציג התראות שחזור מרהיבות המחליקות בצורה נעימה אל מחוץ למגרעת המסך (Notch)",
    "Theme Color": "צבע ערכת נושא",
    "Primary accent for the interface": "צבע הדגשה ראשי לממשק",
    "Primary accent color highlights across the app interface": "צבע ההדגשה הראשי המופיע לכל אורך אלמנטי הממשק באפליקציה",
    "App Language": "שפת היישום",
    "Override the system language": "עקוף את שפת המערכת",
    "Restart app to apply to system menus": "הפעל מחדש את היישום כדי להחיל על תפריטי המערכת",
    // Notch Position HUD
    "Position '%@'": "מיקום '%@'",
    "Resize & move the window, then tap Done": "שנה גודל והזז את החלון, ולאחר מכן לחץ סיום",
    "Done": "סיום",
    "Cancel": "ביטול",

    // System Permissions
    "System Permissions": "הרשאות מערכת",
    "Accessibility": "נגישות",
    "Needed to restore window positions in apps like Chrome, Telegram, etc.": "נדרש כדי לשחזר מיקומי חלונות ביישומים כמו Telegram, Chrome, וכו׳.",
    "Accessibility access granted": "הרשאת נגישות אושרה",
    "Accessibility access required": "נדרשת הרשאת נגישות",
    "Grant Permission…": "אשר הרשאה…",
    "RememberMyWindows needs Accessibility permission to restore window positions in other apps like Telegram, Chrome, etc.": "RememberMyWindows זקוק להרשאת נגישות כדי לשחזר מיקומי חלונות ביישומים אחרים כמו Telegram, Chrome, וכו׳.",
    "Open System Settings…": "פתח הגדרות מערכת…",
    // Finder Automation
    "Finder Control granted": "גישה ל-Finder אושרה",
    "Finder Control required": "נדרשת גישה ל-Finder",
    "Finder Control": "שליטה ב-Finder",
    "Required for the Desktop Toggle to collapse and restore Finder windows.": "נדרש עבור מיתוג שולחן העבודה כדי לכווץ ולשחזר חלונות Finder.",
    "Open Automation Settings…": "פתח הגדרות אוטומציה…",
    "Permissions Required": "נדרשות הרשאות",
    "Permissions granted": "הרשאות אושרו",
    "Two quick permissions let RememberMyWindows do its job properly.": "שתי הרשאות קצרות מאפשרות ל-RememberMyWindows לעבוד כראוי.",
    "Required for the Desktop Toggle — collapses and restores Finder windows.": "נדרש עבור מיתוג שולחן עבודה — כווץ ושחזר חלונות Finder.",
    "Grant Finder Access…": "אשר גישה ל-Finder…",
    "Grant Accessibility…": "אשר נגישות…",
    "Grant Permissions…": "אשר הרשאות…",
    "Save location with layouts": "שמור מיקום עם סידור חלונות",
    "Tags saved sessions with your current GPS coordinates": "מתייג מפגשים שמורים עם קואורדינטות ה-GPS הנוכחיות שלך",
    "Tags saved layout sessions with your current GPS coordinates to easily identify locations": "מתייג מפגשי סידור שמורים עם קואורדינטות ה-GPS הנוכחיות שלך כדי שתוכל לזהות בקלות מיקומים",
    "Location access granted": "הרשאת מיקום אושרה",
    "Location access denied": "הרשאת מיקום נדחתה",
    "Location access restricted": "הרשאת מיקום מוגבלת",
    "Location access required": "נדרשת הרשאת מיקום",
    "Location status unknown": "סטטוס מיקום לא ידוע",
    "To revoke location permission, it must be disabled manually in System Settings -> Privacy & Security -> Location Services.": "כדי לבטל את הרשאת המיקום, יש להשבית אותה ידנית בהגדרות המערכת -> פרטיות ואבטחה -> שירותי מיקום.",
    "Open Location Settings…": "פתח הגדרות מיקום…",
    "Location Privacy & Safety": "פרטיות ואבטחת מיקום",
    "Turn On": "הפעל",
    "Your location is used to tag your saved window layouts so you can easily identify where they were saved. All coordinates are processed locally on your Mac and are never uploaded or shared. To protect your privacy, the app only takes 1 location snapshot per session.": "המיקום שלך משמש לתיוג סידורי החלונות השמורים שלך כדי שתוכל לזהות בקלות היכן הם נשמרו. כל הקואורדינטות מעובדות באופן מקומי ב-Mac שלך ולעולם אינן מועלות או משותפות. כדי להגן על פרטיותך, האפליקציה שומרת רק צילום מיקום אחד לכל הפעלה.",
    // Settings Guide Splash Slide
    "Settings Controls": "בקרי הגדרות",
    "Customize triggers, Desktop Toggle (Cmd+D), and Notch notifications in Settings.": "התאם אישית טריגרים, מקש שולחן עבודה (Cmd+D), והתראות מגרעת בהגדרות.",
    "Auto-Restore": "שחזור אוטומטי",
    "Triggers on display connect or app open": "מופעל בחיבור מסך או פתיחת יישום",
    "Desktop Toggle": "הצגת שולחן העבודה",
    "%@ to hide or show all windows": "%@ להסתרה או הצגה של כל החלונות",
    "Notch Alerts": "התראות מגרעת",
    "Pill notifications for layout events": "התראות קפסולה לאירועי סידור חלונות",
    // Menu Bar at a Glance Splash Slide
    "Menu Bar at a Glance": "סקירת שורת התפריטים",
    "Left click restores the focused app and opens the list. Right click restores everything at once.": "לחיצה שמאלית משחזרת את היישום הפעיל ופותחת את הרשימה. לחיצה ימנית משחזרת הכל בבת אחת.",
    "Left Click": "לחיצה שמאלית",
    "Right Click": "לחיצה ימנית",
    "Restore focused app\n& open app list": "שחזר יישום פעיל\n& פתח רשימה",
    "Restore full layout\nfor all apps": "שחזר סידור מלא\nלכל היישומים",
    // Settings Toggle
    "Restore focused app on left click": "שחזר יישום פעיל בלחיצה שמאלית",
    "Left-clicking the menu bar icon restores the frontmost app": "לחיצה שמאלית על סמל שורת התפריטים משחזרת את היישום הקדמי",
    "Left-clicking the menu bar icon restores the window position of the frontmost app": "לחיצה שמאלית על סמל שורת התפריטים משחזרת את מיקום החלון של היישום הקדמי",
    "When either trigger fires, **Trigger Command on Single Restore** in Experimental also applies.": "כאשר אחד מהטריגרים מופעל, ההגדרה **הפעל פקודה בשחזור בודד** בניסיוני חלה גם היא.",
    // Feature Tour
    "Feature Tour": "סיור תכונות",

    // Settings slide cycling descriptions (casual tone)
    "Restores window layouts automatically when you plug/unplug monitors or open apps.": "משחזר סידורי חלונות באופן אוטומטי בעת חיבור/ניתוק מסכים או פתיחת יישומים.",
    "Hit %@ to hide all windows and see your desktop. Hit it again to bring them back.": "לחץ %@ להסתרת כל החלונות ולראות את שולחן העבודה. לחץ שוב כדי לשחזר אותם.",
    "A pill-shaped alert slides out of the notch when layouts restore — subtle but satisfying.": "התראה בצורת קפסולה מחליקה מהמגרעת כאשר הסידור משוחזר — עדין אבל מהנה.",
    "Control what shows up in the activity log. 'Necessary' keeps it quiet, 'Verbose' tells you everything.": "שלוט במה שמוצג ביומן הפעילות. 'חיוני' שומר על שקט, 'מפורט' מספר הכל.",
    // Legacy settings descriptions kept for compatibility
    "Press Cmd+D to hide all windows and show desktop. Press again to restore them.": "לחץ Cmd+D להסתרת כל החלונות והצגת שולחן העבודה. לחץ שוב לשחזורם.",
    "Shows an elegant pill-shaped alert sliding out from your screen notch when layouts restore.": "מציג התראת קפסולה אלגנטית המחליקה ממגרעת המסך בעת שחזור סידורים.",
    "Filters log verbosity. Use 'Necessary' to minimize logging, or 'Verbose' for troubleshooting.": "מסנן את פירוט הלוגים. בחר 'חיוני' למינימום רישום, או 'מפורט' לפתרון בעיות.",
    // Log Levels
    "Necessary": "חיוני",
    "Moderate": "מתון",
    "Verbose": "מפורט",
    // Version & GitHub
    "Version": "גרסה",
    "GitHub": "GitHub",
    "Open RememberMyWindows on GitHub": "פתח את RememberMyWindows ב-GitHub",
    "Version 1.0.0": "גרסה 1.0.0",
    // ContentView
    "Update Layout": "עדכן סידור",
    "Save Layout": "שמור סידור",
    "Restore": "שחזר",
    "VISUAL PREVIEW": "תצוגה מקדימה",
    "Accessibility Permission Required": "נדרשת הרשאת נגישות",
    "To track and restore windows from other apps, please enable RememberMyWindows in System Settings.": "כדי לעקוב ולשחזר חלונות מיישומים אחרים, אפשר את RememberMyWindows בהגדרות המערכת.",
    "Open System Settings": "פתח הגדרות מערכת",
    // LayoutsView
    "LIVE LAYOUT": "סידור חי",
    "SAVED SESSIONS": "מפגשים שמורים",
    "No active layout for this screen config": "אין סידור פעיל לתצורת מסך זו",
    "No saved sessions": "אין מפגשים שמורים",
    "No layouts saved yet": "לא נשמרו סידורים עדיין",
    "Live": "חי",
    "Active": "פעיל",
    "Select a layout to view details": "בחר סידור לצפייה בפרטים",
    "SCREEN ID": "מזהה מסך",
    "Windows": "חלונות",
    "windows": "חלונות",
    "Created": "נוצר",
    "Updated": "עודכן",
    "External Screens Missing": "מסכים חיצוניים חסרים",
    "Connect the required displays to enable restoration of this session.": "חבר את המסכים הנדרשים כדי לאפשר שחזור מפגש זה.",
    "New monitor detected with the same name": "זוהה מסך חדש עם אותו שם",
    "This is a different physical unit than the one in this session.": "זהו יחידה פיזית שונה מזו שבמפגש זה.",
    "Full Screen": "מסך מלא",
    "Click to rename": "לחץ לשינוי שם",
    "Saved&Updated At": "נשמר ועודכן ב",
    "Saved At": "נשמר ב",
    // ActivityView
    "ACTIVITY LOG": "לוג פעילות",
    "Copy Full Log": "העתק לוג מלא",
    "Clear Log": "נקה לוג",
    "History is empty": "ההיסטוריה ריקה",
    // Menu
    "Open RememberMyWindows": "פתח את RememberMyWindows",
    "Open RememberMyWindows (%@)": "פתח את RememberMyWindows (%@)",
    "Restore Default Layout": "שחזר סידור ברירת מחדל",
    "%@ needs attention": "%@ דורש תשומת לב",
    "%@ window(s) could not be confirmed": "לא ניתן לאשר %@ חלון/חלונות",
    "Restore needs attention": "השחזור דורש תשומת לב",
    "Saved Sessions": "מפגשים שמורים",
    "Quit": "יציאה",
    // System Strings
    "Built-in": "מובנה",
    "Built-in Retina Display": "צג Retina מובנה",
    "Display": "תצוגה",
    "No Display": "אין תצוגה",
    "Bring to Front": "הבא לקדמה",
    "Bring \"%@\" to Front": "הבא את \"%@\" לקדמה",
    "Remove from Session": "הסר מהמפגש",
    "%@ is not in this layout": "%@ אינו בסידור הנוכחי",
    // Permissions & Web Apps
    "Additional delay for web apps": "השהיה נוספת ליישומי רשת",
    "Extra wait time for web apps, PWAs, and browsers on launch before sending ⌘⇧R": "זמן המתנה נוסף ליישומי רשת, PWA ודפדפנים בעת הפעלה לפני שליחת ⌘⇧R",
    "Web App Detection & Custom Apps": "זיהוי יישומי רשת ויישומים מותאמים",
    "Custom Web Apps": "יישומי רשת מותאמים",
    "PWAs (Chrome, Safari Web Apps), Electron apps (Slack, Discord, Notion), and Web Browsers are detected automatically. You can also designate specific apps as web apps below.": "יישומי PWA (כרום, ספארי), יישומי Electron (כגון Slack, Discord, Notion) ודפדפנים מזוהים אוטומטית. ניתן גם להגדיר יישומים ספציפיים כיישומי רשת להלן.",
    "Re-check Status": "בדוק סטטוס מחדש",
    "Re-check": "בדוק שוב",
    "If already turned on in macOS Settings, toggle the switch OFF and ON to refresh the system cache.": "אם ההרשאה כבר מופעלת בהגדרות המערכת, כבה והפעל מחדש את המתג לרענון זיכרון המערכת.",
    "To track and restore windows from other apps, please enable RememberMyWindows in System Settings. If already ON, toggle it OFF and ON to refresh macOS cache.": "כדי לעקוב ולשחזר חלונות מיישומים אחרים, אנא הפעל את RememberMyWindows בהגדרות המערכת. אם כבר מופעל, כבה והפעל מחדש לרענון זיכרון המערכת.",
    "If RememberMyWindows is already turned ON in System Settings, the macOS permission cache may be out of sync. Toggle the switch OFF and ON to refresh it.": "אם RememberMyWindows כבר מופעל בהגדרות המערכת, ייתכן שזיכרון ההרשאות אינו מסונכרן. כבה והפעל מחדש את המתג כדי לרענן אותו.",
    "Add Running App": "הוסף יישום פעיל",
    "Add Custom App ID": "הוסף מזהה יישום מותאם",
    "No custom web apps added yet": "טרם נוספו יישומי רשת מותאמים",
    "Add": "הוסף",
    "Enter bundle identifier (e.g. com.example.app)": "הזן מזהה חבילה (לדוגמה com.example.app)",
    "Welcome Tour & Onboarding": "סיור פתיחה והדרכה",
    "Replay the onboarding walkthrough and setup guide": "הפעל מחדש את סיור ההיכרות ומדריך ההגדרה",
    "Replay Tour": "הפעל סיור מחדש",
    // Menu Bar Icon Customization
    "Menu Bar Icon Style": "סגנון סמל שורת התפריטים",
    "Choose the resting and active icons shown in the macOS status bar": "בחר את הסמלים המוצגים בשורת התפריטים במצב מנוחה ובמצב פעולה",
    "Match Accent Theme Color": "התאם לצבע ערכת הנושא",
    "Tint menu bar icon with active app theme instead of native monochrome": "צבע את סמל שורת התפריטים לפי ערכת הנושא במקום שחור/לבן",
    "Resting": "מנוחה",
    "Action": "פעולה",
    "Test Dynamic Action": "בדוק פעולה דינמית",
    "Custom SF Symbol": "סמל SF מותאם",
    "Custom Image": "תמונה מותאמת אישית",
    "Resting SF Symbol": "סמל SF במנוחה",
    "Action SF Symbol": "סמל SF בפעולה",
    "Choose Image File…": "בחר קובץ תמונה…",
    "Clear Image": "נקה תמונה",
    "Mac Window": "חלון Mac",
    "2x2 Grid": "רשת 2x2",
    "3D Stack": "ערימת תלת-ממד",
    "Workspace Restore": "שחזור סביבת עבודה",
    "Mission Control": "Mission Control",
    "Magic Sparkles": "ניצוצות קסם",
]

private let reverseDict: [String: String] = [
    "מראה והתראות": "Appearance & Notifications",
    "%@ אינו בסידור הנוכחי": "%@ is not in this layout",
    "צג Retina מובנה": "Built-in Retina Display",
    "מובנה": "Built-in",
    "תצוגה": "Display",
    "אין תצוגה": "No Display",
    "סידור חי": "LIVE LAYOUT",
    "מפגשים שמורים": "SAVED SESSIONS",
    "חי": "Live",
    "פעיל": "Active",
    "חלונות": "Windows",
    "נוצר": "Created",
    "עודכן": "Updated",
    "נשמר ועודכן ב": "Saved&Updated At",
    "נשמר ב": "Saved At",
    "לוג פעילות": "ACTIVITY LOG",
    "שוחזר": "Restored",
    "שמור מיקום עם סידור חלונות": "Save location with layouts",
    "הרשאת מיקום אושרה": "Location access granted",
    "הרשאת מיקום נדחתה": "Location access denied",
    "פרטיות ואבטחת מיקום": "Location Privacy & Safety",
    "הפעל": "Turn On",
    "המיקום שלך משמש לתיוג סידורי החלונות השמורים שלך כדי שתוכל לזהות בקלות היכן הם נשמרו. כל הקואורדינטות מעובדות באופן מקומי ב-Mac שלך ולעולם אינן מועלות או משותפות. כדי להגן על פרטיותך, האפליקציה שומרת רק צילום מיקום אחד לכל הפעלה.": "Your location is used to tag your saved window layouts so you can easily identify where they were saved. All coordinates are processed locally on your Mac and are never uploaded or shared. To protect your privacy, the app only takes 1 location snapshot per session.",
]

var currentLocale: Locale {
    let langStr = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    let lang = AppLanguage(rawValue: langStr) ?? .auto
    switch lang {
    case .hebrew:  return Locale(identifier: "he")
    case .english: return Locale(identifier: "en")
    case .auto:    return Locale.current
    }
}
