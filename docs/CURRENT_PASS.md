# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Current known issues:
1. Mendy assets are not fully implemented. The app mostly uses the basic icon instead of all Mendy states.
2. Menu bar manager should be removed and rewritten around Thaw/Ice-grade architecture. Current UI is decent, but functionality is not reliable enough.
3. Dock previews show the wrong app/window, often the neighboring Dock item.
4. Dock preview presentation and dismissal are janky and need DockDoor-grade behavior.
5. Option+Tab switcher highlights windows but does not reliably activate the selected/clicked app/window.
6. Browser window previews show duplicate/same previews even when different windows are open.
7. UI needs heavier Liquid Glass treatment and smoother motion.

Priority for this pass:
1. Preserve the app if it builds.
2. Wire Mendy states correctly.
3. Replace menu bar manager with a Thaw-derived architecture.
4. Document DockDoor issues for the next pass, but only fix obvious shared window identity bugs if safe.
5. Do not attempt Mos, MiddleClick, or Dockey in this pass.
