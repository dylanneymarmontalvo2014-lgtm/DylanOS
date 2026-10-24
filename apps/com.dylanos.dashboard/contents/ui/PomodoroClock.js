.pragma library

function durationSeconds(mode) {
    return mode === "focus" ? 25 * 60 : 5 * 60
}

function nextMode(mode) {
    return mode === "focus" ? "break" : "focus"
}

function remainingSeconds(deadlineMs, nowMs) {
    if (typeof deadlineMs !== "number" || typeof nowMs !== "number" || !isFinite(deadlineMs) || !isFinite(nowMs)) return 0
    return Math.max(0, Math.ceil((deadlineMs - nowMs) / 1000))
}

function progress(remaining, duration) {
    if (typeof remaining !== "number" || typeof duration !== "number" || !isFinite(remaining) || !isFinite(duration) || duration <= 0) return 0
    return Math.max(0, Math.min(1, 1 - remaining / duration))
}
