# frozen_string_literal: true

require "time"

# ERB helpers shared by every view. Mirrors `web/src/lib/utils.ts` (relative-time formatting)
# and `web/src/hooks/useProfileStats.ts` (display-name fallback wording) in the reference app so
# the two implementations read the same for the same data.
module ViewHelpers
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def format_datetime(iso_string)
    return "" if iso_string.nil? || iso_string.empty?

    Time.parse(iso_string).strftime("%b %-d, %Y %-I:%M %p")
  rescue ArgumentError
    iso_string.to_s
  end

  # Compact "3m", "2h", "5d" style relative time for feed/comment timestamps - falls back to an
  # absolute date once it's more than a week old, same threshold the reference web app's
  # `formatRelativeTime` uses.
  def format_relative(iso_string)
    return "" if iso_string.nil? || iso_string.empty?

    then_time = Time.parse(iso_string)
    seconds = (Time.now - then_time).to_i
    return "just now" if seconds < 60
    return "#{seconds / 60}m" if seconds < 3600
    return "#{seconds / 3600}h" if seconds < 86_400
    return "#{seconds / 86_400}d" if seconds < 604_800

    then_time.strftime("%b %-d, %Y")
  rescue ArgumentError
    iso_string.to_s
  end

  def initials(name)
    parts = name.to_s.strip.split(/\s+/)
    return "?" if parts.empty?
    return parts.first[0].upcase if parts.length == 1

    "#{parts.first[0]}#{parts.last[0]}".upcase
  end

  def linkify_content(text)
    h(text).gsub("\n", "<br>")
  end

  def pluralize_count(count, singular, plural = nil)
    plural ||= "#{singular}s"
    count == 1 ? singular : plural
  end
end
