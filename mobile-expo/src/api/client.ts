import { isAxiosError, type AxiosResponse } from "axios";
import { AuthenticationApi, Configuration, DataApi } from "mudbase-sdk";
import { z } from "zod";
import { MUDBASE_PROJECT_ID, MUDBASE_URL } from "@/config/env";
import { secureStorage, STORAGE_KEYS } from "./secureStorage";
import { authResultSchema, mudbaseUserSchema, type AuthResult, type MudbaseUser } from "./schemas";

/**
 * Thin, typed wrapper around the real generated `mudbase-sdk` — same mechanism
 * the sibling `mudbase-showcase-ecommerce/mobile-expo` port uses: real
 * generated `*Api` class instances (`AuthenticationApi`/`DataApi`), not a
 * unified client the SDK doesn't ship. Every generated method takes a single
 * `requestParameters` object (e.g. `loginLocalUser({ loginLocalUserRequest: {...} })`),
 * NOT the positional arguments shown in the SDK's docs/*.md examples — those
 * examples were generated from an older calling convention and no longer match
 * the actual `dist/api.js` class methods in the currently vendored SDK build.
 * Calling positionally throws a client-side `RequiredError` before any request
 * reaches the network — verified the hard way while building the ecommerce
 * port, so this file follows the object-parameter convention throughout.
 *
 * This file adds on top of the generated SDK: token storage (SecureStore,
 * never AsyncStorage), a single-retry-on-401 refresh with in-flight dedupe
 * (ported faithfully from web/src/lib/mudbase.ts's `refreshInFlight` pattern —
 * refresh tokens rotate on every use and a reused one revokes the whole
 * session, so concurrent 401s must share one refresh call, never race), and
 * zod-validated narrowing of the generated response types where they
 * under-describe the real payload (see schemas.ts).
 */

export class MudbaseApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = "MudbaseApiError";
  }
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

interface ListDocumentsOptions {
  filter?: Record<string, unknown>;
  sort?: string;
  page?: number;
  limit?: number;
}

function toApiError(err: unknown): MudbaseApiError {
  if (isAxiosError(err)) {
    const status = err.response?.status ?? 0;
    const body = err.response?.data as { error?: string; message?: string; code?: string } | undefined;
    return new MudbaseApiError(body?.error ?? body?.message ?? err.message, status, body?.code);
  }
  if (err instanceof Error) return new MudbaseApiError(err.message, 0);
  return new MudbaseApiError("Unknown error", 0);
}

class MudbaseClient {
  private token: string | null = null;
  private refreshTokenValue: string | null = null;
  private refreshing: Promise<void> | null = null;

  private readonly configuration = new Configuration({
    basePath: MUDBASE_URL,
    accessToken: async (): Promise<string> => this.token ?? "",
  });

  private readonly authApi = new AuthenticationApi(this.configuration);
  private readonly dataApi = new DataApi(this.configuration);

  /** True for both a real signed-in customer and a bootstrap guest — see isRealUser() for the distinction the UI cares about. */
  isAuthenticated(): boolean {
    return this.token !== null;
  }

