"""Exercise the initial Plasma layout using its scripting object contract."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / 'themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js'


@unittest.skipUnless(shutil.which('node'), 'Node.js needed to execute the Plasma layout')
class DesktopLayoutTest(unittest.TestCase):
    def test_two_panels_wallpaper_and_pins(self):
        result = subprocess.run(['node', '-e', r'''
const vm = require('node:vm');
const fs = require('node:fs');
const assert = require('node:assert/strict');
function run(globals, geometries) {
  const panels = [];
  function containment(screenId) {
    return {screenId: screenId, settings: {}, widgets: [], writeConfig(k,v) {this.settings[k]=v;},
      addWidget(type,x,y,width,height) {const w=containment(screenId); w.type=type; w.geometry=[x,y,width,height]; this.widgets.push(w); return w;}};
  }
  const screens = [containment(0), containment(1)];
  globals.Panel = function() {const p=containment(0); panels.push(p); return p;};
  if (geometries) globals.screenGeometry = (id) => geometries[id];
  globals.desktops = () => screens;
  const context = vm.createContext(globals);
  vm.runInContext(fs.readFileSync(process.argv[1], 'utf8'), context);
  return {panels, screens, context};
}
const {panels, screens} = run({gridUnit: 18}, {0: {x: 0, y: 0, width: 1280, height: 800},
                                               1: {x: 0, y: 0, width: 1280, height: 800}});
assert.equal(panels.length, 2);
assert.deepEqual(panels.map(p => p.location), ['top', 'bottom']);
for (const s of screens) {
  assert.equal(s.widgets.length, 0, 'el escritorio inicial no debe añadir widgets');
}
for (const s of screens) assert.equal(s.settings.Image, 'file:///usr/share/wallpapers/DylanOS/dylanos-default.png');
assert(!panels[0].widgets.some(w => w.type.includes('tasks')));
assert(!panels[0].widgets.some(w => w.type === 'org.kde.plasma.pager'));
// Barra superior = barra de menú: siempre visible (sin autoocultado) y sin
// flotación, porque el margen de un panel flotante recortaba sus elementos.
// La barra superior se deja cubrir por ventanas a pantalla completa.
assert.equal(panels[0].hiding, 'letwindowscover');
assert.equal(panels[0].floating, false);
assert(panels[0].height >= 34, 'alto de barra insuficiente: ' + panels[0].height);
// El nombre de la aplicación activa y sus menús de acción van juntos: el
// separador elástico va después del menú, nunca entre el nombre y el menú.
assert.deepEqual(panels[0].widgets.map(w => w.type), [
  'org.kde.plasma.kickoff', 'com.dylanos.activeapp', 'org.kde.plasma.appmenu',
  'org.kde.plasma.panelspacer', 'org.kde.plasma.systemtray',
  'com.dylanos.search', 'com.dylanos.controlcenter',
  'org.kde.plasma.digitalclock']);
assert.equal(panels[0].widgets[0].settings.icon, 'distributor-logo-dylanos');
assert.equal(panels[0].widgets[7].settings.customDateFormat, "ddd dd 'de' MMM");
assert.equal(panels[0].widgets[7].settings.showDate, true);
// Dock inferior: flotante, centrado, ajustado a su contenido y con autoocultado.
assert.equal(panels[1].alignment, 'center');
assert.equal(panels[1].lengthMode, 'fit');
assert.equal(panels[1].floating, true);
assert.equal(panels[1].hiding, 'dodgewindows');
assert.deepEqual(panels[1].widgets.map(w => w.type), ['com.dylanos.dock', 'org.kde.plasma.trash']);
const fallback = run({gridUnit: 18});
for (const s of fallback.screens) assert.equal(s.widgets.length, 0);
// Sin gridUnit disponible el script no debe fallar.
const sinUnidad = run({}, {});
assert.equal(sinUnidad.panels[0].height, 36);
assert.equal(sinUnidad.panels[0].hiding, 'letwindowscover');
for (const s of sinUnidad.screens) assert.equal(s.widgets.length, 0);
''', str(LAYOUT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
