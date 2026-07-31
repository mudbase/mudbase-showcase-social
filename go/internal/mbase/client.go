// Package mbase wraps the real Mudbase Go SDK (github.com/mudbase/mudbase-sdk/go) with the
// social app's auth and collection-data operations. It intentionally stays thin: every method
// maps to one real SDK call. There is no "unified higher-level client" invented here - this is a
// direct sibling of mudbase-showcase-ecommerce/go's internal/mbase package, trimmed to what this
// app needs (no Register - see README "Known limitations" for why this app only logs in with the
// two pre-provisioned accounts rather than self-registering).
package mbase

import (
	"context"
	"net/http"
	"time"

	mudbase "github.com/mudbase/mudbase-sdk/go"

	"github.com/mudbase/mudbase-showcase-social/go/internal/config"
)

// Client bundles the generated SDK client with the project configuration every call needs.
type Client struct {
	SDK *mudbase.APIClient
	cfg *config.Config
}

// New builds a Client from the app configuration, wiring the SDK to point at the configured
// Mudbase server exactly as documented: NewConfiguration() then override Servers.
func New(cfg *config.Config) *Client {
	sdkCfg := mudbase.NewConfiguration()
	sdkCfg.Servers = mudbase.ServerConfigurations{
		{URL: cfg.MudbaseURL},
	}
	sdkCfg.HTTPClient = &http.Client{Timeout: 15 * time.Second}

	return &Client{
		SDK: mudbase.NewAPIClient(sdkCfg),
		cfg: cfg,
	}
}

// ProjectID returns the configured Mudbase project ID.
func (c *Client) ProjectID() string {
	return c.cfg.ProjectID
}

// authedContext attaches a bearer token to ctx the way the generated SDK expects it
// (context.WithValue(ctx, mudbase.ContextAccessToken, token)) - confirmed against
// mudbase-sdk/go/configuration.go and client.go's prepareRequest, which reads exactly this key.
func authedContext(ctx context.Context, token string) context.Context {
	if token == "" {
		return ctx
	}
	return context.WithValue(ctx, mudbase.ContextAccessToken, token)
}
