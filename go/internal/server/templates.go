package server

import (
	"embed"
	"fmt"
	"html/template"
	"net/http"
)

//go:embed templates/*.html
var templatesFS embed.FS

//go:embed static/*
var staticFS embed.FS

// pageNames lists every page template file (besides layout.html), each of which must define a
// `{{define "content"}}` block. Listing them explicitly (rather than globbing at request time)
// means a missing/misnamed template file fails at startup, not on the first visit to that page.
var pageNames = []string{
	"home.html",
	"post_detail.html",
	"profile.html",
	"login.html",
}

// fragmentNames lists every fragment-only template file, rendered via RenderFragment (no layout) -
// these back the poll-refreshed portions of the feed and post detail pages, this app's stand-in
// for the reference web app's Socket.IO realtime subscription: there is no official Mudbase Go
// realtime client, so pages refresh via polling instead of a push subscription (see README "Known
// limitations").
var fragmentNames = []string{
	"feed_fragment.html",
	"post_detail_fragment.html",
}

// funcMap is available to every page template.
var funcMap = template.FuncMap{
	"formatDate": formatDate,
	"initials":   initials,
}

// Templates is a registry of one fully-parsed (layout + page, or standalone fragment) template.Template.
type Templates struct {
	pages     map[string]*template.Template
	fragments map[string]*template.Template
}

// loadTemplates parses layout.html together with each page file into its own template set (so
// every page can define its own `{{define "content"}}` block without colliding with the others),
// plus each fragment file parsed standalone.
func loadTemplates() (*Templates, error) {
	pages := make(map[string]*template.Template, len(pageNames))
	for _, name := range pageNames {
		tmpl, err := template.New("layout.html").Funcs(funcMap).ParseFS(
			templatesFS, "templates/layout.html", "templates/partials.html", "templates/"+name,
		)
		if err != nil {
			return nil, fmt.Errorf("server: parsing template %s: %w", name, err)
		}
		pages[name] = tmpl
	}

	fragments := make(map[string]*template.Template, len(fragmentNames))
	for _, name := range fragmentNames {
		tmpl, err := template.New(name).Funcs(funcMap).ParseFS(
			templatesFS, "templates/partials.html", "templates/"+name,
		)
		if err != nil {
			return nil, fmt.Errorf("server: parsing fragment %s: %w", name, err)
		}
		fragments[name] = tmpl
	}

	return &Templates{pages: pages, fragments: fragments}, nil
}

// Render executes the named page's layout+content into w.
func (t *Templates) Render(w http.ResponseWriter, status int, name string, data interface{}) error {
	tmpl, ok := t.pages[name]
	if !ok {
		return fmt.Errorf("server: no page template registered for %q", name)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := tmpl.ExecuteTemplate(w, "layout.html", data); err != nil {
		return fmt.Errorf("server: rendering template %q: %w", name, err)
	}
	return nil
}

// RenderFragment executes a standalone fragment template (no layout) into w - used by endpoints a
// small poll script fetches to refresh part of an already-loaded page.
func (t *Templates) RenderFragment(w http.ResponseWriter, status int, name string, data interface{}) error {
	tmpl, ok := t.fragments[name]
	if !ok {
		return fmt.Errorf("server: no fragment template registered for %q", name)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := tmpl.ExecuteTemplate(w, "content", data); err != nil {
		return fmt.Errorf("server: rendering fragment %q: %w", name, err)
	}
	return nil
}
