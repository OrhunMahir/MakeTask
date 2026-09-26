# MakeTask 1.0.0 — App Store submission copy

Prepared from the current application. Account-specific fields below must be completed in App Store Connect. This document does not submit or publish anything.

## Identity

- Name: MakeTask
- Subtitle: Desktop notes for your tasks
- Primary language: English (U.S.)
- Primary category: Productivity
- Bundle ID: `dev.orhun.MakeTask`
- Apple Developer membership: Individual, confirmed; Team ID `9WB6D5BCY2`
- Version: `1.0.0`
- Build: `3` — adds final-save protection and reliable legacy-settings migration; replaces the internally tested build 1 and the local build 2 package
- Minimum macOS version: 14.0
- Copyright: 2026 MakeTask contributors (matches the repository license)

## Promotional text

Keep independent task lists on your desktop. Capture ideas with a shortcut, organize the details, and roll each note up when you need more room.

## Description

Give your tasks a place on your desktop.

MakeTask keeps each list in its own small note window. Use one for today's work, another for a personal project, and another for the things you want to remember. Find all your lists in the menu bar whenever you need them.

KEEP YOUR LISTS CLOSE
Create, name, color, and arrange independent notes. Choose a normal window, keep a note on top, or place it at desktop level. Double-click an empty part of the header to roll a note into its title bar. Hide notes and bring them back from the menu bar.

CAPTURE AND ORGANIZE
Quick Add opens with a customizable global shortcut. Add task notes, subtasks, priorities, and optional due dates. Search within a list, drag tasks between notes, and use keyboard commands to select, edit, complete, or reorder tasks. Undo and redo help you recover recent changes.

MAKE IT YOURS
Choose note colors, light or dark appearance, type styles, transparency, and completion sounds. MakeTask follows macOS Reduce Motion and can launch at login when you enable it.

LOCAL BY DESIGN
Your lists and preferences stay on your Mac. There is no account, advertising, analytics, or cloud sync. Export a JSON backup to a location you choose, and import it later without replacing existing lists.

MakeTask lives in the menu bar. Due dates appear inside your notes; the app does not send scheduled reminder notifications.

## Keywords

todo,checklist,sticky,notes,desktop,tasks,organizer,focus,offline,menubar,productivity

## Screenshots

Upload the three files in `Release/Screenshots/` in numbered order. They show the production note and Quick Add views with sample tasks, at 2560 × 1600 with no alpha channel. See `Screenshots/README.md` for previews and regeneration instructions.

## First-version release notes

Meet MakeTask: independent desktop task notes, Quick Add, keyboard shortcuts, subtasks, priorities, due dates, and local backups.

## Support and privacy

- Current contact: https://github.com/OrhunMahir/MakeTask/issues
- Support page source: `Release/SUPPORT.md`
- Privacy policy source and bundled copy: `MakeTask/Resources/PrivacyPolicy.md`
- Privacy URL: https://github.com/OrhunMahir/MakeTask/blob/0dd1ca47df9c07044394733d9534ae0fcd91362d/MakeTask/Resources/PrivacyPolicy.md
- Support URL: https://github.com/OrhunMahir/MakeTask/blob/0dd1ca47df9c07044394733d9534ae0fcd91362d/Release/SUPPORT.md

Both selected URLs returned HTTP 200 without sign-in on September 13, 2026. Their source contents match the current bundled privacy policy and local support document byte for byte. These published commit permalinks avoid the unmerged `main` branch's 404 pages. Revisit the URLs when the policy or support content changes; a future public site or merged-main URL can replace them.

## App Privacy answers

For the current app: **No, we do not collect data from this app.** Tasks, preferences, and window state remain local. User-directed backup exports are not sent to the developer. External support messages are voluntary and handled through GitHub. There is no tracking or third-party analytics SDK.

The bundle includes `PrivacyInfo.xcprivacy`: no tracking, no collected data categories, and app-only UserDefaults use (`CA92.1`). Review these declarations if features or dependencies change.

## Age-rating questionnaire

The current app has no ads, in-app chat, public user-generated content service, unrestricted web browsing, gambling, purchases, or mature content supplied by the developer. It lets users enter their own private task text. Answer the questionnaire for the actual binary and use the age rating calculated by App Store Connect; do not invent a rating.

## App Review notes

MakeTask is a macOS menu-bar app. It does not keep a Dock icon or a traditional main window open. On a clean installation, a welcome window explains the menu-bar location and lets you create your first list. You can also use the menu-bar icon → New List or Quick Add.

No sign-in, account, subscription, server, or demo credentials are required. To test:

1. Create a list in the welcome window and add a task.
2. Click the task title to edit notes, priority, date/time, or subtasks; click its circle to complete it.
3. Double-click empty header space to collapse/expand the note.
4. Hide a note and reveal it again through the menu-bar list entry.
5. Use Quick Add from the menu or its default global shortcut, Command-Shift-Space. If that shortcut is already used on the review Mac, change it in Settings → Shortcuts.
6. Export and import local JSON backups in Settings → Backup. File access is limited to locations selected in the native file panels.

Launch at Login is optional and appears in Settings → General. Privacy Policy is accessible offline from Settings → About and the welcome window. Support opens the public project issue page in the browser.

## Account decisions still required

- Select free or paid distribution. If paid, supply the price and complete Apple's applicable agreements, tax, and banking information.
- Enter the real reviewer contact name, email, and phone in App Store Connect.
- Confirm territory availability and any required business/trader information in the account.
- Build 3 includes `ITSAppUsesNonExemptEncryption = NO` for the current app, which implements no custom encryption or networking. Reassess this declaration if the app or its dependencies change.
- Choose manual release so review approval does not immediately publish the app.

## Apple references

- [Privacy manifest / required reasons](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [App Review privacy rules](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [App Store Connect privacy answers](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Mac screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)

## Current submission requirements checked September 13, 2026

- Complete the store metadata and build selection, support/privacy links, screenshots and review contact information before submission. [Apple submission checklist](https://developer.apple.com/app-store/review/)
- Answer the current age-rating questions in App Information. [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- Declare the applicable trader status in Business/App Information; individual membership alone does not establish non-trader status. The account holder must determine the accurate status and provide any required details. [Apple DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- Choose **Manually release this version**. App Review approval then precedes a separate release action. [Apple release options](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)
- Build 3's export-compliance key follows [Apple's property-list guidance](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).
