package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"

	zipkin "github.com/openzipkin/zipkin-go"
	zipkinhttp "github.com/openzipkin/zipkin-go/middleware/http"
	zipkinhttpreporter "github.com/openzipkin/zipkin-go/reporter/http"
)

var (
	serviceName = os.Getenv("SERVICE_NAME")
	capability  = os.Getenv("SERVICE_CAPABILITY")

	zipkinHTTPClient *zipkinhttp.Client
)

type ResponseData struct {
	Proto          string
	RequestURI     string
	RequestHeaders http.Header
	RequestBody    string `json:",omitempty"`
	Capability     string
	ServiceName    string
	SubreqData     string `json:",omitempty"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	if serviceName == "echo_subreq" {
		w.WriteHeader(200)
		w.Write([]byte("hello from subrequest"))
		return
	}

	body, _ := ioutil.ReadAll(r.Body)

	// Make a sub request
	subreqData := func() string {
		// retrieve span from context (created by server middleware)
		span := zipkin.SpanFromContext(r.Context())

		newReq, err := http.NewRequest("GET", "http://srv_echo_subreq:8080/hello", nil)
		if err != nil {
			log.Printf("unable to create http request: %+v\n", err)
			return ""
		}

		ctx := zipkin.NewContext(newReq.Context(), span)
		newReq = newReq.WithContext(ctx)

		res, err := zipkinHTTPClient.DoWithAppSpan(newReq, "hello_function")
		if err != nil {
			log.Printf("unable to do http request: %+v\n", err)
			return ""
		}
		defer res.Body.Close()

		subreqBody, _ := ioutil.ReadAll(res.Body)
		return string(subreqBody)
	}()
	// -----------------

	respData := &ResponseData{
		Proto:          r.Proto,
		RequestURI:     r.RequestURI,
		RequestHeaders: r.Header,
		RequestBody:    string(body),
		Capability:     capability,
		ServiceName:    serviceName,
		SubreqData:     subreqData,
	}

	w.WriteHeader(200)
	jenc := json.NewEncoder(w)
	jenc.SetIndent("", "  ")
	jenc.Encode(respData)
}

func main() {
	// Zipkin support
	reporter := zipkinhttpreporter.NewReporter("http://zipkin:9411/api/v2/spans")
	defer reporter.Close()

	zipkinEndpoint, err := zipkin.NewEndpoint(serviceName, "")
	if err != nil {
		log.Fatalf("unable to create local endpoint: %+v\n", err)
	}

	zipkinTracer, err := zipkin.NewTracer(reporter, zipkin.WithLocalEndpoint(zipkinEndpoint))
	if err != nil {
		log.Fatalf("unable to create tracer: %+v\n", err)
	}

	zipkinHTTPClient, err = zipkinhttp.NewClient(zipkinTracer, zipkinhttp.ClientTrace(true))
	if err != nil {
		log.Fatalf("unable to create client: %+v\n", err)
	}

	zipkinMiddleware := zipkinhttp.NewServerMiddleware(zipkinTracer, zipkinhttp.TagResponseSize(true))
	// --------------

	h2s := &http2.Server{}

	http.ListenAndServe(":8080", h2c.NewHandler(
		zipkinMiddleware(http.HandlerFunc(handler)),
		h2s))
}
