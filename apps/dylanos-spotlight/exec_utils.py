"""Parse the Exec field of a desktop entry without invoking a shell."""
import re
import shlex


def desktop_exec_argv(exec_cmd):
    """Return argv for a desktop entry Exec value.

    Desktop-entry Exec is an argument vector, not shell syntax. Field codes
    are intentionally removed here because Spotlight launches without a file
    or URL selection.
    """
    command = re.sub(r"%[a-zA-Z]", "", exec_cmd).strip()
    return shlex.split(command, posix=True)
