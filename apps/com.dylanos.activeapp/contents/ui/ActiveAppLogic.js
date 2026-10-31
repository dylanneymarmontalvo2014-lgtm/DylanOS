function humanName(value) {
    if (!value || typeof value !== "string") return ""
    return value.trim()
}

function nameFromId(value) {
    if (!value || typeof value !== "string") return ""
    var clean = value.trim()
    if (!clean.length) return ""
    if (clean.endsWith(".desktop")) clean = clean.substring(0, clean.length - 8)
    var knownMap = {
        "org.dylanos.explorer": "DylanOS Explorer",
        "org.dylanos.console": "DylanOS Console",
        "org.dylanos.calculator": "Calculadora",
        "org.dylanos.configuration": "DylanOS Configuration",
        "org.dylanos.store": "DylanOS Store",
        "org.dylanos.spotlight": "DylanOS Spotlight",
        "com.microsoft.VSCode": "Visual Studio Code",
        "code": "Visual Studio Code",
        "firefox-esr": "Firefox",
        "firefox": "Firefox",
        "kitty": "DylanOS Console"
    }
    if (knownMap[clean]) return knownMap[clean]
    var parts = clean.split(".")
    clean = parts[parts.length - 1].replace(/[-_]+/g, " ")
    return clean.charAt(0).toUpperCase() + clean.slice(1)
}

function nameFromDisplay(value) {
    if (!value || typeof value !== "string") return ""
    var clean = value.trim()
    if (!clean.length) return ""
    var separator = clean.indexOf(" — ") !== -1 ? " — " : " - "
    var parts = clean.split(separator)
    return parts[parts.length - 1].trim()
}

if (typeof module !== "undefined") {
    module.exports = { humanName, nameFromId, nameFromDisplay }
}
