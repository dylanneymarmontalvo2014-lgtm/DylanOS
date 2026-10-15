# React → QML mapping

| React (`src/`) | QML (`src/qml/`) |
|---|---|
| `views.tsx` Home/Browse/Detail/Library/Updates/Installed/States/Settings/Search | `pages/*Page.qml` |
| `Page` header | `components/PageScaffold.qml` (title/sub left, controls right, wraps below 280px free) |
| Sidebar / top nav / drawer | `components/SidebarPanel.qml`, `Main.qml` |
| Card, Chip, Btn, Toggle, Select, Progress, Skeleton, EmptyState, ErrorBox, Toasts, ConfirmDialog | same-named components |
| Tailwind colors / radii / spacing | `theme/Colors.qml`, `Metrics.qml`; text sizes in `Typography.qml` |
| Lucide icons | `data/icons/*.svg` via `Icon.qml` + `IconImageProvider` |
| CSS grid `auto-fill minmax` | `components/AutoGrid.qml` (equal row heights, `stretchRows`) |
| Texts | `theme/Strings.qml` (copied verbatim) |

Breakpoints kept: page padding 24 / 20 below 640px; detail header stacks below 640px content; detail info column 320px, two columns on wide windows; hero padding 32 / 24 narrow.

## Visual comparison (done at identical window sizes, software renderer vs headless Chromium)
Compared: home (400/800/1280/1700), categories, category list, app detail, library, updates, installed, states, uninstall dialog, install-in-progress, install error, offline.

## Known differences
- Font: the React capture fell back to DejaVu (Google font unreachable); Qt bundles Onest, so text widths/wrapping differ slightly. Environmental.
- Modal: React has backdrop blur; Qt uses dim overlay only.
- Hero is a few px shorter than React; detail header/section spacing differs by ~4–9px.
- Narrow quick tiles: React overflows text, Qt elides it.
- `Select` is a custom ComboBox, not a native `<select>`.
- React has a scrollbar gutter (~15px narrower content); Qt overlays a thin scrollbar.
- Hero glow looks streaky and the Categories tile border can show repaint artifacts under the software renderer only.

## Not verified
Real GPU rendering; real mouse/keyboard interaction (hover, focus ring, drawer); search skeleton (350 ms); Settings, Search and Drawer screenshots versus React; accessibility with a screen reader.
