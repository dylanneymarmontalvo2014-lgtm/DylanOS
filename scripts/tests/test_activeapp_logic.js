const assert = require("node:assert/strict");
const logic = require("../../apps/com.dylanos.activeapp/contents/ui/ActiveAppLogic.js");

assert.equal(logic.nameFromId("org.dylanos.explorer.desktop"), "DylanOS Explorer");
assert.equal(logic.nameFromId("org.dylanos.browser.desktop"), "DylanOS Browser");
assert.equal(logic.nameFromId("com.microsoft.VSCode"), "Visual Studio Code");
assert.equal(logic.nameFromId("org.example.SuperEditor"), "SuperEditor");
assert.equal(logic.nameFromId("simple-player"), "Simple player");
assert.equal(logic.nameFromId(""), "");
assert.equal(logic.humanName("draw.io"), "draw.io");
assert.equal(logic.humanName("Qt Creator 15.0.1"), "Qt Creator 15.0.1");
assert.equal(logic.humanName("  Editor personal  "), "Editor personal");
assert.equal(logic.nameFromDisplay("documento — Mozilla Firefox"), "Mozilla Firefox");
assert.equal(logic.nameFromDisplay("README - Visual Studio Code"), "Visual Studio Code");
assert.equal(logic.nameFromDisplay("Reproductor"), "Reproductor");

console.log("OK: normalización de nombres de aplicaciones");
