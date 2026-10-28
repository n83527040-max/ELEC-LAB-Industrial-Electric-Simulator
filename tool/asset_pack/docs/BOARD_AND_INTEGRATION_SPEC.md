# Fixed board and workspace integration spec

- The board must remain anchored to the center of the workspace viewport. It must not become a draggable component.
- Board size should fit the available content area with a stable portrait ratio; default target is approximately 92% of viewport width and no more than 72% of available height, adjusted to device aspect ratio.
- Use contain/fit scaling to keep the entire board visible. Zoom may scale the board contents but should not change the board's layout anchor or make it drift. Pan is optional only when zoomed beyond fit; reset-fit returns to centered position.
- The top toolbar, bottom action bar and device system insets are outside the board canvas and must not overlap it.
- Keep the power source bus in a fixed dedicated strip attached to the board's top edge: L1, L2, L3, optional N, PE, plus separate DC +/− source if selected. The strip is a fixed reference/supply module, not a movable load. Do not assume N is needed for every three-phase load; PE is protective earth, not a normal load-current conductor.
- Users draw wires from the fixed supply terminals to component terminals. Wires and devices can be moved; the board frame and supply strip stay fixed.
- Use clear phase colors and labels; never rely on color alone.
- Keep layers, add-component, undo/redo and simulation controls in a compact bottom toolbar.
- Components placed on the board should have sensible default size and snapping; zoom must not alter stored circuit coordinates.
- Validate layout at 360, 393 and 432 dp widths, portrait and landscape.
