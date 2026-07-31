package server

import (
	"strings"
	"time"
)

// formatDate parses an RFC3339 timestamp (as returned by Mudbase's createdAt/updatedAt fields) and
// renders it in a medium, readable form. Malformed or empty input renders as "-" rather than
// panicking or leaking a raw parse error into the page.
func formatDate(iso string) string {
	t, err := time.Parse(time.RFC3339, iso)
	if err != nil {
		return "-"
	}
	return t.Local().Format("Jan 2, 2006, 3:04 PM")
}

// initials renders up to two uppercase letters from name for the avatar-circle fallback this app
// uses everywhere a real profile photo would go - there is no file upload path available to any
// project end-user on this backend (see README "Known limitations"), so every avatar is initials.
func initials(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "?"
	}
	fields := strings.Fields(name)
	if len(fields) == 1 {
		runes := []rune(fields[0])
		if len(runes) == 1 {
			return strings.ToUpper(string(runes[0]))
		}
		return strings.ToUpper(string(runes[:2]))
	}
	first := []rune(fields[0])[0]
	last := []rune(fields[len(fields)-1])[0]
	return strings.ToUpper(string(first) + string(last))
}
