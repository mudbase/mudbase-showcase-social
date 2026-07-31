using System.Text.Json;

namespace MudbaseShowcase.Social.Services;

/// <summary>
/// A single, dedicated JsonSerializerOptions for everything this app parses itself: document
/// bodies unwrapped from the SDK's untyped `Object`/JsonElement response fields and the
/// TokenRefreshHandler's raw refresh-endpoint payloads. Deliberately independent of the SDK's own
/// JsonSerializerOptionsProvider (which carries ~150 converters for the SDK's own generated
/// models) so our own POCOs never pick up an unrelated converter by accident — every property on
/// our POCOs is mapped explicitly with [JsonPropertyName], so case-insensitivity here is a safety
/// net, not a requirement.
/// </summary>
public static class MudbaseJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false,
    };
}
