"""Small formatting helpers. Mirrors the ecommerce Python port's app/utils.py
formatting conventions, trimmed to what this app needs."""

from datetime import datetime


def format_date(value: datetime | str | None) -> str:
    """Formats an ISO timestamp (or already-parsed datetime) for display."""
    if value is None:
        return ""
    parsed: datetime
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    else:
        parsed = value
    return parsed.strftime("%b %-d, %Y, %-I:%M %p")


def initial(name: str | None) -> str:
    """First letter of a display name, uppercased, for the avatar circle.
    Falls back to "?" for an empty/missing name."""
    stripped = (name or "").strip()
    return stripped[0].upper() if stripped else "?"


def relative_time(value: datetime | str | None) -> str:
    """A short "2h ago"-style label for feed/comment timestamps, falling back
    to `format_date` for anything older than a week (where a relative label
    stops being useful)."""
    if value is None:
        return ""
    parsed: datetime
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    else:
        parsed = value

    now = datetime.now(parsed.tzinfo) if parsed.tzinfo else datetime.now()
    delta_seconds = (now - parsed).total_seconds()
    if delta_seconds < 60:
        return "just now"
    if delta_seconds < 3600:
        minutes = int(delta_seconds // 60)
        return f"{minutes}m ago"
    if delta_seconds < 86400:
        hours = int(delta_seconds // 3600)
        return f"{hours}h ago"
    if delta_seconds < 604800:
        days = int(delta_seconds // 86400)
        return f"{days}d ago"
    return format_date(parsed)