  /** Loads any persisted tokens from SecureStore at app boot. Call once, before getSession(). */
  async restoreTokens(): Promise<boolean> {
    const [token, refreshTokenValue] = await Promise.all([
      secureStorage.get(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.get(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
    if (!token || !refreshTokenValue) return false;
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    return true;
  }

  getToken(): string | null {
    return this.token;
  }

  private async persistTokens(token: string, refreshTokenValue: string): Promise<void> {
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    await Promise.all([
      secureStorage.set(STORAGE_KEYS.ACCESS_TOKEN, token),
      secureStorage.set(STORAGE_KEYS.REFRESH_TOKEN, refreshTokenValue),
    ]);
  }

  private async clearTokens(): Promise<void> {
    this.token = null;
    this.refreshTokenValue = null;
    await Promise.all([
      secureStorage.delete(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.delete(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
  }

  /**
   * Mudbase access tokens are short-lived (~30 min). Refresh tokens rotate on
   * every use and a reused one revokes the session (platform reuse-detection)
   * — this in-flight promise is shared across concurrent 401s to guarantee at
   * most one refresh call per expiry, never a stampede that would trip
   * reuse-detection itself. Faithful port of web/src/lib/mudbase.ts's
   * `refreshAccessToken()` / `refreshInFlight`.
   */
  private async refreshSession(): Promise<void> {
    if (!this.refreshTokenValue) {
      throw new MudbaseApiError("No refresh token available — sign in again.", 401);
    }
    if (!this.refreshing) {
      this.refreshing = (async (): Promise<void> => {
        const res = await this.authApi.refreshToken({
          refreshTokenRequest: { refreshToken: this.refreshTokenValue as string },
        });
        const { token, refreshToken: nextRefreshToken } = res.data;
        if (!token || !nextRefreshToken) {
          throw new MudbaseApiError("Refresh response was missing new tokens.", 500);
        }
        await this.persistTokens(token, nextRefreshToken);
      })().finally(() => {
        this.refreshing = null;
      });
    }
    return this.refreshing;
  }

  private async withAuthRetry<T>(fn: () => Promise<AxiosResponse<T>>): Promise<T> {
    try {
      const res = await fn();
      return res.data;
    } catch (err) {
      if (isAxiosError(err) && err.response?.status === 401 && this.refreshTokenValue) {
        await this.refreshSession();
        const retried = await fn();
        return retried.data;
      }
      throw toApiError(err);
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /**
   * Every collection read requires *some* JWT — verified live against this
   * exact project (see ../plan/build-plan.md finding #3): an anonymous session
   * satisfies that without forcing a login screen on first launch, exactly
   * like the web reference app's guest-browsing bootstrap. Posting, liking,
   * commenting, and following still require a real, verified customer account
   * — enforced both by Mudbase's own collection permissions and by this app's
   * `isRealUser()` UI gate.
   */
  async createAnonymousSession(): Promise<MudbaseUser> {
    try {
      const res = await this.authApi.createAnonymousSession({
        createAnonymousSessionRequest: { projectId: MUDBASE_PROJECT_ID },
      });
      const parsed: AuthResult = authResultSchema.parse(res.data);
      if (!parsed.token || !parsed.refreshToken || !parsed.user) {
        throw new MudbaseApiError("Anonymous session response was missing tokens or user.", 500);
      }
      await this.persistTokens(parsed.token, parsed.refreshToken);
      return parsed.user;
    } catch (err) {
      throw toApiError(err);
    }
  }

  async login(email: string, password: string): Promise<MudbaseUser> {
    try {
      const res = await this.authApi.loginLocalUser({
        loginLocalUserRequest: { email, password, projectId: MUDBASE_PROJECT_ID },
      });
      const { token, refreshToken: refreshTokenValue } = res.data;
      if (!token || !refreshTokenValue) {
        throw new MudbaseApiError("Login response was missing tokens.", 500);
      }
      const user = mudbaseUserSchema.parse(res.data.user);
      await this.persistTokens(token, refreshTokenValue);
      return user;
    } catch (err) {
      if (err instanceof MudbaseApiError) throw err;
      if (isAxiosError(err) && err.response?.status === 403) {
        const body = err.response.data as { code?: string; error?: string } | undefined;
        if (body?.code === "EMAIL_VERIFICATION_REQUIRED") {
          throw new MudbaseApiError("Please verify your email before signing in.", 403, body.code);
        }
      }
      throw toApiError(err);
    }
  }

  async logout(): Promise<void> {
    try {
      await this.authApi.logoutLocalUser();
    } catch {
      // Best-effort server-side revoke — always clear local tokens regardless.
    } finally {
      await this.clearTokens();
    }
  }

  async getSession(): Promise<MudbaseUser | null> {
    if (!this.token) return null;
    try {
      const body = await this.withAuthRetry(() => this.authApi.getLocalSession({ projectId: MUDBASE_PROJECT_ID }));
      return mudbaseUserSchema.parse(body.user);
    } catch {
      await this.clearTokens();
      return null;
    }
  }

  // ─── Collections (Data API) ────────────────────────────────────────────────

  async listDocuments<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    options: ListDocumentsOptions = {},
  ): Promise<{ data: T[]; pagination: PaginationMeta }> {
    const filterStr =
      options.filter && Object.keys(options.filter).length > 0 ? JSON.stringify(options.filter) : undefined;
    const body = await this.withAuthRetry(() =>
      this.dataApi.listData({
        projectId: MUDBASE_PROJECT_ID,
        collectionId,
        page: options.page,
        limit: options.limit,
        sort: options.sort,
        filter: filterStr,
      }),
    );
    const list = z.array(schema).parse(body.data ?? []);
    const page = body.pagination?.page ?? 1;
    const totalPages = body.pagination?.totalPages ?? 1;
    return {
      data: list,
      pagination: {
        page,
        limit: body.pagination?.limit ?? list.length,
        total: body.pagination?.total ?? list.length,
        totalPages,
        hasMore: page < totalPages,
      },
    };
  }

  async getDocument<T>(schema: z.ZodType<T>, collectionId: string, documentId: string): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.getData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId }),
    );
    return schema.parse(body.data);
  }

  async createDocument<T>(schema: z.ZodType<T>, collectionId: string, data: Record<string, unknown>): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.createData({ projectId: MUDBASE_PROJECT_ID, collectionId, body: data }),
    );
    return schema.parse(body.data);
  }

  async updateDocument<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    documentId: string,
    data: Record<string, unknown>,
  ): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.updateData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId, body: data }),
    );
    return schema.parse(body.data);
  }

  async deleteDocument(collectionId: string, documentId: string): Promise<void> {
    await this.withAuthRetry(() =>
      this.dataApi.deleteData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId }),
    );
  }

  // ─── Post images (bucket upload) ───────────────────────────────────────────

  /**
   * Two real, verified platform constraints shape this method (both documented
   * in ../plan/build-plan.md "Known limitations", mirroring web/README.md
   * verbatim since it's the same backend and the same account roles):
   *
   * 1. `rbacCheck("file","create")` (both bucket listing-with-intent-to-upload
   *    and file upload) only allows the org-level system roles
   *    owner/admin/developer. Every project end-user — including a real,
   *    verified `customer` account — always carries system role `viewer`.
   *    A live check against this exact project during this build returned
   *    `buckets: []` for a customer-role JWT (empty, not 403 — the list call
   *    itself is reachable, but no bucket is visible/writable at this role),
   *    consistent with that constraint.
   * 2. The generated `mudbase-sdk`'s `FilesApi.uploadFiles()` JSON-stringifies
   *    the `files` array into a single `Blob` rather than appending real
   *    multipart file parts (see its generated `dist/api.js` — a known
   *    OpenAPI-Generator gap for binary/multipart bodies, the same reason
   *    web/src/lib/mudbase.ts hand-rolls its own `uploadFile()` via raw
   *    `fetch` instead of going through a generated method). This method does
   *    the same: a direct authenticated `fetch` with a real RN-shaped
   *    multipart body (`{ uri, name, type }`), bypassing the broken generated
   *    method for this one endpoint only.
   *
   * Given (1), this call is expected to fail for both provisioned test
   * accounts today — the composer catches that and lets the user continue
   * with a text-only post rather than blocking on it. Kept fully implemented
   * (not a stub) for API-contract completeness and in case the org grants a
   * bucket-capable role in the future, exactly the posture the reference web
   * app documents for the identical constraint.
   */
  async uploadPostImage(asset: { uri: string; name: string; mimeType: string }): Promise<string> {
    if (!this.token) throw new MudbaseApiError("Must be signed in to upload an image", 401);

    const bucketsRes = await fetch(`${MUDBASE_URL}/api/bucket/projects/${MUDBASE_PROJECT_ID}/buckets`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    if (!bucketsRes.ok) {
      throw new MudbaseApiError("Could not look up an upload bucket for this project.", bucketsRes.status);
    }
    const bucketsBody = (await bucketsRes.json()) as { buckets?: Array<{ _id: string }> };
    const bucketId = bucketsBody.buckets?.[0]?._id;
    if (!bucketId) {
      throw new MudbaseApiError(
        "No storage bucket is reachable from this account's role — see README 'Known limitations'.",
        403,
      );
    }

    const form = new FormData();
    // React Native's FormData accepts this `{ uri, name, type }` shape directly (unlike web's
    // File/Blob) — this is the RN-native equivalent of the generated SDK's (broken) file part.
    form.append("files", { uri: asset.uri, name: asset.name, type: asset.mimeType } as unknown as Blob);
    form.append("isPublic", "true");

    const uploadRes = await fetch(`${MUDBASE_URL}/api/bucket/projects/${MUDBASE_PROJECT_ID}/buckets/${bucketId}/files`, {
      method: "POST",
      headers: { Authorization: `Bearer ${this.token}` },
      body: form,
    });
    if (!uploadRes.ok) {
      const body = (await uploadRes.json().catch(() => ({}))) as { error?: string; message?: string };
      throw new MudbaseApiError(body.error ?? body.message ?? "Image upload failed", uploadRes.status);
    }
    const uploadBody = (await uploadRes.json()) as { files?: Array<{ url?: string; publicUrl?: string }> };
    const uploaded = uploadBody.files?.[0];
    const url = uploaded?.publicUrl ?? uploaded?.url;
    if (!url) throw new MudbaseApiError("Upload succeeded but returned no file URL.", 500);
    return url;
  }
}

export const mudbaseClient = new MudbaseClient();
