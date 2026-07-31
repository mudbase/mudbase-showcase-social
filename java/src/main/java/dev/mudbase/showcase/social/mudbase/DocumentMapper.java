package dev.mudbase.showcase.social.mudbase;

import java.util.Map;

/**
 * Converts the SDK's document shapes into a plain {@code Map<String, Object>} keyed the same way
 * as the raw Mudbase JSON ({@code _id}, {@code createdAt}, {@code updatedAt}, plus every
 * collection-defined field), and provides defensive readers for pulling typed values back out.
 *
 * <p>{@code DataResponse.getData()} (used by {@code getData}/{@code createData}/{@code
 * updateData}) is declared as a raw {@code Object} that Gson deserializes into a {@code
 * LinkedTreeMap<String,Object>} with every field - including {@code _id} - already flattened
 * together; {@code asMap} below just narrows that to a plain {@code Map}. {@code listData}'s own
 * document shape never reaches here - see {@link MudbaseDataClient#rawList} for why that call is
 * parsed independently with Jackson instead of the generated SDK model.
 */
public final class DocumentMapper {

  private DocumentMapper() {}

  /**
   * {@code DataResponse.getData()}'s raw entries deserialize (via Gson, since the declared type
   * is {@code Object}) into a {@code LinkedTreeMap<String,Object>} for any JSON object - safe to
   * treat as a plain {@code Map} here.
   */
  @SuppressWarnings("unchecked")
  public static Map<String, Object> asMap(Object data) {
    if (data == null) {
      return Map.of();
    }
    if (data instanceof Map) {
      return (Map<String, Object>) data;
    }
    throw new IllegalStateException("Expected a JSON object, got: " + data.getClass());
  }

  public static String getId(Map<String, Object> doc) {
    return getString(doc, "_id");
  }

  public static String getString(Map<String, Object> doc, String key) {
    Object value = doc.get(key);
    return value != null ? value.toString() : null;
  }

  public static String getString(Map<String, Object> doc, String key, String fallback) {
    String value = getString(doc, key);
    return value != null && !value.isBlank() ? value : fallback;
  }

  public static long getLong(Map<String, Object> doc, String key, long fallback) {
    Object value = doc.get(key);
    if (value instanceof Number number) {
      return number.longValue();
    }
    if (value instanceof String s && !s.isBlank()) {
      try {
        return Long.parseLong(s);
      } catch (NumberFormatException ignored) {
        return fallback;
      }
    }
    return fallback;
  }
}
