using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Mudbase.Sdk.Api;
using Mudbase.Sdk.Client;
using Mudbase.Sdk.Model;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>A page of documents plus Mudbase's pagination metadata.</summary>
public sealed class MudbaseListResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public int Page { get; init; }
    public int Limit { get; init; }
    public int Total { get; init; }
    public int TotalPages { get; init; }
}

/// <summary>
/// Thin, generic wrapper over Mudbase.Sdk.Api.DataApi for the posts/comments/likes/follows
/// collections. Handles the plumbing the generated SDK leaves to the caller: building the
/// `filter` query param as a JSON string, and reconstructing a full document from the SDK's
/// untyped response shapes.
///
/// - Single-document reads (Get/Create/Update) come back as `DataResponse.Data` typed `Object`,
///   which System.Text.Json deserializes to a boxed JsonElement — re-serialize/deserialize that
///   into our own POCO. Verified correct live (post detail page renders full content/author).
/// - List reads: the generated SDK's `DataListResponseDataInnerJsonConverter` is a hand-rolled
///   `JsonConverter&lt;T&gt;` whose `Read()` method only ever parses `_id`/`createdAt`/`updatedAt` -
///   every collection-specific field is silently discarded because a custom converter bypasses
///   System.Text.Json's automatic `[JsonExtensionData]` population entirely, and this converter's
///   `Read()` never writes to that dictionary itself. Verified live during this build: every post
///   rendered via the feed/profile list came back with empty content/authorName, while the exact
///   same document fetched via `GetDataAsync` (single-document read, different converter) rendered
///   correctly. <see cref="ListAsync{T}"/> works around this by parsing <c>response.RawContent</c>
///   (the raw HTTP body, already captured by every <see cref="IApiResponse"/> for error reporting)
///   directly with a plain <see cref="JsonDocument"/> instead of trusting the SDK's typed `body.Data`
///   - the authenticated HTTP call itself (token attachment, 401-refresh-retry) still goes through
///   the real SDK; only the broken part of its JSON deserialization is bypassed.
/// </summary>
public sealed class MudbaseDataService
{
    private readonly IDataApi _dataApi;
    private readonly MudbaseOptions _options;

    public MudbaseDataService(IDataApi dataApi, IOptions<MudbaseOptions> options)
    {
        _dataApi = dataApi;
        _options = options.Value;
    }

    public async Task<MudbaseListResult<T>> ListAsync<T>(
        string collectionId,
        IReadOnlyDictionary<string, object?>? filter = null,
        string sort = "-createdAt",
        int page = 1,
        int limit = 20,
        CancellationToken cancellationToken = default)
    {
        string? filterJson = filter is { Count: > 0 } ? JsonSerializer.Serialize(filter, MudbaseJson.Options) : null;
        Option<string> filterOption = filterJson is null ? default : new Option<string>(filterJson);

        IListDataApiResponse response = await _dataApi.ListDataAsync(
            _options.ProjectId, collectionId, page, limit, sort, filterOption, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw MudbaseApiException.From(response);
        }

        using JsonDocument doc = JsonDocument.Parse(response.RawContent);
        JsonElement root = doc.RootElement;

        List<T> items = new();
        if (root.TryGetProperty("data", out JsonElement dataElement) && dataElement.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement itemElement in dataElement.EnumerateArray())
            {
                T? mapped = JsonSerializer.Deserialize<T>(itemElement.GetRawText(), MudbaseJson.Options);
                if (mapped is not null) items.Add(mapped);
            }
        }

        int resolvedPage = page;
        int resolvedLimit = limit;
        int resolvedTotal = items.Count;
        int resolvedTotalPages = 1;
        if (root.TryGetProperty("pagination", out JsonElement paginationElement) && paginationElement.ValueKind == JsonValueKind.Object)
        {
            if (paginationElement.TryGetProperty("page", out JsonElement pageEl)) resolvedPage = pageEl.GetInt32();
            if (paginationElement.TryGetProperty("limit", out JsonElement limitEl)) resolvedLimit = limitEl.GetInt32();
            if (paginationElement.TryGetProperty("total", out JsonElement totalEl)) resolvedTotal = totalEl.GetInt32();
            if (paginationElement.TryGetProperty("totalPages", out JsonElement totalPagesEl)) resolvedTotalPages = totalPagesEl.GetInt32();
        }

        return new MudbaseListResult<T>
        {
            Items = items,
            Page = resolvedPage,
            Limit = resolvedLimit,
            Total = resolvedTotal,
            TotalPages = resolvedTotalPages,
        };
    }

    public async Task<T?> GetAsync<T>(string collectionId, string documentId, CancellationToken cancellationToken = default)
        where T : class
    {
        IGetDataApiResponse response = await _dataApi.GetDataAsync(_options.ProjectId, collectionId, documentId, cancellationToken);

        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }

        if (!response.TryOk(out DataResponse? body) || body?.Data is null)
        {
            throw MudbaseApiException.From(response);
        }

        return MapSingle<T>(body.Data);
    }

    public async Task<T> CreateAsync<T>(string collectionId, IReadOnlyDictionary<string, object?> data, CancellationToken cancellationToken = default)
        where T : class
    {
        ICreateDataApiResponse response = await _dataApi.CreateDataAsync(_options.ProjectId, collectionId, data, cancellationToken);

        if (!response.TryCreated(out DataResponse? body) || body?.Data is null)
        {
            throw MudbaseApiException.From(response);
        }

        return MapSingle<T>(body.Data)!;
    }

    public async Task<T> UpdateAsync<T>(string collectionId, string documentId, IReadOnlyDictionary<string, object?> data, CancellationToken cancellationToken = default)
        where T : class
    {
        IUpdateDataApiResponse response = await _dataApi.UpdateDataAsync(_options.ProjectId, collectionId, documentId, data, cancellationToken);

        if (!response.TryOk(out DataResponse? body) || body?.Data is null)
        {
            throw MudbaseApiException.From(response);
        }

        return MapSingle<T>(body.Data)!;
    }

    public async Task DeleteAsync(string collectionId, string documentId, CancellationToken cancellationToken = default)
    {
        IDeleteDataApiResponse response = await _dataApi.DeleteDataAsync(_options.ProjectId, collectionId, documentId, cancellationToken);

        if (!response.IsOk)
        {
            throw MudbaseApiException.From(response);
        }
    }

    private static T? MapSingle<T>(object data) where T : class
    {
        // System.Text.Json.JsonSerializer.Deserialize<Object> (used internally by the SDK's
        // DataResponseJsonConverter) always produces a boxed JsonElement, never our POCO type
        // directly — re-parse its raw text into the type we actually want.
        if (data is JsonElement element)
        {
            return JsonSerializer.Deserialize<T>(element.GetRawText(), MudbaseJson.Options);
        }

        // Defensive fallback in case a future SDK version deserializes `Object` differently.
        return JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(data, MudbaseJson.Options), MudbaseJson.Options);
    }
}
