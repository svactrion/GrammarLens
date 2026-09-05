interface WorkerEnv {
  /** Secret — set via `wrangler secret put ANTHROPIC_API_KEY`, never in code. */
  readonly ANTHROPIC_API_KEY: string;
  /**
   * Secret — set via `wrangler secret put APP_TOKEN`. A shared static
   * value baked into the Flutter build too (see AppConfig). Known to be
   * extractable from a shipped binary like any client-side value; this
   * filters casual/automated scanning, it is not the sole defense (that's
   * also the per-device/global quota below).
   */
  readonly APP_TOKEN: string;
  readonly QUOTA_KV: KVNamespace;
  /** Plain vars (not secret) — see wrangler.jsonc. */
  readonly DEVICE_DAILY_LIMIT: string;
  readonly GLOBAL_DAILY_LIMIT: string;
}

export type Env = WorkerEnv;

// Merges WorkerEnv into the ambient `Cloudflare.Env` global namespace, the
// same shape `wrangler types` would generate from wrangler.jsonc — done by
// hand here instead so secrets (which never appear in wrangler.jsonc) are
// typed too, without a generated file to keep in sync. This is what lets
// `cloudflare:test`'s `env` export (typed as `Cloudflare.Env`) resolve to
// this same Env in tests, with no casting at the call site. (Named
// WorkerEnv, not Env, so this doesn't self-reference: an unqualified `Env`
// inside `namespace Cloudflare` would resolve to the interface being
// declared right here, not the outer module's Env.)
declare global {
  namespace Cloudflare {
    interface Env extends WorkerEnv {}
  }
}

/**
 * A deliberately generic, client-safe error code — never Anthropic's raw
 * error body (which can contain implementation detail we don't want to
 * leak, and isn't ours to pass through unfiltered).
 */
export type ProxyErrorCode =
  | 'unauthorized'
  | 'invalid_request'
  | 'quota_exceeded'
  | 'upstream_error'
  | 'internal_error';

export class ProxyError extends Error {
  readonly code: ProxyErrorCode;
  readonly status: number;
  /** Only meaningful for 'quota_exceeded' — which limit was hit. */
  readonly scope?: 'device' | 'global';

  constructor(
    code: ProxyErrorCode,
    status: number,
    message: string,
    scope?: 'device' | 'global',
  ) {
    super(message);
    this.code = code;
    this.status = status;
    this.scope = scope;
  }

  toResponse(): Response {
    return Response.json(
      { error: this.code, message: this.message, ...(this.scope ? { scope: this.scope } : {}) },
      { status: this.status },
    );
  }
}
