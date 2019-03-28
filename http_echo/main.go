package main

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"os"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

var capability string

type ResponseData struct {
	Proto          string
	RequestURI     string
	RequestHeaders http.Header
	RequestBody    string `json:",omitempty"`
	Capability     string
}

func handler(w http.ResponseWriter, r *http.Request) {
	body, _ := ioutil.ReadAll(r.Body)

	respData := &ResponseData{
		Proto:          r.Proto,
		RequestURI:     r.RequestURI,
		RequestHeaders: r.Header,
		RequestBody:    string(body),
		Capability:     capability,
	}

	w.WriteHeader(200)
	jenc := json.NewEncoder(w)
	jenc.SetIndent("", "  ")
	jenc.Encode(respData)
}

func main() {
	capability = os.Getenv("SERVICE_CAPABILITY")

	h2s := &http2.Server{}

	http.ListenAndServe(":8080", h2c.NewHandler(http.HandlerFunc(handler), h2s))
}
