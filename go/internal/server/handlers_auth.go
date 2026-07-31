package server

import (
	"log"
	"net/http"
	"net/mail"
	"net/url"

	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
)

// LoginData is the /login page's content payload.
type LoginData struct {
	Base
	Redirect string
}

func (a *App) handleLoginShow(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	if data.IsSignedIn() {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	view := LoginData{
		Base:     a.baseView(r, "Sign in"),
		Redirect: r.URL.Query().Get("redirect"),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "login.html", view)
}

// loginError redirects back to /login preserving both the flash message and any pending
// post-login redirect target.
func loginError(w http.ResponseWriter, r *http.Request, redirect, message string) {
	q := url.Values{"error": {message}}
	if redirect != "" {
		q.Set("redirect", redirect)
	}
	http.Redirect(w, r, "/login?"+q.Encode(), http.StatusSeeOther)
}

func (a *App) handleLoginSubmit(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	email := r.FormValue("email")
	password := r.FormValue("password")
	redirect := r.FormValue("redirect")

	if _, err := mail.ParseAddress(email); err != nil {
		loginError(w, r, redirect, "Enter a valid email address.")
		return
	}
	if password == "" {
		loginError(w, r, redirect, "Password is required.")
		return
	}

	auth, err := a.mudbase.Login(r.Context(), email, password)
	if err != nil {
		loginError(w, r, redirect, mbase.FriendlyMessage(err))
		return
	}

	data := sessionFrom(r)
	data.SetUser(auth)
	if err := data.Save(w, r); err != nil {
		a.serverError(w, r, err)
		return
	}

	target := "/"
	if redirect != "" {
		target = redirect
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

// handleLogout revokes the session's token server-side (best-effort - a failure here shouldn't
// block the visitor from being signed out locally) and clears the local session identity, letting
// the session middleware re-establish a fresh anonymous session on the very next request.
func (a *App) handleLogout(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	if token := data.AccessToken(); token != "" && !data.IsAnonymous() {
		if err := a.mudbase.Logout(r.Context(), token); err != nil {
			log.Printf("server: logout: %v", mbase.FriendlyMessage(err))
		}
	}
	data.ClearUser()
	if err := data.Save(w, r); err != nil {
		a.serverError(w, r, err)
		return
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}
