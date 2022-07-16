package main

import (
	"html/template"
	"log"
	"net/http"
)

var templates = template.Must(template.ParseFiles("templates/index.tmpl"))

func indexHandler(w http.ResponseWriter, r *http.Request) {
	err := templates.ExecuteTemplate(w, "index.tmpl", "Chip-8")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func main() {
	fs := http.FileServer(http.Dir("./assets"))
	http.HandleFunc("/", indexHandler)
	http.Handle("/static/", http.StripPrefix("/static", fs))
	log.Fatal(http.ListenAndServe(":8080", nil))
}
